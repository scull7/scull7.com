(* Netlify function entry for interview-me. Melange emit; wrapper is generated. *)

type request = Interview_http.request
type context

external context_site : context -> < url : string Js.undefined > Js.t = "site"
[@@mel.get]

let read_if path =
  if Node.Fs.existsSync path then Some (Node.Fs.readFileAsUtf8Sync path)
  else None

let first_file candidates =
  let rec loop = function
    | [] -> None
    | p :: rest -> (
        match read_if p with Some body -> Some (p, body) | None -> loop rest)
  in
  loop candidates

let load_corpus root =
  let resume_json =
    match
      first_file
        [
          Node.Path.join [| root; "public/resume.json" |];
          Node.Path.join [| root; "dist/resume.json" |];
          Node.Path.join [| root; "resume.json" |];
        ]
    with
    | None -> Interview_json.obj []
    | Some (_, body) -> (
        try Interview_json.json_parse body with _ -> Interview_json.obj [])
  in
  let page name =
    match
      first_file
        [
          Node.Path.join [| root; "public"; name |];
          Node.Path.join [| root; "dist"; name |];
        ]
    with
    | None -> None
    | Some (_, body) -> Some ("/" ^ name, body)
  in
  let pages =
    [ "about.md"; "contact.md"; "llms-full.txt"; "llms.txt" ]
    |> List.filter_map page
  in
  Interview_corpus.of_pages ~resume_json pages

let origin_of request context (cfg : Interview_config.t) =
  match Js.Undefined.toOption (context_site context)##url with
  | Some u when String.trim u <> "" ->
      let s = String.trim u in
      if String.ends_with ~suffix:"/" s then
        String.sub s 0 (String.length s - 1)
      else s
  | _ -> (
      match
        Js.Re.exec ~str:(Interview_http.request_url request)
          [%mel.re "/^(https?:\\/\\/[^/]+)/"]
      with
      | None -> cfg.site_url
      | Some m -> (
          match Js.Nullable.toOption (Js.Re.captures m).(1) with
          | Some o -> o
          | None -> cfg.site_url))

let deps_for request context =
  let cfg0 = Interview_config.load () in
  let site_url = origin_of request context cfg0 in
  let cfg = { cfg0 with site_url } in
  {
    Interview_service.now_ms = Interview_crypto.now_ms;
    random_id = Interview_crypto.random_id;
    cfg;
    store = Interview_store.of_config cfg;
    corpus = load_corpus (Node.Process.cwd ());
    mail = Interview_mail.of_config cfg;
    calendar = Interview_calendar.of_config cfg;
    webhook = Interview_service.http_webhook ();
  }

let config =
  [%mel.obj
    { path = [| "/openapi.json"; "/mcp"; "/interview"; "/interview/*" |] }]

let default =
  fun [@u] request context ->
    try Interview_http.handle (deps_for request context) request
    with exn ->
      Js.Promise.resolve
        (Interview_http.respond 500 "application/json; charset=utf-8"
           (Interview_json.pretty
              (Interview_json.obj
                 [
                   ("error", Interview_json.str "internal");
                   ("message", Interview_json.str (Printexc.to_string exn));
                 ]))
           [])
