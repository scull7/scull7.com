(* HTTP + MCP surfaces for interview-me. *)

type request
type response
type headers
type url
type url_search

external request_method : request -> string = "method" [@@mel.get]
external request_url : request -> string = "url" [@@mel.get]
external request_headers : request -> headers = "headers" [@@mel.get]
external request_text : request -> string Js.Promise.t = "text" [@@mel.send]
external headers_get_null : headers -> string -> string Js.null = "get"
[@@mel.send]
external new_url : string -> url = "URL" [@@mel.new]
external url_pathname : url -> string = "pathname" [@@mel.get]
external url_search_params : url -> url_search = "searchParams" [@@mel.get]
external search_get_null : url_search -> string -> string Js.null = "get"
[@@mel.send]

external new_response :
  string -> < status : int ; headers : string Js.Dict.t > Js.t -> response
  = "Response"
[@@mel.new]

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let header_get headers name =
  Js.Null.toOption (headers_get_null headers name)

let query_get url name = Js.Null.toOption (search_get_null (url_search_params url) name)

let cors_headers extra =
  let h = Js.Dict.empty () in
  Js.Dict.set h "Access-Control-Allow-Origin" "*";
  Js.Dict.set h "Access-Control-Allow-Methods" "GET,POST,OPTIONS";
  Js.Dict.set h "Access-Control-Allow-Headers" "Content-Type, Authorization";
  List.iter (fun (k, v) -> Js.Dict.set h k v) extra;
  h

let respond status content_type body extra =
  new_response body
    [%mel.obj
      { status; headers = cors_headers (("Content-Type", content_type) :: extra) }]

let json_status status json =
  respond status "application/json; charset=utf-8"
    (Interview_json.pretty json) []

let json_ok json = json_status 200 json
let json_created json = json_status 201 json
let json_accepted json = json_status 202 json

let error_res e =
  json_status (Interview_service.error_code e) (Interview_service.error_json e)

let html_page title body =
  respond 200 "text/html; charset=utf-8"
    ("<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"/><title>"
   ^ title ^ "</title></head><body>" ^ body ^ "</body></html>")
    []

let wants_html headers =
  match header_get headers "accept" with
  | None -> true
  | Some a ->
      Js.String.includes ~search:"text/html" (String.lowercase_ascii a)
      && not
           (Js.String.includes ~search:"application/json"
              (String.lowercase_ascii a))

let read_object req =
  request_text req >>= fun text ->
  return
    (if String.trim text = "" then Js.Dict.empty ()
     else
       match Interview_json.parse_object text with
       | Some dict -> dict
       | None -> Js.Dict.empty ())

let field_any dict keys =
  let rec loop = function
    | [] -> None
    | k :: rest -> (
        match Interview_json.opt_string_field dict k with
        | Some v -> Some v
        | None -> loop rest)
  in
  loop keys

let session_json (s : Interview_store.session) =
  Interview_json.obj
    ([
       ("id", Interview_json.str s.id);
       ("company", Interview_json.str s.company);
       ("role", Interview_json.str s.role);
       ("recruiter_name", Interview_json.str s.recruiter_name);
       ("work_email", Interview_json.str s.work_email);
       ("verified", Interview_json.bool s.verified);
       ( "completed",
         Interview_json.arr (List.map Interview_json.str s.completed) );
     ]
    @
    match s.callback_url with
    | Some u -> [ ("callback_url", Interview_json.str u) ]
    | None -> [])

let ask_json (o : Interview_service.ask_output) =
  Interview_json.obj
    ([
       ("session_id", Interview_json.str o.session_id);
       ("answer", Interview_json.str o.answer);
       ("cited", Interview_json.bool o.cited);
       ("refused", Interview_json.bool o.refused);
       ( "required_progress",
         Interview_json.arr (List.map Interview_json.str o.required_progress) );
       ( "required_remaining",
         Interview_json.arr (List.map Interview_json.str o.required_remaining)
       );
     ]
    @ (match o.citation with
      | Some c ->
          [ ("citation", Interview_corpus.citation_json c) ]
      | None -> [])
    @
    match o.completed_item with
    | Some id -> [ ("completed_item", Interview_json.str id) ]
    | None -> [])

let hold_json (o : Interview_service.hold_output) =
  Interview_json.obj
    [
      ("hold_id", Interview_json.str o.hold_id);
      ("session_id", Interview_json.str o.session_id);
      ("start", Interview_json.str o.start);
      ("end", Interview_json.str o.end_);
      ("status", Interview_json.str "tentative");
      ("calendar_id", Interview_json.str o.calendar_id);
      ("calendar_event_id", Interview_json.str o.calendar_event_id);
      ("html_link", Interview_json.str o.html_link);
    ]

let mcp_tools =
  [
    ( "start_interview",
      "Start a named recruiter-agent session (company, role, recruiter name, \
       work email). Optional callback_url for webhooks.",
      [ "company"; "role"; "recruiter_name"; "work_email" ],
      [ "callback_url" ] );
    ( "ask_nathan",
      "Ask a question against published facts. Returns a cited answer or a \
       refusal. Q&A works without verification. Refuses do not complete the \
       required question set.",
      [ "session_id"; "question" ],
      [] );
    ( "request_verification",
      "Send a magic-link email to the session work email. The agent never \
       reads inbox. The human click issues a book token.",
      [ "session_id" ],
      [] );
    ( "create_hold",
      "Create a tentative Google Calendar hold. Requires book_token, a \
       completed required question set, and a work domain under the active-hold \
       cap. Default hold length is 1 hour if end is omitted.",
      [ "start"; "book_token" ],
      [ "end" ] );
    ( "get_resume",
      "Return published resume facts from the same corpus as cited answers.",
      [],
      [] );
  ]

let tool_schema required optional =
  let props = Js.Dict.empty () in
  List.iter
    (fun name ->
      Js.Dict.set props name
        (Interview_json.obj [ ("type", Interview_json.str "string") ]))
    (required @ optional);
  Interview_json.obj
    [
      ("type", Interview_json.str "object");
      ( "required",
        Interview_json.arr (List.map Interview_json.str required) );
      ("properties", Js.Json.object_ props);
    ]

let tools_list_json () =
  Interview_json.obj
    [
      ( "tools",
        Interview_json.arr
          (List.map
             (fun (name, desc, req, opt) ->
               Interview_json.obj
                 [
                   ("name", Interview_json.str name);
                   ("description", Interview_json.str desc);
                   ("inputSchema", tool_schema req opt);
                 ])
             mcp_tools) );
    ]

let mcp_result json =
  Interview_json.obj
    [
      ( "content",
        Interview_json.arr
          [
            Interview_json.obj
              [
                ("type", Interview_json.str "text");
                ("text", Interview_json.str (Interview_json.pretty json));
              ];
          ] );
      ("structuredContent", json);
    ]

let mcp_error id code message data =
  Interview_json.obj
    [
      ("jsonrpc", Interview_json.str "2.0");
      ("id", id);
      ( "error",
        Interview_json.obj
          ([
             ("code", Interview_json.num (float_of_int code));
             ("message", Interview_json.str message);
           ]
          @
          match data with
          | None -> []
          | Some d -> [ ("data", d) ]) );
    ]

let mcp_ok id result =
  Interview_json.obj
    [
      ("jsonrpc", Interview_json.str "2.0");
      ("id", id);
      ("result", result);
    ]

let last_segments path n =
  let parts =
    path |> String.split_on_char '/' |> List.filter (fun s -> s <> "")
  in
  let rec take acc rest k =
    match (rest, k) with
    | _, 0 -> acc
    | [], _ -> acc
    | x :: xs, k -> take (x :: acc) xs (k - 1)
  in
  take [] (List.rev parts) n

let handle_start deps dict =
  Interview_service.start deps
    {
      company =
        (match field_any dict [ "company" ] with Some v -> v | None -> "");
      role = (match field_any dict [ "role" ] with Some v -> v | None -> "");
      recruiter_name =
        (match field_any dict [ "recruiter_name"; "recruiterName" ] with
        | Some v -> v
        | None -> "");
      work_email =
        (match field_any dict [ "work_email"; "workEmail" ] with
        | Some v -> v
        | None -> "");
      callback_url = field_any dict [ "callback_url"; "callbackUrl" ];
    }
  >>= function
  | Error e -> return (error_res e)
  | Ok session -> return (json_created (session_json session))

let handle_ask deps session_id dict =
  let question =
    match field_any dict [ "question" ] with Some v -> v | None -> ""
  in
  Interview_service.ask deps ~session_id ~question >>= function
  | Error e -> return (error_res e)
  | Ok out -> return (json_ok (ask_json out))

let handle_verify_request deps session_id =
  Interview_service.request_verification deps ~session_id >>= function
  | Error e -> return (error_res e)
  | Ok out ->
      return
        (json_accepted
           (Interview_json.obj
              [
                ("session_id", Interview_json.str out.session_id);
                ("sent", Interview_json.bool true);
              ]))

let handle_verify deps req url =
  match query_get url "token" with
  | None -> return (error_res (Interview_service.Invalid "token is required"))
  | Some token -> (
      Interview_service.verify deps ~signed:token >>= function
      | Error e ->
          if wants_html (request_headers req) then
            return
              (html_page "interview-me verify"
                 ("<h1>Verification failed</h1><p>"
                 ^ Interview_json.as_string (Interview_service.error_json e)
                 ^ "</p>"))
          else return (error_res e)
      | Ok out ->
          if wants_html (request_headers req) then
            return
              (html_page "interview-me book token"
                 ("<h1>Work email verified</h1><p>Give this book token to your \
                   recruiter agent. It is short-lived and scoped to this \
                   session.</p><pre>" ^ out.book_token
                ^ "</pre><p>Session " ^ out.session_id ^ "</p>"))
          else
            return
              (json_ok
                 (Interview_json.obj
                    [
                      ("session_id", Interview_json.str out.session_id);
                      ("book_token", Interview_json.str out.book_token);
                      ("expires_at", Interview_json.str out.expires_at);
                    ])))

let handle_hold deps dict =
  let start =
    match field_any dict [ "start" ] with Some v -> v | None -> ""
  in
  let end_ = field_any dict [ "end" ] in
  let book_token =
    match field_any dict [ "book_token"; "bookToken" ] with
    | Some v -> v
    | None -> ""
  in
  Interview_service.create_hold deps ~start ~end_ ~book_token >>= function
  | Error e -> return (error_res e)
  | Ok out -> return (json_created (hold_json out))

let handle_resume deps = return (json_ok (Interview_service.get_resume deps))

let handle_experience deps query =
  let hits = Interview_service.search_experience deps query in
  return
    (json_ok
       (Interview_json.obj
          [
            ( "results",
              Interview_json.arr
                (List.map
                   (fun (p : Interview_corpus.passage) ->
                     Interview_json.obj
                       [
                         ("source", Interview_json.str p.source);
                         ("path", Interview_json.str p.path);
                         ("quote", Interview_json.str p.text);
                       ])
                   hits) );
          ]))

let handle_ban deps req url =
  let kind =
    match query_get url "kind" with Some k -> k | None -> "address"
  in
  match query_get url "token" with
  | None -> return (error_res (Interview_service.Invalid "token is required"))
  | Some token -> (
      Interview_service.ban deps ~kind ~signed:token >>= function
      | Error e -> return (error_res e)
      | Ok (k, value) ->
          if wants_html (request_headers req) then
            return
              (html_page "interview-me ban"
                 ("<h1>Banned</h1><p>Banned this " ^ k ^ ": " ^ value ^ "</p>"))
          else
            return
              (json_ok
                 (Interview_json.obj
                    [
                      ("banned", Interview_json.str k);
                      ("value", Interview_json.str value);
                    ])))

let mcp_call deps name args =
  match name with
  | "start_interview" ->
      Interview_service.start deps
        {
          company =
            (match field_any args [ "company" ] with Some v -> v | None -> "");
          role = (match field_any args [ "role" ] with Some v -> v | None -> "");
          recruiter_name =
            (match field_any args [ "recruiter_name"; "recruiterName" ] with
            | Some v -> v
            | None -> "");
          work_email =
            (match field_any args [ "work_email"; "workEmail" ] with
            | Some v -> v
            | None -> "");
          callback_url = field_any args [ "callback_url"; "callbackUrl" ];
        }
      >>= (function
      | Error e -> return (Error e)
      | Ok s -> return (Ok (session_json s)))
  | "ask_nathan" ->
      let session_id =
        match field_any args [ "session_id"; "sessionId" ] with
        | Some v -> v
        | None -> ""
      in
      Interview_service.ask deps ~session_id
        ~question:
          (match field_any args [ "question" ] with Some v -> v | None -> "")
      >>= (function
      | Error e -> return (Error e) | Ok out -> return (Ok (ask_json out)))
  | "request_verification" ->
      let session_id =
        match field_any args [ "session_id"; "sessionId" ] with
        | Some v -> v
        | None -> ""
      in
      Interview_service.request_verification deps ~session_id >>= (function
      | Error e -> return (Error e)
      | Ok out ->
          return
            (Ok
               (Interview_json.obj
                  [
                    ("session_id", Interview_json.str out.session_id);
                    ("sent", Interview_json.bool true);
                  ])))
  | "create_hold" ->
      Interview_service.create_hold deps
        ~start:
          (match field_any args [ "start" ] with Some v -> v | None -> "")
        ~end_:(field_any args [ "end" ])
        ~book_token:
          (match field_any args [ "book_token"; "bookToken" ] with
          | Some v -> v
          | None -> "")
      >>= (function
      | Error e -> return (Error e) | Ok out -> return (Ok (hold_json out)))
  | "get_resume" -> return (Ok (Interview_service.get_resume deps))
  | other -> return (Error (Interview_service.Invalid ("unknown MCP tool: " ^ other)))

let handle_mcp deps req =
  read_object req >>= fun dict ->
  let id =
    match Js.Dict.get dict "id" with
    | Some json -> json
    | None -> Interview_json.null
  in
  let method_ = Interview_json.string_field dict "method" in
  match method_ with
  | "initialize" ->
      return
        (json_ok
           (mcp_ok id
              (Interview_json.obj
                 [
                   ("protocolVersion", Interview_json.str "2024-11-05");
                   ( "capabilities",
                     Interview_json.obj [ ("tools", Interview_json.obj []) ] );
                   ( "serverInfo",
                     Interview_json.obj
                       [
                         ("name", Interview_json.str "interview-me");
                         ("version", Interview_json.str "1.0.0");
                       ] );
                 ])))
  | "notifications/initialized" | "initialized" ->
      return (respond 204 "text/plain; charset=utf-8" "" [])
  | "ping" -> return (json_ok (mcp_ok id (Interview_json.obj [])))
  | "tools/list" -> return (json_ok (mcp_ok id (tools_list_json ())))
  | "tools/call" ->
      let params = Interview_json.object_field dict "params" in
      let name = Interview_json.string_field params "name" in
      let args = Interview_json.object_field params "arguments" in
      if not (List.exists (fun (n, _, _, _) -> n = name) mcp_tools) then
        return (json_ok (mcp_error id (-32601) ("Unknown tool: " ^ name) None))
      else
        mcp_call deps name args >>= (function
        | Error e ->
            return
              (json_ok
                 (mcp_error id (-32000) "tool error"
                    (Some (Interview_service.error_json e))))
        | Ok json -> return (json_ok (mcp_ok id (mcp_result json))))
  | "" ->
      return (json_ok (mcp_error id (-32600) "Missing JSON-RPC method" None))
  | other ->
      return
        (json_ok (mcp_error id (-32601) ("Unknown method: " ^ other) None))

let handle_rest deps req url =
  let path = url_pathname url in
  let meth = request_method req in
  if meth = "OPTIONS" then
    return (respond 204 "text/plain; charset=utf-8" "" [])
  else if path = "/openapi.json" && (meth = "GET" || meth = "HEAD") then
    return
      (json_ok (Interview_openapi.document ~site_url:deps.Interview_service.cfg.site_url))
  else if path = "/mcp" && meth = "GET" then
    return (json_ok (tools_list_json ()))
  else if path = "/mcp" && meth = "POST" then handle_mcp deps req
  else if path = "/interview/sessions" && meth = "POST" then
    read_object req >>= handle_start deps
  else if path = "/interview/holds" && meth = "POST" then
    read_object req >>= handle_hold deps
  else if path = "/interview/resume" && (meth = "GET" || meth = "HEAD") then
    handle_resume deps
  else if path = "/interview/experience" && (meth = "GET" || meth = "HEAD") then
    handle_experience deps
      (match query_get url "q" with Some q -> q | None -> "")
  else if path = "/interview/verify" && meth = "GET" then
    handle_verify deps req url
  else if path = "/interview/ban" && meth = "GET" then handle_ban deps req url
  else
    match last_segments path 3 with
    | [ "ask"; id; "sessions" ] when meth = "POST" && String.starts_with ~prefix:"/interview/sessions/" path ->
        read_object req >>= handle_ask deps id
    | [ "verify-request"; id; "sessions" ] when meth = "POST" ->
        handle_verify_request deps id
    | _ ->
        return
          (respond 404 "application/json; charset=utf-8"
             (Interview_json.pretty
                (Interview_json.obj [ ("error", Interview_json.str "not_found") ]))
             [])

let handle deps req = handle_rest deps req (new_url (request_url req))

let is_interview_path pathname =
  pathname = "/openapi.json" || pathname = "/mcp"
  || String.starts_with ~prefix:"/interview" pathname
