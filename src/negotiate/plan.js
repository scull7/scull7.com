/**
 * Negotiation plan used by the Netlify edge function.
 *
 * 406 is only when the client rejects every type we offer (HTML and
 * Markdown), e.g. Accept: application/pdf. A missing path still has a
 * Markdown representation (/404.md), so Accept: text/markdown must not
 * 406 just because no page-specific sibling exists.
 */

import { MARKDOWN_TYPE, PRODUCES, preferredType } from "./accept.js";

/**
 * @param {{
 *   accept: string | null | undefined,
 *   pageMdExists: boolean,
 *   originStatus?: number,
 * }} input
 * @returns {{
 *   action: "not-acceptable" | "page-markdown" | "not-found-markdown" | "not-found-html" | "origin",
 *   status: number,
 *   chosen: string | null,
 * }}
 */
export function planNegotiation({ accept, pageMdExists, originStatus }) {
  const chosen = preferredType(accept, PRODUCES);
  if (chosen === null) {
    return { action: "not-acceptable", status: 406, chosen: null };
  }
  if (chosen === MARKDOWN_TYPE && pageMdExists) {
    return { action: "page-markdown", status: 200, chosen };
  }
  if (originStatus === 404) {
    if (chosen === MARKDOWN_TYPE) {
      return { action: "not-found-markdown", status: 404, chosen };
    }
    return { action: "not-found-html", status: 404, chosen };
  }
  return { action: "origin", status: originStatus ?? 200, chosen };
}
