/**
 * Agent-readiness proofs: Accept parsing, markdown negotiation, 404 recovery,
 * trust-page length, llms.txt / sitemap. Uses Vite preview + the same
 * negotiate middleware Netlify's edge function imports.
 */
import { spawn, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { preferredType, PRODUCES } from "../src/negotiate/accept.js";
import { planNegotiation } from "../src/negotiate/plan.js";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PORT = process.env.AGENTIC_PORT || "4176";
const BASE = `http://127.0.0.1:${PORT}`;
const VITE_BIN = path.join(ROOT, "node_modules/vite/bin/vite.js");

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function pass(label) {
  console.log(`PASS ${label}`);
}

function visibleText(html) {
  const body = html.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? html;
  return body
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript\b[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function proveAcceptParsing() {
  const cases = [
    ["text/markdown", "text/markdown"],
    ["text/markdown, text/html;q=0.8", "text/markdown"],
    ["text/html", "text/html"],
    ["text/markdown;q=0, text/html", "text/html"],
    ["text/markdown, text/html", "text/markdown"],
    ["text/html, text/markdown;q=0.8", "text/html"],
    ["*/*", "text/html"],
    [null, "text/html"],
    ["", "text/html"],
    [
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
      "text/html",
    ],
  ];
  for (const [header, expect] of cases) {
    const got = preferredType(header, PRODUCES);
    assert(got === expect, `Accept "${header}" → ${got}, want ${expect}`);
  }
  assert(
    preferredType("application/pdf", PRODUCES) === null,
    "application/pdf should 406",
  );
  assert(
    preferredType("text/markdown;q=0", ["text/markdown"]) === null,
    "markdown q=0 against md-only should 406",
  );
  pass("Accept parsing q-values / 406 / browser header");
}

function proveMissingPathMarkdownPlan() {
  const missingMd = planNegotiation({
    accept: "text/markdown",
    pageMdExists: false,
    originStatus: 404,
  });
  assert(
    missingMd.action === "not-found-markdown" && missingMd.status === 404,
    `missing path + Accept: text/markdown → ${missingMd.action} ${missingMd.status} (want not-found-markdown 404, not 406)`,
  );

  const missingHtml = planNegotiation({
    accept: null,
    pageMdExists: false,
    originStatus: 404,
  });
  assert(
    missingHtml.action === "not-found-html" && missingHtml.status === 404,
    `missing path + browser Accept → ${missingHtml.action}`,
  );

  const pdf = planNegotiation({
    accept: "application/pdf",
    pageMdExists: false,
    originStatus: 404,
  });
  assert(
    pdf.action === "not-acceptable" && pdf.status === 406,
    `application/pdf → ${pdf.action} ${pdf.status}`,
  );

  const pageMd = planNegotiation({
    accept: "text/markdown",
    pageMdExists: true,
    originStatus: 200,
  });
  assert(
    pageMd.action === "page-markdown" && pageMd.status === 200,
    `existing .md sibling → ${pageMd.action}`,
  );
  pass("edge plan: missing path + Accept markdown is 404, not 406");
}

function proveTrustPageFiles() {
  for (const name of ["about", "contact", "privacy"]) {
    const html = readFileSync(path.join(ROOT, `public/${name}.html`), "utf8");
    const text = visibleText(html);
    assert(
      text.length >= 500,
      `${name}.html visible text ${text.length} < 500`,
    );
    assert(/Nathan Sculli/.test(text), `${name}.html missing name`);
    assert(/vegasbuckeye\.com/.test(text), `${name}.html missing email`);
    const md = readFileSync(path.join(ROOT, `public/${name}.md`), "utf8");
    assert(md.length >= 500, `${name}.md ${md.length} < 500`);
  }
  const llms = readFileSync(path.join(ROOT, "public/llms.txt"), "utf8");
  assert(/When to use this/i.test(llms), "llms.txt missing When to use this");
  assert(/not a SaaS API/i.test(llms) && /not an MCP server/i.test(llms), "llms.txt missing not-for jobs");
  assert(/TensorWave/.test(llms), "llms.txt missing TensorWave");
  pass("trust pages + llms.txt on disk");
}

function runOrThrow(cmd, args, label) {
  const result = spawnSync(cmd, args, {
    cwd: ROOT,
    encoding: "utf8",
    stdio: "inherit",
    env: process.env,
  });
  if (result.status !== 0) {
    throw new Error(`${label} exited ${result.status}`);
  }
}

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

async function waitPortFree(attempts = 40) {
  for (let i = 0; i < attempts; i += 1) {
    if (pidsOnPort(PORT).length === 0) return;
    killPort(PORT);
    await sleep(100);
  }
  throw new Error(`port ${PORT} still in use`);
}

function startPreview() {
  const child = spawn(
    process.execPath,
    [VITE_BIN, "preview", "--host", "127.0.0.1", "--port", PORT, "--strictPort"],
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

function headerHas(headers, name, needle) {
  const value = headers.get(name) || "";
  return value.toLowerCase().includes(needle.toLowerCase());
}

async function proveHttp() {
  const home = await fetch(`${BASE}/`, { cache: "no-store" });
  assert(home.ok, `GET / ${home.status}`);
  const homeHtml = await home.text();
  const homeText = visibleText(homeHtml);
  assert(homeText.length >= 500, `GET / visible text ${homeText.length} < 500`);
  assert(/<h1\b/i.test(homeHtml), "GET / missing H1");
  assert(headerHas(home.headers, "vary", "accept"), `GET / Vary=${home.headers.get("vary")}`);

  const md = await fetch(`${BASE}/`, {
    cache: "no-store",
    headers: { Accept: "text/markdown" },
  });
  assert(md.ok, `GET / markdown ${md.status}`);
  const mdType = md.headers.get("content-type") || "";
  assert(
    mdType.startsWith("text/markdown") && mdType.includes("charset=utf-8"),
    `GET / markdown Content-Type=${mdType}`,
  );
  assert(headerHas(md.headers, "vary", "accept"), `markdown Vary=${md.headers.get("vary")}`);
  const mdBody = await md.text();
  assert(/Nathan Sculli/.test(mdBody), "markdown home missing name");
  assert(/TensorWave/.test(mdBody), "markdown home missing TensorWave");
  pass("GET / HTML + Accept: text/markdown");

  const q = await fetch(`${BASE}/`, {
    cache: "no-store",
    headers: { Accept: "text/markdown, text/html;q=0.8" },
  });
  assert(
    (q.headers.get("content-type") || "").startsWith("text/markdown"),
    "q-value markdown preference lost",
  );

  const chrome = await fetch(`${BASE}/`, {
    cache: "no-store",
    headers: {
      Accept:
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,*/*;q=0.8",
    },
  });
  assert(chrome.ok, "browser Accept should not 406");
  assert(
    (chrome.headers.get("content-type") || "").includes("text/html"),
    "browser Accept should stay HTML",
  );

  const notAcceptable = await fetch(`${BASE}/`, {
    cache: "no-store",
    headers: { Accept: "application/pdf" },
  });
  assert(notAcceptable.status === 406, `pdf Accept status ${notAcceptable.status}`);
  assert(headerHas(notAcceptable.headers, "vary", "accept"), "406 missing Vary Accept");
  pass("q-values, browser Accept, 406");

  for (const page of ["/about", "/contact", "/privacy"]) {
    const res = await fetch(`${BASE}${page}`, { cache: "no-store" });
    assert(res.ok, `GET ${page} ${res.status}`);
    const text = visibleText(await res.text());
    assert(text.length >= 500, `${page} text ${text.length} < 500`);
    const mdRes = await fetch(`${BASE}${page}`, {
      cache: "no-store",
      headers: { Accept: "text/markdown" },
    });
    assert(
      (mdRes.headers.get("content-type") || "").startsWith("text/markdown"),
      `${page} markdown Content-Type`,
    );
  }
  pass("trust pages HTML + markdown");

  const missing = "/__missing_agentic_404__";
  const html404 = await fetch(`${BASE}${missing}`, { cache: "no-store" });
  assert(html404.status === 404, `missing path status ${html404.status}`);
  const body404 = await html404.text();
  for (const token of ["sitemap", "llms.txt", "about", "contact", "privacy"]) {
    assert(body404.toLowerCase().includes(token), `404 HTML missing ${token}`);
  }

  const md404 = await fetch(`${BASE}${missing}`, {
    cache: "no-store",
    headers: { Accept: "text/markdown" },
  });
  assert(
    md404.status === 404,
    `missing path + Accept: text/markdown status ${md404.status} (must be 404 with 404.md, not 406)`,
  );
  assert(
    (md404.headers.get("content-type") || "").startsWith("text/markdown"),
    `markdown 404 Content-Type=${md404.headers.get("content-type")}`,
  );
  assert(
    md404.status !== 406,
    "missing path + Accept: text/markdown must not 406 before /404.md",
  );
  const md404Body = await md404.text();
  for (const token of ["sitemap", "llms.txt", "about", "contact", "privacy"]) {
    assert(md404Body.toLowerCase().includes(token), `404 markdown missing ${token}`);
  }
  pass("404 HTML + markdown recovery");

  for (const p of ["/llms.txt", "/sitemap.xml", "/for-agents", "/resume.json"]) {
    const res = await fetch(`${BASE}${p}`, { cache: "no-store" });
    assert(res.ok, `GET ${p} ${res.status}`);
  }
  const llms = await (await fetch(`${BASE}/llms.txt`)).text();
  assert(/When to use this/.test(llms), "served llms.txt missing When to use this");
  pass("llms.txt sitemap for-agents resume.json");
}

let preview;

async function main() {
  try {
    proveAcceptParsing();
    proveMissingPathMarkdownPlan();
    proveTrustPageFiles();

    if (process.env.SKIP_BUILD !== "1") {
      console.log("→ npm run build");
      runOrThrow("npm", ["run", "build"], "npm run build");
    }

    console.log(`→ vite preview :${PORT}`);
    await waitPortFree();
    preview = startPreview();
    await waitHttp(`${BASE}/`);
    await proveHttp();
    console.log("e2e/agentic.mjs PASS");
  } catch (err) {
    console.error("e2e/agentic.mjs FAIL:", err.message);
    process.exitCode = 1;
  } finally {
    stopPreview(preview);
    await waitPortFree().catch(() => {});
    setTimeout(() => process.exit(process.exitCode ?? 0), 100).unref();
  }
}

main();
