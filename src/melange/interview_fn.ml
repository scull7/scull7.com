(* Netlify function entry for interview-me. Melange emit; emit_artifacts
   esbuild-bundles this module so Lambda does not import `melange.js`. *)

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

let page_names = [ "about.md"; "contact.md"; "llms-full.txt"; "llms.txt" ]

let resume_candidates root =
  [
    Node.Path.join [| root; "public/resume.json" |];
    Node.Path.join [| root; "dist/resume.json" |];
    Node.Path.join [| root; "resume.json" |];
    Node.Path.join [| root; "netlify/functions/_corpus/resume.json" |];
    Node.Path.join [| root; "_corpus/resume.json" |];
  ]

let page_candidates root name =
  [
    Node.Path.join [| root; "public"; name |];
    Node.Path.join [| root; "dist"; name |];
    Node.Path.join [| root; "netlify/functions/_corpus"; name |];
    Node.Path.join [| root; "_corpus"; name |];
  ]

let load_corpus_disk root =
  let resume =
    match first_file (resume_candidates root) with
    | None -> None
    | Some (_, body) -> (
        try Some (Interview_json.json_parse body) with _ -> None)
  in
  let page name =
    match first_file (page_candidates root name) with
    | None -> None
    | Some (_, body) -> Some ("/" ^ name, body)
  in
  let pages = page_names |> List.filter_map page in
  (resume, pages)

let fetch_text origin path =
  let headers = Js.Dict.empty () in
  Interview_http_fetch.get (origin ^ path) ~headers
  |> Js.Promise.then_ (fun res ->
         if Interview_http_fetch.response_ok res then
           Interview_http_fetch.response_text res
           |> Js.Promise.then_ (fun body ->
                  Js.Promise.resolve
                    (if String.trim body = "" then None else Some body))
         else Js.Promise.resolve None)
  |> Js.Promise.catch (fun _ -> Js.Promise.resolve None)

let rec fetch_pages origin acc = function
  | [] -> Js.Promise.resolve (List.rev acc)
  | name :: rest ->
      fetch_text origin ("/" ^ name)
      |> Js.Promise.then_ (fun body ->
             let acc =
               match body with
               | None -> acc
               | Some t -> ("/" ^ name, t) :: acc
             in
             fetch_pages origin acc rest)

let load_corpus origin root =
  let resume, pages = load_corpus_disk root in
  match resume with
  | Some resume_json ->
      Js.Promise.resolve (Interview_corpus.of_pages ~resume_json pages)
  | None ->
      fetch_text origin "/resume.json"
      |> Js.Promise.then_ (fun resume_body ->
             (if pages = [] then fetch_pages origin [] page_names
              else Js.Promise.resolve pages)
             |> Js.Promise.then_ (fun pages ->
                    let resume_json =
                      match resume_body with
                      | None -> Interview_json.obj []
                      | Some body -> (
                          try Interview_json.json_parse body
                          with _ -> Interview_json.obj [])
                    in
                    Js.Promise.resolve
                      (Interview_corpus.of_pages ~resume_json pages)))

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

external js_message : 'a -> string Js.undefined = "message" [@@mel.get]
external js_payload : 'a -> string Js.undefined = "_1" [@@mel.get]
external js_cause : 'a -> 'a Js.undefined = "cause" [@@mel.get]

let useful = function
  | Some s when String.trim s <> "" && s <> "Failure" && s <> "Error" ->
      Some (String.trim s)
  | _ -> None

let rec peek_exn err depth =
  if depth > 3 then None
  else
    match useful (Js.Undefined.toOption (js_payload err)) with
    | Some s -> Some s
    | None -> (
        match useful (Js.Undefined.toOption (js_message err)) with
        | Some s -> Some s
        | None -> (
            match Js.Undefined.toOption (js_cause err) with
            | Some c -> peek_exn c (depth + 1)
            | None -> None))

let fail_message exn =
  match peek_exn exn 0 with
  | Some s -> s
  | None ->
      let ocaml = Printexc.to_string exn in
      if ocaml <> "Failure" then ocaml else "function failed"

let fail_res exn =
  Interview_http.respond 500 "application/json; charset=utf-8"
    (Interview_json.pretty
       (Interview_json.obj
          [
            ("error", Interview_json.str "invalid");
            ("message", Interview_json.str (fail_message exn));
          ]))
    []

let deps_for request context =
  let cfg0 = Interview_config.load () in
  let site_url = origin_of request context cfg0 in
  let cfg = { cfg0 with site_url } in
  load_corpus site_url (Node.Process.cwd ())
  |> Js.Promise.then_ (fun corpus ->
         Js.Promise.resolve
           {
             Interview_service.now_ms = Interview_clock.now_ms;
             random_id = Interview_clock.random_id;
             cfg;
             store = Interview_store.of_config cfg;
             corpus;
           })

let config =
  [%mel.obj
    {
      path =
        [|
          "/openapi.json";
          "/mcp";
          "/interview";
          "/interview/*";
          "/.netlify/functions/interview";
          "/.netlify/functions/interview/*";
        |];
    }]

let default =
  fun [@u] request context ->
    (try
       deps_for request context
       |> Js.Promise.then_ (fun deps -> Interview_http.handle deps request)
     with exn -> Js.Promise.resolve (fail_res exn))
    |> Js.Promise.catch (fun err ->
           let message =
             match Js.Undefined.toOption (js_message err) with
             | Some m when String.trim m <> "" -> m
             | _ -> "function failed"
           in
           Js.Promise.resolve (fail_res (Failure message)))
