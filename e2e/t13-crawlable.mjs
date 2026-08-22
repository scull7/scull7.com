/**
 * T-13 crawlable proof: HTTP GET of Vite preview (no JS) plus local
 * resume.json fixtures. Playwright is not used — crawlers do not execute JS.
 *
 * Restores public/resume.json in `finally` after every fixture, including
 * failures and invalid JSON. Inspects `<main id="crawlable-resume">` (Ora
 * ignores noscript).
 */
import { spawn, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const RESUME_REL = "public/resume.json";
const RESUME_PATH = path.join(ROOT, RESUME_REL);
const PORT = process.env.T13_PORT || "4175";
const BASE = `http://127.0.0.1:${PORT}`;

const FIXTURE = {
  name: "PBI-T-13 Fixture Name",
  summary: "PBI-T-13-SUMMARY-TOKEN",
  employer: "PBI-T-13-EMPLOYER",
  crates: "https://example.invalid/pbi-t13",
};

const PROD = {
  name: "Nathan Sculli",
  summary: "Director of Engineering at TensorWave",
  employer: "TensorWave",
  subZero: "Sub Zero Corp",
  crates: "https://crates.io/users/scull7",
  mailto: "mailto:nathan@vegasbuckeye.com",
  github: "https://github.com/scull7",
  tensorwave: "https://tensorwave.com",
  banner: "Banner",
  bannerUrl: "https://withbanner.com",
  backtrace: "Backtrace.io",
  markerTrax: "Marker Trax",
  title: "Nathan Sculli",
  ogTitle: "Nathan Sculli — scull7.com",
  description: "Builder-leader · 20+ years · Rust · Distributed Systems",
  jobTitle: "Director of Engineering",
};

const BANNER_HIGHLIGHTS = [
  "Cut React web build time from 10 minutes to under 1 minute",
  "Fixed concurrency bugs in MongoDB call paths",
  "DevOps infrastructure design and implementation",
];

// --- calculations ----------------------------------------------------------

function extractFragment(html) {
  const match = html.match(
    /<main\s+id=["']crawlable-resume["']\s*>([\s\S]*?)<\/main>/i,
  );
  if (!match) {
    throw new Error('missing <main id="crawlable-resume"> in GET body');
  }
  return match[1];
}

function withoutNoscript(html) {
  return html.replace(/<noscript\b[\s\S]*?<\/noscript>/gi, "");
}

function visibleBodyText(html) {
  const body = html.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? html;
  const stripped = withoutNoscript(body)
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return stripped;
}

function assertNoJsDocument(html) {
  const visible = withoutNoscript(html);
  assert(/<h1\b[^>]*>[\s\S]*?<\/h1>/i.test(visible), "AC no-JS: H1 missing outside noscript");
  assert(/<h2\b[^>]*>[\s\S]*?<\/h2>/i.test(visible), "AC no-JS: H2 missing outside noscript");
  assert(/<h3\b[^>]*>[\s\S]*?<\/h3>/i.test(visible), "AC no-JS: H3 missing outside noscript");
  assert(
    !/<a\b[^>]*>\s*<h[1-3]\b/i.test(visible),
    "AC no-JS: heading trapped inside a link",
  );
  const text = visibleBodyText(html);
  assert(
    text.length >= 500,
    `AC no-JS: need 500+ body chars outside noscript, got ${text.length}`,
  );
}

function hrefs(fragment) {
  return [...fragment.matchAll(/<a\s[^>]*href=["']([^"']*)["']/gi)].map(
    (m) => m[1],
  );
}

function headingTexts(fragment) {
  return [...fragment.matchAll(/<h2>([\s\S]*?)<\/h2>/gi)].map((m) =>
    m[1].replace(/<[^>]+>/g, "").trim(),
  );
}

function meta(html, attr, value) {
  const re = new RegExp(
    `<meta\\s+${attr}=["']${value}["']\\s+content=["']([^"']*)["']`,
    "i",
  );
  const match = html.match(re);
  return match ? match[1] : "";
}

function pageTitle(html) {
  const match = html.match(/<title>([^<]*)<\/title>/i);
  return match ? match[1] : "";
}

function personJsonLd(html) {
  const match = html.match(
    /<script\s+type=["']application\/ld\+json["']\s*>([\s\S]*?)<\/script>/i,
  );
  if (!match) throw new Error("missing Person JSON-LD in GET body");
  return JSON.parse(match[1]);
}

function hasHref(urls, target) {
  const strip = (u) => u.replace(/\/+$/, "");
  return urls.some((u) => u === target || strip(u) === strip(target));
}

function tensorwaveHrefs(urls) {
  return urls.filter((u) => /^https:\/\/tensorwave\.com\/?$/i.test(u));
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function mutateResume(doc) {
  const next = cloneJson(doc);
  next.basics.name = FIXTURE.name;
  next.basics.summary = FIXTURE.summary;
  next.work[0].name = FIXTURE.employer;
  const profile = next.basics.profiles.find((p) => p.url === PROD.crates);
  if (!profile) throw new Error("mutation: crates.io profile missing");
  profile.url = FIXTURE.crates;
  return next;
}

function emptyUrls(doc) {
  const next = cloneJson(doc);
  next.work[0].url = "";
  const profile = next.basics.profiles.find((p) => p.url === PROD.github);
  if (!profile) throw new Error("empty-url: github profile missing");
  profile.url = "";
  return next;
}

function removeBanner(doc) {
  const next = cloneJson(doc);
  if (next.work[2]?.name !== PROD.banner) {
    throw new Error(`missing-job: work[2] is ${next.work[2]?.name}, not Banner`);
  }
  // Drop Banner at work[2] without compacting: T-12 `take 3` is a positional
  // prefix, so splice would promote Backtrace.io into the fragment.
  next.work[2] = {
    name: "",
    position: "",
    url: "",
    startDate: "",
    endDate: "",
    highlights: [],
  };
  return next;
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function assertAc1(fragment) {
  assert(fragment.includes(PROD.name), "AC1: Nathan Sculli missing in crawlable main");
  assert(
    fragment.includes(PROD.summary),
    "AC1: summary sentence missing in crawlable main",
  );
  assert(fragment.includes(PROD.employer), "AC1: TensorWave missing in crawlable main");
  const urls = hrefs(fragment);
  assert(
    hasHref(urls, PROD.mailto) || hasHref(urls, PROD.crates),
    `AC1: need mailto or crates.io href in noscript, got ${urls.join(", ")}`,
  );
}

function assertIdentityLock(html) {
  assert(pageTitle(html) === PROD.title, `title drifted: ${pageTitle(html)}`);
  assert(
    meta(html, "property", "og:title") === PROD.ogTitle,
    `og:title drifted: ${meta(html, "property", "og:title")}`,
  );
  assert(
    meta(html, "name", "description") === PROD.description,
    "meta description drifted",
  );
  assert(
    meta(html, "property", "og:description") === PROD.description,
    "og:description drifted",
  );
  assert(
    meta(html, "name", "twitter:description") === PROD.description,
    "twitter:description drifted",
  );
  const ld = personJsonLd(html);
  assert(ld.name === PROD.name, `JSON-LD name drifted: ${ld.name}`);
  assert(
    typeof ld.description === "string" && ld.description.length > 20,
    `JSON-LD description missing: ${ld.description}`,
  );
  assert(ld.jobTitle === PROD.jobTitle, `JSON-LD jobTitle drifted: ${ld.jobTitle}`);
  assert(
    ld.worksFor?.name === PROD.employer,
    `JSON-LD worksFor drifted: ${ld.worksFor?.name}`,
  );
  assert(
    ld.worksFor?.contactPoint?.email === PROD.mailto.replace("mailto:", ""),
    "JSON-LD Organization contactPoint.email missing",
  );
  assert(
    ld.worksFor?.address?.addressLocality === "Las Vegas",
    "JSON-LD Organization address missing",
  );
}

function assertMutation(fragment, html) {
  assert(fragment.includes(FIXTURE.name), "mutation: fixture name missing");
  assert(
    !fragment.includes(PROD.name),
    "mutation: leftover Nathan Sculli in noscript (append-only inject?)",
  );
  assert(fragment.includes(FIXTURE.summary), "mutation: summary token missing");
  assert(
    !fragment.includes(PROD.summary),
    "mutation: leftover production summary in noscript",
  );
  assert(fragment.includes(FIXTURE.employer), "mutation: employer token missing");
  const headings = headingTexts(fragment);
  assert(
    headings[0] === FIXTURE.employer,
    `mutation: work[0] heading "${headings[0]}" is not ${FIXTURE.employer}`,
  );
  assert(
    !headings.includes(PROD.employer),
    "mutation: leftover TensorWave work[0] heading",
  );
  const urls = hrefs(fragment);
  assert(hasHref(urls, FIXTURE.crates), "mutation: example.invalid href missing");
  assert(
    !hasHref(urls, PROD.crates),
    "mutation: leftover crates.io href in noscript",
  );
  assertIdentityLock(html);
}

function assertEmptyUrl(fragment) {
  const urls = hrefs(fragment);
  const leftover = tensorwaveHrefs(urls);
  assert(
    leftover.length === 0,
    `empty-url: tensorwave.com href still present: ${leftover.join(", ")}`,
  );
  assert(
    !hasHref(urls, PROD.github),
    "empty-url: emptied github href still present",
  );
}

function assertMissingJob(fragment) {
  assert(fragment.trim() !== "", "missing-job: empty fragment");
  assert(fragment.includes(PROD.employer), "missing-job: TensorWave missing");
  assert(fragment.includes(PROD.subZero), "missing-job: Sub Zero Corp missing");
  assert(!fragment.includes(PROD.banner), "missing-job: Banner still in fragment");
  assert(
    !fragment.includes(PROD.bannerUrl),
    "missing-job: withbanner.com still in fragment",
  );
  for (const highlight of BANNER_HIGHLIGHTS) {
    assert(
      !fragment.includes(highlight),
      `missing-job: Banner highlight still present: ${highlight}`,
    );
  }
  assert(
    !fragment.includes(PROD.backtrace),
    "missing-job: Backtrace.io substituted as third job",
  );
  assert(
    !fragment.includes(PROD.markerTrax),
    "missing-job: Marker Trax substituted",
  );
}

// --- actions ---------------------------------------------------------------

function run(cmd, args, opts = {}) {
  return spawnSync(cmd, args, {
    cwd: ROOT,
    encoding: "utf8",
    env: process.env,
    ...opts,
  });
}

function runOrThrow(cmd, args, label) {
  const result = run(cmd, args, { stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`${label} exited ${result.status}`);
  }
}

function readResume() {
  return JSON.parse(readFileSync(RESUME_PATH, "utf8"));
}

function writeResume(doc) {
  writeFileSync(RESUME_PATH, `${JSON.stringify(doc, null, 2)}\n`);
}

function restoreResume() {
  const result = run("git", ["checkout", "--", RESUME_REL]);
  if (result.status !== 0) {
    throw new Error(
      `git checkout -- ${RESUME_REL} exited ${result.status}: ${result.stderr}`,
    );
  }
}

function injectDist() {
  runOrThrow("npm", ["run", "inject:resume:dist"], "npm run inject:resume:dist");
}

function injectDistStatus() {
  return run("npm", ["run", "inject:resume:dist"]);
}

function resumeDiff() {
  return run("git", ["diff", "--", RESUME_REL]);
}

async function waitHttp(url, attempts = 40) {
  for (let i = 0; i < attempts; i += 1) {
    try {
      const res = await fetch(url, { cache: "no-store" });
      if (res.ok) return;
    } catch {
      /* retry */
    }
    await sleep(250);
  }
  throw new Error(`server not ready: ${url}`);
}

const VITE_BIN = path.join(ROOT, "node_modules/vite/bin/vite.js");

function pidsOnPort(port) {
  const result = spawnSync(
    "lsof",
    ["-nP", `-iTCP:${port}`, "-sTCP:LISTEN", "-t"],
    { encoding: "utf8" },
  );
  return (result.stdout || "").trim().split(/\s+/).filter(Boolean);
}

function killPort(port) {
  for (const pid of pidsOnPort(port)) {
    try {
      process.kill(Number(pid), "SIGKILL");
    } catch {
      /* already dead */
    }
  }
}

function startPreview() {
  const child = spawn(
    process.execPath,
    [
      VITE_BIN,
      "preview",
      "--host",
      "127.0.0.1",
      "--port",
      PORT,
      "--strictPort",
    ],
    {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    },
  );
  child.stdout.on("data", (d) => process.stdout.write(d));
  child.stderr.on("data", (d) => process.stderr.write(d));
  return child;
}

function stopPreview(child) {
  if (child && child.pid != null) {
    try {
      child.kill("SIGTERM");
    } catch {
      /* already dead */
    }
  }
  killPort(PORT);
}

async function waitPortFree(attempts = 40) {
  for (let i = 0; i < attempts; i += 1) {
    if (pidsOnPort(PORT).length === 0) return;
    killPort(PORT);
    await sleep(100);
  }
  throw new Error(`port ${PORT} still in use`);
}

async function startPreviewReady() {
  await waitPortFree();
  const child = startPreview();
  try {
    await waitHttp(`${BASE}/`);
    return child;
  } catch (err) {
    stopPreview(child);
    await waitPortFree();
    throw err;
  }
}

async function recyclePreview(child) {
  stopPreview(child);
  await waitPortFree();
  return startPreviewReady();
}

async function getHome() {
  const res = await fetch(`${BASE}/`, { cache: "no-store" });
  assert(res.ok, `GET / status ${res.status}`);
  return res.text();
}

function pass(label) {
  console.log(`PASS ${label}`);
}

async function withResumeRestored(label, fn) {
  try {
    await fn();
    pass(label);
  } finally {
    restoreResume();
  }
}

// --- orchestration ---------------------------------------------------------

async function proveAc1() {
  const html = await getHome();
  assertAc1(extractFragment(html));
  assertNoJsDocument(html);
  pass("AC1 HTTP GET / crawlable main (no JS)");
}

async function proveMutation(committed) {
  await withResumeRestored("AC mutation fixture", async () => {
    writeResume(mutateResume(committed));
    injectDist();
    preview = await recyclePreview(preview);
    const html = await getHome();
    assertMutation(extractFragment(html), html);
  });
}

async function proveEmptyUrl(committed) {
  await withResumeRestored("AC empty-URL fixture", async () => {
    writeResume(emptyUrls(committed));
    injectDist();
    preview = await recyclePreview(preview);
    const html = await getHome();
    assertEmptyUrl(extractFragment(html));
  });
}

async function proveMissingJob(committed) {
  await withResumeRestored("AC missing-job fixture", async () => {
    writeResume(removeBanner(committed));
    injectDist();
    preview = await recyclePreview(preview);
    const html = await getHome();
    assertMissingJob(extractFragment(html));
  });
}

async function proveInvalidJson() {
  await withResumeRestored("AC invalid JSON", async () => {
    writeFileSync(RESUME_PATH, "{ this is not json\n");
    const result = injectDistStatus();
    assert(
      result.status !== 0 && result.status != null,
      `invalid JSON inject exited ${result.status} (want non-zero)`,
    );
    console.log(`  inject:resume:dist exited ${result.status}`);
  });
}

function assertResumeClean() {
  const diff = resumeDiff();
  assert(
    (diff.stdout || "") === "",
    `public/resume.json dirty after restore:\n${diff.stdout}`,
  );
  pass("public/resume.json restored (git diff empty)");
}

let preview;

async function main() {
  try {
    if (process.env.SKIP_BUILD !== "1") {
      console.log("→ npm run build");
      runOrThrow("npm", ["run", "build"], "npm run build");
    }

    console.log(`→ vite preview :${PORT}`);
    preview = await startPreviewReady();

    const committed = readResume();
    await proveAc1();
    await proveMutation(committed);
    await proveEmptyUrl(committed);
    await proveMissingJob(committed);
    await proveInvalidJson();

    injectDist();
    assertResumeClean();
    console.log("e2e/t13-crawlable.mjs PASS");
  } catch (err) {
    console.error("e2e/t13-crawlable.mjs FAIL:", err.message);
    process.exitCode = 1;
  } finally {
    try {
      restoreResume();
    } catch (err) {
      console.error("resume restore failed:", err.message);
      process.exitCode = 1;
    }
    stopPreview(preview);
    await waitPortFree().catch(() => {});
    setTimeout(() => process.exit(process.exitCode ?? 0), 100).unref();
  }
}

main();
