(* Shared Accept-negotiation + agent-friendly 404.
   `has` / `read` are injected so Vite preview and tests share this logic. *)

type store = { has : string -> bool; read : string -> string }

type negotiated = {
  status : int;
  headers : (string * string) list;
  body : string;
}

let md_content_type = "text/markdown; charset=utf-8"
let html_content_type = "text/html; charset=utf-8"
let plain_content_type = "text/plain; charset=utf-8"

let headers_for content_type extra =
  ("Content-Type", content_type)
  :: ("Vary", Accept.vary_accept_value None)
  :: extra

let first_existing store candidates =
  let rec loop = function
    | [] -> None
    | path :: rest -> if store.has path then Some path else loop rest
  in
  loop candidates

let not_found_fallback =
  String.concat "\n"
    [
      "# Not found";
      "";
      "This path does not exist on scull7.com.";
      "";
      "## Where to go next";
      "";
      "- [Home](https://scull7.com/)";
      "- [About](https://scull7.com/about)";
      "- [Contact](https://scull7.com/contact)";
      "- [Privacy](https://scull7.com/privacy)";
      "- [Sitemap](https://scull7.com/sitemap.xml)";
      "- [llms.txt](https://scull7.com/llms.txt)";
      "";
    ]

let not_found_response chosen store =
  if chosen = Accept.markdown_type && store.has "/404.md" then
    {
      status = 404;
      headers = headers_for md_content_type [];
      body = store.read "/404.md";
    }
  else if store.has "/404.html" then
    {
      status = 404;
      headers = headers_for html_content_type [];
      body = store.read "/404.html";
    }
  else
    {
      status = 404;
      headers =
        headers_for
          (if chosen = Accept.markdown_type then md_content_type
           else plain_content_type)
          [];
      body = not_found_fallback;
    }

let requested accept = match accept with Some s -> s | None -> ""

let html_result store html_path md_path =
  match html_path with
  | Some path ->
      let extra =
        match md_path with
        | Some md ->
            [
              ( "Link",
                "<" ^ md
                ^ ">; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\""
              );
            ]
        | None -> []
      in
      Some
        {
          status = 200;
          headers = headers_for html_content_type extra;
          body = store.read path;
        }
  | None -> (
      match md_path with
      | Some path ->
          Some
            {
              status = 200;
              headers = headers_for md_content_type [];
              body = store.read path;
            }
      | None -> None)

let negotiate_request ~pathname ~accept store =
  let clean = Resolve.normalize_path pathname in
  if Resolve.is_passthrough_path clean then None
  else
    match Accept.preferred_type accept Accept.produces with
    | None ->
        Some
          {
            status = 406;
            headers =
              headers_for plain_content_type [ ("Cache-Control", "no-store") ];
            body = Accept.not_acceptable_body (requested accept);
          }
    | Some chosen ->
        let html_path = first_existing store (Resolve.html_candidates clean) in
        let md_path = first_existing store (Resolve.markdown_candidates clean) in
        let found =
          match (html_path, md_path) with None, None -> false | _ -> true
        in
        if not found then Some (not_found_response chosen store)
        else if chosen = Accept.markdown_type then
          match md_path with
          | Some path ->
              Some
                {
                  status = 200;
                  headers =
                    headers_for md_content_type
                      [
                        ( "Link",
                          "<" ^ path
                          ^ ">; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\""
                        );
                      ];
                  body = store.read path;
                }
          | None ->
              if Accept.preferred_type accept [ Accept.html_type ] = None then
                Some
                  {
                    status = 406;
                    headers =
                      headers_for plain_content_type
                        [ ("Cache-Control", "no-store") ];
                    body = Accept.not_acceptable_body (requested accept);
                  }
              else html_result store html_path md_path
        else html_result store html_path md_path
