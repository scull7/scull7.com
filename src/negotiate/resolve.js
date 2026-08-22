/**
 * Map request paths to HTML / Markdown siblings and decide passthrough.
 */

const STATIC_EXT =
  /\.(?:css|js|mjs|map|png|jpe?g|webp|gif|svg|avif|ico|woff2?|ttf|otf|eot|xml|txt|json|pdf|mp4|webm|mp3|wav|ogg|zip|wasm)$/i;

/**
 * @param {string} pathname
 */
export function normalizePath(pathname) {
  if (!pathname) return "/";
  try {
    const decoded = decodeURIComponent(pathname);
    const clean = decoded.split("?")[0].split("#")[0];
    if (clean === "" || clean === "/") return "/";
    return clean.replace(/\/+$/, "") || "/";
  } catch {
    return pathname || "/";
  }
}

/**
 * Assets and already-negotiated files skip Accept handling.
 * @param {string} pathname
 */
export function isPassthroughPath(pathname) {
  const clean = normalizePath(pathname);
  if (clean === "/") return false;
  const last = clean.split("/").pop() || "";
  if (!last.includes(".")) return false;
  if (/\.html?$/i.test(last)) return false;
  return STATIC_EXT.test(last) || last.endsWith(".md");
}

/**
 * Candidate HTML files for a URL (first existing wins).
 * @param {string} pathname
 * @returns {string[]}
 */
export function htmlCandidates(pathname) {
  const clean = normalizePath(pathname);
  if (clean === "/") return ["/index.html"];
  return [`${clean}.html`, `${clean}/index.html`];
}

/**
 * Candidate Markdown siblings for a URL.
 * @param {string} pathname
 * @returns {string[]}
 */
export function markdownCandidates(pathname) {
  const clean = normalizePath(pathname);
  if (clean === "/") return ["/index.md"];
  return [`${clean}.md`, `${clean}/index.md`];
}

/**
 * @param {string} pathname
 */
export function isNotFoundProbe(pathname) {
  const clean = normalizePath(pathname);
  return clean === "/__missing_agentic_404__" || clean.startsWith("/__missing");
}
