(* Accept: text/markdown negotiation + agent-friendly 404.
   Spec: https://acceptmarkdown.com
   Emitted to netlify/edge-functions/negotiate.js during `npm run melange`. *)

type request
type response
type headers
type context
type url

let bypass = "x-negotiate-bypass"

external request_headers : request -> headers = "headers" [@@mel.get]
external request_method : request -> string = "method" [@@mel.get]
external request_url : request -> string = "url" [@@mel.get]
external headers_get_null : headers -> string -> string Js.null = "get" [@@mel.send]
external headers_set : headers -> string -> string -> unit = "set" [@@mel.send]
external new_headers : headers -> headers = "Headers" [@@mel.new]
external new_url : string -> url = "URL" [@@mel.new]
external new_url2 : string -> string -> url = "URL" [@@mel.new]
external url_pathname : url -> string = "pathname" [@@mel.get]
external context_next : context -> response Js.Promise.t = "next" [@@mel.send]

external new_request : url -> < headers : string Js.Dict.t > Js.t -> request
  = "Request"
[@@mel.new]

external fetch : request -> response Js.Promise.t = "fetch"
external response_ok : response -> bool = "ok" [@@mel.get]
external response_status : response -> int = "status" [@@mel.get]
external response_headers : response -> headers = "headers" [@@mel.get]
external response_body : response -> 'a = "body" [@@mel.get]
external response_text : response -> string Js.Promise.t = "text" [@@mel.send]

external new_response :
  'body -> < status : int ; headers : string Js.Dict.t > Js.t -> response
  = "Response"
[@@mel.new]

external new_response_headers :
  'body -> < status : int ; headers : headers > Js.t -> response = "Response"
[@@mel.new]

let header_get headers name =
  Js.Null.toOption (headers_get_null headers name)

let last_segment pathname =
  match List.rev (String.split_on_char '/' pathname) with
  | [] -> ""
  | last :: _ -> last

let with_headers status content_type body extra =
  let headers = Js.Dict.empty () in
  Js.Dict.set headers "Content-Type" content_type;
  Js.Dict.set headers "Vary" (Accept.vary_accept_value None);
  List.iter (fun (k, v) -> Js.Dict.set headers k v) extra;
  new_response body [%mel.obj { status; headers }]

let fetch_sibling request pathname =
  let url = new_url2 pathname (request_url request) in
  let headers = Js.Dict.empty () in
  Js.Dict.set headers bypass "1";
  fetch (new_request url [%mel.obj { headers }])

let rec first_ok_md request paths =
  match paths with
  | [] -> Js.Promise.resolve None
  | path :: rest ->
      fetch_sibling request path
      |> Js.Promise.then_ (fun res ->
             if response_ok res then Js.Promise.resolve (Some (path, res))
             else first_ok_md request rest)

let body_for request md_res =
  if request_method request = "HEAD" then
    Js.Promise.resolve (Js.Null.empty : string Js.null)
  else
    response_text md_res
    |> Js.Promise.then_ (fun text -> Js.Promise.resolve (Js.Null.return text))

let config =
  [%mel.obj
    {
      path = "/*";
      excludedPath =
        [|
          "/assets/*";
          "/styles/*";
          "/og.png";
          "/og.svg";
          "/openapi.json";
          "/mcp";
          "/interview";
          "/interview/*";
        |];
    }]

let default =
  fun [@u] request context ->
    if header_get (request_headers request) bypass = Some "1" then
      context_next context
    else
      let meth = request_method request in
      if meth <> "GET" && meth <> "HEAD" then context_next context
      else
        let url = new_url (request_url request) in
        let pathname = url_pathname url in
        if
          pathname = "/mcp"
          || pathname = "/openapi.json"
          || String.starts_with ~prefix:"/interview" pathname
        then context_next context
        else
        let last = last_segment pathname in
        if String.contains last '.' then context_next context
        else
          let accept = header_get (request_headers request) "accept" in
          let early =
            Plan.plan_negotiation ~accept ~page_md_exists:false ()
          in
          if early.action = "not-acceptable" then
            Js.Promise.resolve
              (with_headers 406 "text/plain; charset=utf-8"
                 (Accept.not_acceptable_body
                    (match accept with Some s -> s | None -> ""))
                 [ ("Cache-Control", "no-store") ])
          else
            let clean = Resolve.normalize_path (url_pathname url) in
            let md_paths = Resolve.markdown_candidates clean in
            let after_page_md (page : (string * response) option) =
              match (early.chosen, page) with
              | Some chosen, Some (md_path, md_res)
                when chosen = Accept.markdown_type ->
                  body_for request md_res
                  |> Js.Promise.then_ (fun body ->
                         Js.Promise.resolve
                           (with_headers 200 "text/markdown; charset=utf-8" body
                              [
                                ( "Link",
                                  "<" ^ md_path
                                  ^ ">; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\""
                                );
                              ]))
              | _ ->
                  context_next context
                  |> Js.Promise.then_ (fun origin ->
                         let plan =
                           Plan.plan_negotiation ~accept ~page_md_exists:false
                             ~origin_status:(response_status origin) ()
                         in
                         if plan.action = "not-acceptable" then
                           Js.Promise.resolve
                             (with_headers 406 "text/plain; charset=utf-8"
                                (Accept.not_acceptable_body
                                   (match accept with
                                   | Some s -> s
                                   | None -> ""))
                                [ ("Cache-Control", "no-store") ])
                         else if plan.action = "not-found-markdown" then
                           fetch_sibling request "/404.md"
                           |> Js.Promise.then_ (fun md404 ->
                                  if response_ok md404 then
                                    body_for request md404
                                    |> Js.Promise.then_ (fun body ->
                                           Js.Promise.resolve
                                             (with_headers 404
                                                "text/markdown; charset=utf-8"
                                                body []))
                                  else
                                    let headers =
                                      new_headers (response_headers origin)
                                    in
                                    headers_set headers "Vary"
                                      (Accept.vary_accept_value
                                         (header_get headers "Vary"));
                                    Js.Promise.resolve
                                      (new_response_headers
                                         (response_body origin)
                                         [%mel.obj { status = 404; headers }]))
                         else
                           let headers =
                             new_headers (response_headers origin)
                           in
                           headers_set headers "Vary"
                             (Accept.vary_accept_value
                                (header_get headers "Vary"));
                           let ct =
                             match header_get headers "content-type" with
                             | Some s -> s
                             | None -> ""
                           in
                           if
                             response_status origin <> 404
                             && Js.String.includes ~search:"text/html" ct
                           then (
                             let md_path =
                               match md_paths with
                               | p :: _ -> p
                               | [] -> "/index.md"
                             in
                             let link =
                               "<" ^ md_path
                               ^ ">; rel=\"alternate\"; type=\"text/markdown\", </llms.txt>; rel=\"describedby\""
                             in
                             match header_get headers "Link" with
                             | Some existing ->
                                 headers_set headers "Link" (existing ^ ", " ^ link)
                             | None -> headers_set headers "Link" link);
                           Js.Promise.resolve
                             (new_response_headers (response_body origin)
                                [%mel.obj
                                  { status = response_status origin; headers }]))
            in
            if early.chosen = Some Accept.markdown_type then
              first_ok_md request md_paths
              |> Js.Promise.then_ after_page_md
            else after_page_md None
