/**
 * Shared Accept-negotiation + agent-friendly 404.
 * `has` / `read` are injected so the same logic runs in Node (Vite) and Deno (Netlify).
 */

import {
  HTML_TYPE,
  MARKDOWN_TYPE,
  PRODUCES,
  preferredType,
  varyAcceptValue,
  notAcceptableBody,
} from "./accept.js";
import {
  htmlCandidates,
  markdownCandidates,
  isPassthroughPath,
  normalizePath,
} from "./resolve.js";

const MD_CONTENT_TYPE = "text/markdown; charset=utf-8";
const HTML_CONTENT_TYPE = "text/html; charset=utf-8";
const PLAIN_CONTENT_TYPE = "text/plain; charset=utf-8";

/**
 * @typedef {{
 *   has: (path: string) => boolean | Promise<boolean>,
 *   read: (path: string) => string | Promise<string>,
 * }} Store
 */

/**
 * @typedef {{
 *   status: number,
 *   headers: Record<string, string>,
 *   body: string,
 * }} Negotiated
 */

function headersFor(contentType, extra = {}) {
  return {
    "Content-Type": contentType,
    Vary: varyAcceptValue(null),
    ...extra,
  };
}

async function firstExisting(store, candidates) {
  for (const path of candidates) {
    if (await store.has(path)) return path;
  }
  return null;
}

/**
 * @param {{ pathname: string, accept: string | null | undefined }} req
 * @param {Store} store
 * @returns {Promise<Negotiated | null>} null = let the static server handle it
 */
export async function negotiateRequest({ pathname, accept }, store) {
  const clean = normalizePath(pathname);
  if (isPassthroughPath(clean)) return null;

  const chosen = preferredType(accept, PRODUCES);
  if (chosen === null) {
    return {
      status: 406,
      headers: {
        ...headersFor(PLAIN_CONTENT_TYPE),
        "Cache-Control": "no-store",
      },
      body: notAcceptableBody(accept || ""),
    };
  }

  const htmlPath = await firstExisting(store, htmlCandidates(clean));
  const mdPath = await firstExisting(store, markdownCandidates(clean));
  const found = Boolean(htmlPath || mdPath);

  if (!found) {
    return notFoundResponse(chosen, store);
  }

  if (chosen === MARKDOWN_TYPE) {
    if (mdPath) {
      const body = await store.read(mdPath);
      return {
        status: 200,
        headers: headersFor(MD_CONTENT_TYPE, {
          Link: `<${mdPath}>; rel="alternate"; type="text/markdown", </llms.txt>; rel="describedby"`,
        }),
        body,
      };
    }
    if (!preferredType(accept, [HTML_TYPE])) {
      return {
        status: 406,
        headers: {
          ...headersFor(PLAIN_CONTENT_TYPE),
          "Cache-Control": "no-store",
        },
        body: notAcceptableBody(accept || ""),
      };
    }
  }

  if (htmlPath) {
    const body = await store.read(htmlPath);
    const extra = {};
    if (mdPath) {
      extra.Link = `<${mdPath}>; rel="alternate"; type="text/markdown", </llms.txt>; rel="describedby"`;
    }
    return {
      status: 200,
      headers: headersFor(HTML_CONTENT_TYPE, extra),
      body,
    };
  }

  if (mdPath) {
    const body = await store.read(mdPath);
    return {
      status: 200,
      headers: headersFor(MD_CONTENT_TYPE),
      body,
    };
  }

  return null;
}

/**
 * @param {string} chosen
 * @param {Store} store
 */
export async function notFoundResponse(chosen, store) {
  if (chosen === MARKDOWN_TYPE && (await store.has("/404.md"))) {
    return {
      status: 404,
      headers: headersFor(MD_CONTENT_TYPE),
      body: await store.read("/404.md"),
    };
  }
  if (await store.has("/404.html")) {
    return {
      status: 404,
      headers: headersFor(HTML_CONTENT_TYPE),
      body: await store.read("/404.html"),
    };
  }
  const fallback = [
    "# Not found",
    "",
    "This path does not exist on scull7.com.",
    "",
    "## Where to go next",
    "",
    "- [Home](https://scull7.com/)",
    "- [About](https://scull7.com/about)",
    "- [Contact](https://scull7.com/contact)",
    "- [Privacy](https://scull7.com/privacy)",
    "- [Sitemap](https://scull7.com/sitemap.xml)",
    "- [llms.txt](https://scull7.com/llms.txt)",
    "",
  ].join("\n");
  return {
    status: 404,
    headers: headersFor(
      chosen === MARKDOWN_TYPE ? MD_CONTENT_TYPE : PLAIN_CONTENT_TYPE,
    ),
    body: fallback,
  };
}
