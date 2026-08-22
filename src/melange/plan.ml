(* Negotiation plan used by the Netlify edge function.
   406 is only when the client rejects every type we offer (HTML and
   Markdown). A missing path still has /404.md, so Accept: text/markdown
   must not 406 just because no page-specific sibling exists. *)

type t = { action : string; status : int; chosen : string option }

let plan_negotiation ~accept ~page_md_exists ?origin_status () =
  match Accept.preferred_type accept Accept.produces with
  | None -> { action = "not-acceptable"; status = 406; chosen = None }
  | Some chosen when chosen = Accept.markdown_type && page_md_exists ->
      { action = "page-markdown"; status = 200; chosen = Some chosen }
  | Some chosen when origin_status = Some 404 ->
      if chosen = Accept.markdown_type then
        { action = "not-found-markdown"; status = 404; chosen = Some chosen }
      else { action = "not-found-html"; status = 404; chosen = Some chosen }
  | Some chosen ->
      {
        action = "origin";
        status = (match origin_status with Some s -> s | None -> 200);
        chosen = Some chosen;
      }
