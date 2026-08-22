/**
 * RFC 9110 Accept parsing for HTML vs Markdown negotiation.
 * Shared by the Netlify edge function, Vite preview middleware, and tests.
 * Follows https://acceptmarkdown.com/guides/accept-parsing
 */

/**
 * @typedef {{ type: string, q: number, specificity: number }} AcceptEntry
 */

/**
 * @param {string} header
 * @returns {AcceptEntry[]}
 */
export function parseAccept(header) {
  if (typeof header !== "string") return [];
  return header
    .split(",")
    .map((raw) => {
      const parts = raw
        .trim()
        .split(";")
        .map((s) => s.trim())
        .filter(Boolean);
      const type = (parts[0] || "").toLowerCase();
      if (!type) return null;
      let q = 1;
      for (const param of parts.slice(1)) {
        const eq = param.indexOf("=");
        if (eq === -1) continue;
        const name = param.slice(0, eq).trim().toLowerCase();
        const value = param.slice(eq + 1).trim();
        if (name === "q") {
          const parsed = Number(value);
          if (!Number.isNaN(parsed)) q = Math.max(0, Math.min(1, parsed));
        }
      }
      const specificity = type === "*/*" ? 0 : type.endsWith("/*") ? 1 : 2;
      return { type, q, specificity };
    })
    .filter((e) => e !== null);
}

/**
 * @param {AcceptEntry} entry
 * @param {string} candidate
 */
function matches(entry, candidate) {
  if (entry.type === "*/*") return true;
  if (entry.type.endsWith("/*")) {
    return candidate.startsWith(entry.type.slice(0, -1));
  }
  return entry.type === candidate;
}

/**
 * Pick the best of `produces` for this Accept header.
 * Missing / blank Accept -> produces[0] (HTML). A catch-all Accept also
 * prefers produces[0] when q-values tie, so ordinary browsers are never 406'd.
 *
 * @param {string | null | undefined} header
 * @param {string[]} produces
 * @returns {string | null} chosen type, or null → 406
 */
export function preferredType(header, produces) {
  if (!produces.length) return null;
  if (header == null || String(header).trim() === "") {
    return produces[0];
  }

  const entries = parseAccept(header);
  if (entries.length === 0) return produces[0];

  let bestType = null;
  let bestQ = -1;
  let bestPosition = Infinity;

  for (const candidate of produces) {
    let matched = null;
    let matchedPosition = Infinity;
    for (let idx = 0; idx < entries.length; idx += 1) {
      const entry = entries[idx];
      if (!matches(entry, candidate)) continue;
      if (
        matched === null ||
        entry.specificity > matched.specificity ||
        (entry.specificity === matched.specificity && idx < matchedPosition)
      ) {
        matched = entry;
        matchedPosition = idx;
      }
    }
    if (matched === null) continue;
    if (matched.q <= 0) continue;
    if (matched.q > bestQ || (matched.q === bestQ && matchedPosition < bestPosition)) {
      bestQ = matched.q;
      bestPosition = matchedPosition;
      bestType = candidate;
    }
  }

  return bestType;
}

/**
 * @param {Headers | { get: (n: string) => string | null, set: (n: string, v: string) => void }} headers
 */
export function appendVaryAccept(headers) {
  const existing = headers.get("vary") || headers.get("Vary");
  if (!existing) {
    headers.set("Vary", "Accept");
    return;
  }
  const tokens = existing.split(",").map((s) => s.trim().toLowerCase());
  if (!tokens.includes("accept")) {
    headers.set("Vary", `${existing}, Accept`);
  }
}

export const HTML_TYPE = "text/html";
export const MARKDOWN_TYPE = "text/markdown";
export const PRODUCES = [HTML_TYPE, MARKDOWN_TYPE];

export function varyAcceptValue(existing) {
  if (!existing) return "Accept, Accept-Encoding";
  const tokens = existing.split(",").map((s) => s.trim().toLowerCase());
  const parts = existing.split(",").map((s) => s.trim()).filter(Boolean);
  if (!tokens.includes("accept")) parts.unshift("Accept");
  if (!tokens.includes("accept-encoding")) parts.push("Accept-Encoding");
  return parts.join(", ");
}

export function notAcceptableBody(requested) {
  return [
    "Not Acceptable",
    "",
    "This resource is available in:",
    "- text/html",
    "- text/markdown",
    requested ? "" : "",
    requested ? `You requested: ${requested}` : "",
    "",
  ]
    .filter((line, i, arr) => line !== "" || (i > 0 && arr[i - 1] !== ""))
    .join("\n");
}
