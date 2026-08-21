/**
 * Build-time crawlable resume fragment.
 * Calculations: JSON Resume → HTML string. Actions: read file, Vite hook.
 *
 * Delimiter: <noscript id="crawlable-resume">
 * Facts come from public/resume.json — do not hard-code career copy here.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const NOSCRIPT_ID = "crawlable-resume";
export const CRAWLABLE_WORK_COUNT = 3;
export const RESUME_RELATIVE_PATH = path.join("public", "resume.json");

const NOSCRIPT_RE =
  /<noscript\s+id=["']crawlable-resume["']\s*>[\s\S]*?<\/noscript>/i;

const HTML_ESCAPES = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

export function asString(value) {
  return typeof value === "string" ? value : "";
}

export function escapeHtml(text) {
  return asString(text).replace(/[&<>"']/g, (ch) => HTML_ESCAPES[ch]);
}

export function splitParagraphs(summary) {
  return asString(summary)
    .split(/\n\s*\n/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
}

export function isPresentUrl(url) {
  return asString(url).trim().length > 0;
}

export function renderAnchor(href, text) {
  return `<a href="${escapeHtml(href)}">${escapeHtml(text)}</a>`;
}

export function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function objectOrEmpty(value) {
  return isPlainObject(value) ? value : {};
}

function listOrEmpty(value) {
  return Array.isArray(value) ? value : [];
}

export function profileUrls(profiles) {
  return listOrEmpty(profiles)
    .map((profile) => asString(profile?.url).trim())
    .filter(isPresentUrl);
}

export function contactHrefs(basics) {
  const email = asString(basics.email).trim();
  const site = asString(basics.url).trim();
  const hrefs = [];
  if (email) hrefs.push(`mailto:${email}`);
  if (isPresentUrl(site)) hrefs.push(site);
  return hrefs.concat(profileUrls(basics.profiles));
}

export function crawlableWork(resume) {
  return listOrEmpty(resume?.work)
    .filter(isPlainObject)
    .slice(0, CRAWLABLE_WORK_COUNT);
}

function renderParagraphs(summary) {
  return splitParagraphs(summary).map((part) => `<p>${escapeHtml(part)}</p>`);
}

function renderContact(basics) {
  const anchors = contactHrefs(basics).map((href) => {
    const text = href.startsWith("mailto:") ? href.slice("mailto:".length) : href;
    return renderAnchor(href, text);
  });
  return anchors.length > 0 ? `<p>${anchors.join(" ")}</p>` : "";
}

export function renderBasics(basics) {
  const name = asString(basics.name);
  const label = asString(basics.label);
  return [
    name ? `<h1>${escapeHtml(name)}</h1>` : "",
    label ? `<p>${escapeHtml(label)}</p>` : "",
    ...renderParagraphs(basics.summary),
    renderContact(basics),
  ]
    .filter(Boolean)
    .join("\n");
}

function renderJobHeading(job) {
  const name = asString(job.name);
  const url = asString(job.url).trim();
  if (isPresentUrl(url)) return `<h2>${renderAnchor(url, name)}</h2>`;
  return name ? `<h2>${escapeHtml(name)}</h2>` : "";
}

function renderJobDates(job) {
  const start = asString(job.startDate).trim();
  const end = asString(job.endDate).trim();
  const times = [];
  if (start) times.push(`<time>${escapeHtml(start)}</time>`);
  if (end) times.push(`<time>${escapeHtml(end)}</time>`);
  return times.length > 0 ? `<p>${times.join(" – ")}</p>` : "";
}

function renderHighlights(highlights) {
  const items = listOrEmpty(highlights)
    .map((item) => asString(item))
    .filter((item) => item.length > 0)
    .map((item) => `<li>${escapeHtml(item)}</li>`);
  return items.length > 0 ? `<ul>${items.join("")}</ul>` : "";
}

export function renderJob(job) {
  const position = asString(job.position);
  return [
    "<section>",
    renderJobHeading(job),
    position ? `<p>${escapeHtml(position)}</p>` : "",
    renderJobDates(job),
    renderHighlights(job.highlights),
    "</section>",
  ]
    .filter(Boolean)
    .join("\n");
}

export function renderFragment(resume) {
  const doc = objectOrEmpty(resume);
  const basics = objectOrEmpty(doc.basics);
  return [renderBasics(basics), ...crawlableWork(doc).map(renderJob)]
    .filter(Boolean)
    .join("\n");
}

export function wrapNoscript(inner) {
  return `<noscript id="${NOSCRIPT_ID}">\n${inner}\n    </noscript>`;
}

export function injectNoscript(html, inner) {
  const replacement = wrapNoscript(inner);
  if (NOSCRIPT_RE.test(html)) return html.replace(NOSCRIPT_RE, replacement);
  if (/<\/body>/i.test(html)) {
    return html.replace(/<\/body>/i, `    ${replacement}\n  </body>`);
  }
  return `${html}\n${replacement}\n`;
}

export function resumePathFor(rootDir) {
  return path.join(rootDir, RESUME_RELATIVE_PATH);
}

export function readResumeJson(filePath) {
  let raw;
  try {
    raw = fs.readFileSync(filePath, "utf8");
  } catch (err) {
    throw new Error(`crawlable-resume: cannot read ${filePath}: ${err.message}`);
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    throw new Error(`crawlable-resume: invalid JSON in ${filePath}: ${err.message}`);
  }
}

export function crawlableResumePlugin(rootDir) {
  const resumePath = resumePathFor(rootDir);
  return {
    name: "crawlable-resume",
    transformIndexHtml(html) {
      const inner = renderFragment(readResumeJson(resumePath));
      return injectNoscript(html, inner);
    },
  };
}

function repoRoot() {
  return path.dirname(path.dirname(fileURLToPath(import.meta.url)));
}

function isDirectRun() {
  const invoked = process.argv[1];
  if (!invoked) return false;
  return path.resolve(invoked) === fileURLToPath(import.meta.url);
}

if (isDirectRun()) {
  const inner = renderFragment(readResumeJson(resumePathFor(repoRoot())));
  process.stdout.write(`${wrapNoscript(inner)}\n`);
}
