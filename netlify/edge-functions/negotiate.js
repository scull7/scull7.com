/**
 * Accept: text/markdown negotiation + agent-friendly 404.
 * Spec: https://acceptmarkdown.com
 *
 * HTML comes from the origin (context.next). Markdown is the .md sibling.
 * File-extension requests and an internal bypass header skip this function
 * so sibling fetches cannot recurse.
 */

import { MARKDOWN_TYPE, varyAcceptValue, notAcceptableBody } from "../../src/negotiate/accept.js";
import { markdownCandidates, normalizePath } from "../../src/negotiate/resolve.js";
import { planNegotiation } from "../../src/negotiate/plan.js";

export const config = {
  path: "/*",
  excludedPath: ["/assets/*", "/styles/*", "/og.png", "/og.svg"],
};

const BYPASS = "x-negotiate-bypass";

function withHeaders(status, contentType, body, extra = {}) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": contentType,
      Vary: varyAcceptValue(null),
      ...extra,
    },
  });
}

async function fetchSibling(request, pathname) {
  const url = new URL(pathname, request.url);
  return fetch(new Request(url, { headers: { [BYPASS]: "1" } }));
}

export default async (request, context) => {
  if (request.headers.get(BYPASS) === "1") {
    return context.next();
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return context.next();
  }

  const url = new URL(request.url);
  const last = url.pathname.split("/").pop() || "";
  if (last.includes(".")) {
    return context.next();
  }

  const accept = request.headers.get("accept");
  const early = planNegotiation({ accept, pageMdExists: false });
  if (early.action === "not-acceptable") {
    return withHeaders(406, "text/plain; charset=utf-8", notAcceptableBody(accept || ""), {
      "Cache-Control": "no-store",
    });
  }

  const clean = normalizePath(url.pathname);
  const mdPaths = markdownCandidates(clean);

  if (early.chosen === MARKDOWN_TYPE) {
    for (const mdPath of mdPaths) {
      const mdRes = await fetchSibling(request, mdPath);
      if (mdRes.ok) {
        const body = request.method === "HEAD" ? null : await mdRes.text();
        return withHeaders(200, "text/markdown; charset=utf-8", body, {
          Link: `<${mdPath}>; rel="alternate"; type="text/markdown", </llms.txt>; rel="describedby"`,
        });
      }
    }
  }

  // No page-specific .md sibling. Do not 406: Accept: text/markdown still
  // matches /404.md on a missing path. 406 is only not-acceptable above.
  const origin = await context.next();
  const plan = planNegotiation({
    accept,
    pageMdExists: false,
    originStatus: origin.status,
  });

  if (plan.action === "not-acceptable") {
    return withHeaders(406, "text/plain; charset=utf-8", notAcceptableBody(accept || ""), {
      "Cache-Control": "no-store",
    });
  }

  if (plan.action === "not-found-markdown") {
    const md404 = await fetchSibling(request, "/404.md");
    if (md404.ok) {
      const body = request.method === "HEAD" ? null : await md404.text();
      return withHeaders(404, "text/markdown; charset=utf-8", body);
    }
  }

  if (origin.status === 404) {
    const headers = new Headers(origin.headers);
    headers.set("Vary", varyAcceptValue(headers.get("Vary")));
    return new Response(origin.body, { status: 404, headers });
  }

  const headers = new Headers(origin.headers);
  headers.set("Vary", varyAcceptValue(headers.get("Vary")));
  if ((headers.get("content-type") || "").includes("text/html")) {
    const mdPath = mdPaths[0];
    const existing = headers.get("Link");
    const link = `<${mdPath}>; rel="alternate"; type="text/markdown", </llms.txt>; rel="describedby"`;
    headers.set("Link", existing ? `${existing}, ${link}` : link);
  }
  return new Response(origin.body, { status: origin.status, headers });
};
