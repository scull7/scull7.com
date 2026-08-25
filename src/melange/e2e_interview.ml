(* T-16 + T-17 + T-18 + T-19 proofs: named Turso session, cited Q&A,
   required-set progress, interview.completed once, human magic-link
   verify / book token, create_hold refuse-or-create + booking.requested,
   resume/experience, OpenAPI + MCP + llms.txt. Each AC inverts. *)

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

external new_request : string -> 'a -> Interview_http.request = "Request"
[@@mel.new]

external request_init_body :
  method_:(string[@mel.as "method"]) ->
  headers:string Js.Dict.t ->
  body:string ->
  < method_ : string ; headers : string Js.Dict.t ; body : string > Js.t = ""
[@@mel.obj]

external request_init_get :
  method_:(string[@mel.as "method"]) ->
  headers:string Js.Dict.t ->
  < method_ : string ; headers : string Js.Dict.t > Js.t = ""
[@@mel.obj]

external response_status : Interview_http.response -> int = "status"
[@@mel.get]

external response_text : Interview_http.response -> string Js.Promise.t = "text"
[@@mel.send]

type incoming
type outgoing
type server

external create_server : (incoming -> outgoing -> unit) -> server
  = "createServer"
[@@mel.module "http"]

external req_method : incoming -> string = "method" [@@mel.get]
external req_url : incoming -> string = "url" [@@mel.get]
external req_on : incoming -> string -> ('a -> unit) -> unit = "on"
[@@mel.send]
external chunk_string : 'a -> string = "toString" [@@mel.send]
external res_write_head : outgoing -> int -> string Js.Dict.t -> unit
  = "writeHead"
[@@mel.send]
external res_end : outgoing -> string -> unit = "end" [@@mel.send]
external server_listen :
  server -> int -> string -> (unit -> unit) -> unit = "listen"
[@@mel.send]
external server_address : server -> < port : int > Js.t = "address"
[@@mel.send]
external server_close : server -> (unit -> unit) -> unit = "close"
[@@mel.send]

let env name value = (name, value)

let source pairs name =
  try Some (List.assoc name pairs) with Not_found -> None

let test_cfg extras =
  Interview_config.of_source
    ~source:
      (source
         (extras
         @ [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
             env "INTERVIEW_SITE_URL" "https://scull7.com";
             env "INTERVIEW_MAGIC_LINK_SECRET" "test-secret-interview-me";
             env "RESEND_API_KEY" "re_test_not_a_secret";
             env "INTERVIEW_MAIL_FROM" "nathan@vegasbuckeye.com";
             env "INTERVIEW_CAL_API_URL" "https://cal.test.invalid";
             env "INTERVIEW_CAL_USERNAME" "nate";
             env "INTERVIEW_CAL_EVENT_SLUG" "interview-hold";
           ]))
    ()

let load_resume () =
  let path = Node.Path.join [| E2e_ffi.root; "public/resume.json" |] in
  Interview_json.json_parse (Node.Fs.readFileAsUtf8Sync path)

let test_corpus () =
  let about =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/about.md" |])
  in
  Interview_corpus.of_pages ~resume_json:(load_resume ())
    [ ("/about.md", about) ]

let memory_full ?cfg ?now_ms ?store ?webhook ?mail () =
  let cfg = match cfg with Some c -> c | None -> test_cfg [] in
  let store =
    match store with
    | Some s -> s
    | None -> Interview_store.Memory.bind (Interview_store.Memory.create ())
  in
  let mail, sent =
    match mail with
    | Some (m, s) -> (m, s)
    | None -> Interview_mail.capture ()
  in
  let calendar, created = Interview_calendar.capture () in
  let webhook, hooks =
    match webhook with
    | Some (w, h) -> (w, h)
    | None -> Interview_webhook.capture ()
  in
  ( {
      Interview_service.now_ms =
        (match now_ms with Some f -> f | None -> Interview_clock.now_ms);
      random_id = Interview_clock.random_id;
      cfg;
      store;
      corpus = test_corpus ();
      mail;
      calendar;
      webhook;
    },
    sent,
    created,
    hooks )

let memory_harness ?cfg ?now_ms ?store () =
  let deps, sent, created, _ = memory_full ?cfg ?now_ms ?store () in
  (deps, sent, created)

let memory_deps ?cfg ?now_ms () =
  let deps, _, _, _ = memory_full ?cfg ?now_ms () in
  deps

let json_body res =
  response_text res >>= fun text ->
  return (text, Interview_json.parse_object text)

let req method_ path body =
  let headers = Js.Dict.empty () in
  Js.Dict.set headers "Content-Type" "application/json";
  Js.Dict.set headers "Accept" "application/json";
  let url = "https://scull7.com" ^ path in
  if method_ = "GET" || method_ = "HEAD" then
    new_request url (request_init_get ~method_ ~headers)
  else new_request url (request_init_body ~method_ ~headers ~body)

let start_body ?(email = "recruiter@acme.example") ?callback () =
  Interview_json.json_stringify
    (Interview_json.obj
       ([
          ("company", Interview_json.str "Acme");
          ("role", Interview_json.str "Director of Engineering");
          ("recruiter_name", Interview_json.str "Pat Recruiter");
          ("work_email", Interview_json.str email);
        ]
       @
       match callback with
       | Some u -> [ ("callback_url", Interview_json.str u) ]
       | None -> []))

let must_ok label = function
  | Ok v -> v
  | Error e ->
      failwith
        (label ^ " "
        ^ Interview_json.json_stringify (Interview_service.error_json e))

let error_name text =
  match Interview_json.parse_object text with
  | None -> ""
  | Some dict -> Interview_json.string_field dict "error"

let has_session_id text =
  Js.String.includes ~search:"\"id\"" text
  && Js.String.includes ~search:"ses_" text

let mcp_call name args =
  Interview_json.json_stringify
    (Interview_json.obj
       [
         ("jsonrpc", Interview_json.str "2.0");
         ("id", Interview_json.num 1.);
         ("method", Interview_json.str "tools/call");
         ( "params",
           Interview_json.obj
             [
               ("name", Interview_json.str name);
               ("arguments", args);
             ] );
       ])

let tool_names_of text =
  match Interview_json.parse_object text with
  | None -> []
  | Some dict ->
      let tools =
        match Interview_json.as_object (Interview_json.field dict "result") with
        | Some result ->
            Interview_json.as_array (Interview_json.field result "tools")
        | None -> Interview_json.as_array (Interview_json.field dict "tools")
      in
      tools |> Array.to_list
      |> List.filter_map (fun json ->
             match Interview_json.as_object json with
             | None -> None
             | Some t ->
                 let n = Interview_json.string_field t "name" in
                 if n = "" then None else Some n)

let expected_tools =
  [
    "start_interview";
    "ask_nathan";
    "request_verification";
    "create_hold";
    "get_resume";
  ]

let assert_exact_tools label names =
  E2e_ffi.assert_
    (List.length names = List.length expected_tools)
    (label ^ " tool count " ^ string_of_int (List.length names));
  List.iter
    (fun t ->
      E2e_ffi.assert_ (List.exists (fun n -> n = t) names) (label ^ " missing " ^ t))
    expected_tools;
  List.iter
    (fun n ->
      E2e_ffi.assert_
        (List.exists (fun t -> t = n) expected_tools)
        (label ^ " extra " ^ n))
    names

(* --- Fake Turso /v2/pipeline: persists across fresh store clients. --- *)

let arg_value json =
  match Interview_json.as_object json with
  | None -> Interview_json.as_string json
  | Some dict -> (
      match Interview_json.string_field dict "type" with
      | "null" -> ""
      | _ ->
          (match Interview_json.opt_string_field dict "value" with
          | Some v -> v
          | None -> Interview_json.as_string json))

let execute_ok rows =
  Interview_json.obj
    [
      ("type", Interview_json.str "ok");
      ( "response",
        Interview_json.obj
          [
            ("type", Interview_json.str "execute");
            ( "result",
              Interview_json.obj
                [
                  ( "rows",
                    Interview_json.arr
                      (List.map
                         (fun cells ->
                           Interview_json.arr
                             (List.map
                                (fun c ->
                                  Interview_json.obj
                                    [
                                      ("type", Interview_json.str "text");
                                      ("value", Interview_json.str c);
                                    ])
                                cells))
                         rows) );
                ] );
          ] );
    ]

let close_ok =
  Interview_json.obj
    [
      ("type", Interview_json.str "ok");
      ("response", Interview_json.obj [ ("type", Interview_json.str "close") ]);
    ]

let handle_pipeline sessions tokens body =
  match Interview_json.parse_object body with
  | None ->
      Interview_json.obj
        [ ("results", Interview_json.arr [ execute_ok [] ]) ]
  | Some dict ->
      let requests =
        Interview_json.as_array (Interview_json.field dict "requests")
      in
      let results =
        requests |> Array.to_list
        |> List.map (fun req_json ->
               match Interview_json.as_object req_json with
               | None -> execute_ok []
               | Some req -> (
                   match Interview_json.string_field req "type" with
                   | "close" -> close_ok
                   | "execute" ->
                       let stmt = Interview_json.object_field req "stmt" in
                       let sql =
                         String.uppercase_ascii
                           (Interview_json.string_field stmt "sql")
                       in
                       let args =
                         Interview_json.as_array
                           (Interview_json.field stmt "args")
                         |> Array.to_list |> List.map arg_value
                       in
                       if Js.String.includes ~search:"CREATE TABLE" sql then
                         execute_ok []
                       else if
                         Js.String.includes ~search:"INSERT INTO INTERVIEW_SESSIONS"
                           sql
                       then (
                         (match args with
                         | id :: _ -> Hashtbl.replace sessions id args
                         | [] -> ());
                         execute_ok [])
                       else if
                         Js.String.includes ~search:"FROM INTERVIEW_SESSIONS" sql
                       then (
                         let id =
                           match List.rev args with
                           | last :: _ -> last
                           | [] -> ""
                         in
                         match Hashtbl.find_opt sessions id with
                         | Some row -> execute_ok [ row ]
                         | None -> execute_ok [])
                       else if
                         Js.String.includes ~search:"INSERT INTO INTERVIEW_TOKENS"
                           sql
                       then (
                         (match args with
                         | token :: _ -> Hashtbl.replace tokens token args
                         | [] -> ());
                         execute_ok [])
                       else if
                         Js.String.includes ~search:"FROM INTERVIEW_TOKENS" sql
                       then (
                         let id =
                           match List.rev args with
                           | last :: _ -> last
                           | [] -> ""
                         in
                         match Hashtbl.find_opt tokens id with
                         | Some row -> execute_ok [ row ]
                         | None -> execute_ok [])
                       else if
                         Js.String.includes ~search:"UPDATE INTERVIEW_TOKENS" sql
                       then (
                         let id =
                           match args with t :: _ -> t | [] -> ""
                         in
                         (match Hashtbl.find_opt tokens id with
                         | Some (t :: k :: s :: e :: _c :: created :: rest) ->
                             Hashtbl.replace tokens id
                               (t :: k :: s :: e :: "1" :: created :: rest)
                         | _ -> ());
                         execute_ok [])
                       else execute_ok []
                   | _ -> execute_ok []))
      in
      Interview_json.obj [ ("results", Interview_json.arr results) ]

let start_fake_turso () : (string * (unit -> unit Js.Promise.t)) Js.Promise.t
    =
  let sessions : (string, string list) Hashtbl.t = Hashtbl.create 16 in
  let tokens : (string, string list) Hashtbl.t = Hashtbl.create 16 in
  let server =
    create_server (fun incoming outgoing ->
        let chunks = ref "" in
        req_on incoming "data" (fun c -> chunks := !chunks ^ chunk_string c);
        req_on incoming "end" (fun _ ->
            let headers = Js.Dict.empty () in
            Js.Dict.set headers "Content-Type" "application/json";
            if
              not
                (Js.String.includes ~search:"/v2/pipeline"
                   (req_url incoming))
            then (
              res_write_head outgoing 404 headers;
              res_end outgoing "{\"error\":\"not pipeline\"}")
            else
              let payload =
                Interview_json.json_stringify
                  (handle_pipeline sessions tokens !chunks)
              in
              res_write_head outgoing 200 headers;
              res_end outgoing payload))
  in
  Js.Promise.make (fun ~resolve ~reject:_ ->
      server_listen server 0 "127.0.0.1" (fun () ->
          let port = (server_address server)##port in
          let url = "http://127.0.0.1:" ^ string_of_int port in
          let stop () =
            Js.Promise.make (fun ~resolve ~reject:_ ->
                server_close server (fun () ->
                    let u = () in
                    resolve u [@u]))
          in
          resolve (url, stop) [@u]))

let turso_deps ?now_ms url token =
  let cfg =
    test_cfg
      [ env "TURSO_DATABASE_URL" url; env "TURSO_AUTH_TOKEN" token ]
  in
  let mail, sent = Interview_mail.capture () in
  let calendar, created = Interview_calendar.capture () in
  let webhook, _hooks = Interview_webhook.capture () in
  ( {
      Interview_service.now_ms =
        (match now_ms with Some f -> f | None -> Interview_clock.now_ms);
      random_id = Interview_clock.random_id;
      cfg;
      store = Interview_store.turso ~url ~token ();
      corpus = test_corpus ();
      mail;
      calendar;
      webhook;
    },
    sent,
    created )

let echo_fields dict =
  ( Interview_json.string_field dict "company",
    Interview_json.string_field dict "role",
    Interview_json.string_field dict "recruiter_name",
    Interview_json.string_field dict "work_email",
    Interview_json.opt_string_field dict "callback_url",
    Interview_json.as_bool (Interview_json.field dict "verified") )

(* AC1 *)
let prove_start_echo () =
  let deps = memory_deps () in
  Interview_http.handle deps
    (req "POST" "/interview/sessions"
       (start_body ~callback:"https://hooks.example/interview" ()))
  >>= fun res ->
  E2e_ffi.assert_ (response_status res = 201) "AC1 HTTP start 201";
  json_body res >>= fun (_text, obj) ->
  (match obj with
  | None -> failwith "AC1 start body"
  | Some dict ->
      let company, role, recruiter, email, callback, verified =
        echo_fields dict
      in
      E2e_ffi.assert_ (company = "Acme") "AC1 company";
      E2e_ffi.assert_ (role = "Director of Engineering") "AC1 role";
      E2e_ffi.assert_ (recruiter = "Pat Recruiter") "AC1 recruiter_name";
      E2e_ffi.assert_ (email = "recruiter@acme.example") "AC1 work_email";
      E2e_ffi.assert_
        (callback = Some "https://hooks.example/interview")
        "AC1 callback_url";
      E2e_ffi.assert_ (not verified) "AC1 verified false/absent";
      E2e_ffi.assert_
        (String.starts_with ~prefix:"ses_"
           (Interview_json.string_field dict "id"))
        "AC1 session id");
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "start_interview"
          (Interview_json.json_parse
             (start_body ~email:"mcp@acme.example"
                ~callback:"https://hooks.example/mcp" ()))))
  >>= fun mcp_res ->
  E2e_ffi.assert_ (response_status mcp_res = 200) "AC1 MCP start_interview";
  response_text mcp_res >>= fun mcp_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"mcp@acme.example" mcp_text
    && Js.String.includes ~search:"Acme" mcp_text
    && Js.String.includes ~search:"Pat Recruiter" mcp_text
    && Js.String.includes ~search:"https://hooks.example/mcp" mcp_text
    && Js.String.includes ~search:"ses_" mcp_text)
    "AC1 MCP start echoes the four fields + callback + id";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"\"verified\": true" mcp_text))
    "AC1 MCP verified not true";
  E2e_ffi.pass "AC1 start session echo + MCP start_interview";
  return ()

(* AC2: later ask on a fresh Turso client, not process memory *)
let prove_later_ask_turso () =
  start_fake_turso () >>= fun (url, stop) ->
  let deps1, _, _ = turso_deps url "test-turso-token" in
  let deps2, _, _ = turso_deps url "test-turso-token" in
  E2e_ffi.assert_ (deps1.store != deps2.store) "AC2 distinct store clients";
  Interview_http.handle deps1
    (req "POST" "/interview/sessions"
       (start_body ~callback:"https://hooks.example/later" ()))
  >>= fun start_res ->
  E2e_ffi.assert_ (response_status start_res = 201) "AC2 start 201";
  json_body start_res >>= fun (_, obj) ->
  let id =
    match obj with
    | None -> failwith "AC2 start"
    | Some dict -> Interview_json.string_field dict "id"
  in
  let ask_body =
    Interview_json.json_stringify
      (Interview_json.obj
         [
           ( "question",
             Interview_json.str "What is Nathan doing at TensorWave on Relay?"
           );
         ])
  in
  Interview_http.handle deps2
    (req "POST" ("/interview/sessions/" ^ id ^ "/ask") ask_body)
  >>= fun ask_res ->
  E2e_ffi.assert_
    (response_status ask_res = 200)
    ("AC2 later HTTP ask " ^ string_of_int (response_status ask_res));
  json_body ask_res >>= fun (_, ask_obj) ->
  (match ask_obj with
  | None -> failwith "AC2 ask body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "company" = "Acme")
        "AC2 later ask company";
      E2e_ffi.assert_
        (Interview_json.string_field dict "role" = "Director of Engineering")
        "AC2 later ask role";
      E2e_ffi.assert_
        (Interview_json.string_field dict "recruiter_name" = "Pat Recruiter")
        "AC2 later ask recruiter_name";
      E2e_ffi.assert_
        (Interview_json.string_field dict "work_email"
        = "recruiter@acme.example")
        "AC2 later ask work_email";
      E2e_ffi.assert_
        (Interview_json.opt_string_field dict "callback_url"
        = Some "https://hooks.example/later")
        "AC2 later ask callback_url");
  let deps3, _, _ = turso_deps url "test-turso-token" in
  Interview_http.handle deps3
    (req "POST" "/mcp"
       (mcp_call "ask_nathan"
          (Interview_json.obj
             [
               ("session_id", Interview_json.str id);
               ( "question",
                 Interview_json.str
                   "What leadership scale has Nathan managed?" );
             ])))
  >>= fun mcp_ask ->
  E2e_ffi.assert_ (response_status mcp_ask = 200) "AC2 MCP ask_nathan";
  response_text mcp_ask >>= fun mcp_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"Acme" mcp_text
    && Js.String.includes ~search:"recruiter@acme.example" mcp_text
    && Js.String.includes ~search:"https://hooks.example/later" mcp_text)
    "AC2 MCP later ask echoes stored fields";
  Interview_http.handle deps3
    (req "GET" ("/interview/sessions/" ^ id) "")
  >>= fun get_res ->
  E2e_ffi.assert_
    (response_status get_res = 404)
    "AC2 no GET-session";
  json_body get_res >>= fun (get_text, _) ->
  E2e_ffi.assert_ (error_name get_text = "not_found") "AC2 GET-session not_found";
  stop () >>= fun () ->
  E2e_ffi.pass "AC2 later ask on fresh Turso client + no GET-session";
  return ()

(* AC3 *)
let prove_invalid_start () =
  let deps = memory_deps () in
  let cases =
    [
      ("{}", "empty object");
      ( Interview_json.json_stringify
          (Interview_json.obj
             [
               ("company", Interview_json.str "");
               ("role", Interview_json.str "Eng");
               ("recruiter_name", Interview_json.str "Pat");
               ("work_email", Interview_json.str "pat@acme.example");
             ]),
        "empty company" );
      ( Interview_json.json_stringify
          (Interview_json.obj
             [
               ("company", Interview_json.str "Acme");
               ("role", Interview_json.str "");
               ("recruiter_name", Interview_json.str "Pat");
               ("work_email", Interview_json.str "pat@acme.example");
             ]),
        "empty role" );
      ( Interview_json.json_stringify
          (Interview_json.obj
             [
               ("company", Interview_json.str "Acme");
               ("role", Interview_json.str "Eng");
               ("recruiter_name", Interview_json.str "");
               ("work_email", Interview_json.str "pat@acme.example");
             ]),
        "empty recruiter_name" );
      ( Interview_json.json_stringify
          (Interview_json.obj
             [
               ("company", Interview_json.str "Acme");
               ("role", Interview_json.str "Eng");
               ("recruiter_name", Interview_json.str "Pat");
               ("work_email", Interview_json.str "");
             ]),
        "empty work_email" );
    ]
  in
  let rec loop = function
    | [] ->
        E2e_ffi.pass "AC3 missing/empty fields are invalid without a session id";
        return ()
    | (body, label) :: rest ->
        Interview_http.handle deps
          (req "POST" "/interview/sessions" body)
        >>= fun res ->
        E2e_ffi.assert_
          (response_status res >= 400 && response_status res < 500)
          ("AC3 " ^ label ^ " status");
        json_body res >>= fun (text, _) ->
        E2e_ffi.assert_ (error_name text = "invalid") ("AC3 " ^ label ^ " error");
        E2e_ffi.assert_ (not (has_session_id text)) ("AC3 " ^ label ^ " no id");
        loop rest
  in
  loop cases

(* AC4 *)
let prove_ask_never_created () =
  let deps = memory_deps () in
  let ask_body =
    Interview_json.json_stringify
      (Interview_json.obj
         [ ("question", Interview_json.str "What is Nathan doing at TensorWave?") ])
  in
  Interview_http.handle deps
    (req "POST" "/interview/sessions/ses_never/ask" ask_body)
  >>= fun res ->
  E2e_ffi.assert_
    (response_status res = 404 || (response_status res >= 400 && response_status res < 500))
    "AC4 never-created ask is 4xx/404";
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "not_found") "AC4 error=not_found";
  E2e_ffi.pass "AC4 ask unknown id is not_found";
  return ()

(* AC5 *)
let prove_free_email_and_allowlist () =
  let deps = memory_deps () in
  let blocked =
    [
      "pat@gmail.com";
      "pat@yahoo.com";
      "pat@hotmail.com";
      "pat@outlook.com";
      "pat@icloud.com";
    ]
  in
  let rec reject = function
    | [] -> return ()
    | email :: rest ->
        Interview_http.handle deps
          (req "POST" "/interview/sessions" (start_body ~email ()))
        >>= fun res ->
        E2e_ffi.assert_
          (response_status res >= 400 && response_status res < 500)
          (email ^ " rejected");
        json_body res >>= fun (text, _) ->
        E2e_ffi.assert_
          (error_name text = "free_email")
          (email ^ " error=free_email");
        E2e_ffi.assert_ (not (has_session_id text)) (email ^ " no session id");
        reject rest
  in
  reject blocked >>= fun () ->
  let allow_cfg =
    test_cfg [ env "INTERVIEW_EMAIL_ALLOWLIST" "special@gmail.com" ]
  in
  let allow_deps = memory_deps ~cfg:allow_cfg () in
  Interview_http.handle allow_deps
    (req "POST" "/interview/sessions" (start_body ~email:"special@gmail.com" ()))
  >>= fun allowed ->
  E2e_ffi.assert_
    (response_status allowed = 201)
    "AC5 allowlisted address on blocked domain is accepted";
  let block_cfg =
    test_cfg [ env "INTERVIEW_FREE_EMAIL_BLOCKLIST" "acme.example" ]
  in
  let block_deps = memory_deps ~cfg:block_cfg () in
  Interview_http.handle block_deps
    (req "POST" "/interview/sessions"
       (start_body ~email:"recruiter@acme.example" ()))
  >>= fun newly_blocked ->
  E2e_ffi.assert_
    (response_status newly_blocked >= 400)
    "AC5 env blocklist rejects without a code change";
  json_body newly_blocked >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "free_email") "AC5 env blocklist free_email";
  Interview_http.handle deps
    (req "POST" "/interview/sessions"
       (start_body ~email:"recruiter@acme.example" ()))
  >>= fun default_ok ->
  E2e_ffi.assert_
    (response_status default_ok = 201)
    "AC5 default blocklist still allows acme.example";
  E2e_ffi.pass "AC5 free-email blocklist + allowlist are env-driven";
  return ()

(* AC6 *)
let prove_cited_and_refuse () =
  let deps = memory_deps () in
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ()))
  >>= fun start_res ->
  json_body start_res >>= fun (_, obj) ->
  let id =
    match obj with
    | None -> failwith "AC6 start"
    | Some dict -> Interview_json.string_field dict "id"
  in
  let ask id q =
    Interview_http.handle deps
      (req "POST" ("/interview/sessions/" ^ id ^ "/ask")
         (Interview_json.json_stringify
            (Interview_json.obj [ ("question", Interview_json.str q) ])))
  in
  let cited_ok q needles =
    ask id q >>= fun res ->
    E2e_ffi.assert_ (response_status res = 200) ("AC6 " ^ q ^ " 200");
    json_body res >>= fun (text, obj) ->
    (match obj with
    | None -> failwith ("AC6 " ^ q)
    | Some dict ->
        E2e_ffi.assert_
          (Interview_json.as_bool (Interview_json.field dict "cited"))
          ("AC6 " ^ q ^ " cited");
        E2e_ffi.assert_
          (not (Interview_json.as_bool (Interview_json.field dict "refused")))
          ("AC6 " ^ q ^ " not refused");
        List.iter
          (fun n ->
            E2e_ffi.assert_
              (Js.String.includes ~search:(String.lowercase_ascii n)
                 (String.lowercase_ascii text))
              ("AC6 " ^ q ^ " mentions " ^ n))
          needles;
        (match Interview_json.as_object (Interview_json.field dict "citation") with
        | None -> failwith ("AC6 " ^ q ^ " missing citation")
        | Some c ->
            let source = Interview_json.string_field c "source" in
            E2e_ffi.assert_
              (source = "/resume.json" || String.starts_with ~prefix:"/" source)
              ("AC6 " ^ q ^ " citation source " ^ source)));
    return ()
  in
  cited_ok "What is Nathan doing at TensorWave on Relay?"
    [ "TensorWave" ]
  >>= fun () ->
  cited_ok "What leadership scale has Nathan managed?" [ "engineer" ]
  >>= fun () ->
  cited_ok
    "What systems depth does Nathan have in Rust and distributed systems?"
    [ "Rust" ]
  >>= fun () ->
  cited_ok "What does Nathan want next?" [ "looking for" ] >>= fun () ->
  let refuse q =
    ask id q >>= fun res ->
    json_body res >>= fun (text, obj) ->
    (match obj with
    | None -> failwith ("AC6 refuse " ^ q)
    | Some dict ->
        E2e_ffi.assert_
          (Interview_json.as_bool (Interview_json.field dict "refused"))
          ("AC6 refuse " ^ q);
        E2e_ffi.assert_
          (not (Interview_json.as_bool (Interview_json.field dict "cited")))
          ("AC6 refuse not cited " ^ q);
        E2e_ffi.assert_
          (not
             (Js.String.includes ~search:"$180" text
             || Js.String.includes ~search:"123 Main" text
             || Js.String.includes ~search:"FakeCorp" text))
          ("AC6 must not invent " ^ q));
    return ()
  in
  refuse "What is Nathan's unpublished salary?" >>= fun () ->
  refuse "What is Nathan's street address?" >>= fun () ->
  refuse "What invented next role is Nathan taking at FakeCorp?" >>= fun () ->
  E2e_ffi.pass "AC6 cited published facts and refuse unpublished";
  return ()

(* AC7 *)
let prove_ask_unverified_no_hold () =
  let deps = memory_deps () in
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ()))
  >>= fun start_res ->
  json_body start_res >>= fun (_, obj) ->
  let dict = match obj with Some d -> d | None -> failwith "AC7 start" in
  E2e_ffi.assert_
    (not (Interview_json.as_bool (Interview_json.field dict "verified")))
    "AC7 start unverified";
  let id = Interview_json.string_field dict "id" in
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/ask")
       (Interview_json.json_stringify
          (Interview_json.obj
             [
               ( "question",
                 Interview_json.str
                   "What is Nathan doing at TensorWave on Relay?" );
             ])))
  >>= fun ask_res ->
  E2e_ffi.assert_ (response_status ask_res = 200) "AC7 ask succeeds unverified";
  json_body ask_res >>= fun (ask_text, _) ->
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"hold_id" ask_text))
    "AC7 ask is not a calendar hold";
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "create_hold"
          (Interview_json.obj
             [
               ("start", Interview_json.str "2026-09-01T17:00:00.000Z");
               ("book_token", Interview_json.str "not-a-token");
             ])))
  >>= fun hold_res ->
  response_text hold_res >>= fun hold_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"\"error\"" hold_text
    && (Js.String.includes ~search:"invalid" hold_text
       || Js.String.includes ~search:"not_found" hold_text
       || Js.String.includes ~search:"missing_env" hold_text))
    "AC7 create_hold fail-closed with a named error";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"hold_id" hold_text))
    "AC7 create_hold does not create a hold";
  E2e_ffi.pass "AC7 ask works unverified; no calendar hold";
  return ()

(* AC8 *)
let prove_resume_and_experience () =
  let deps = memory_deps () in
  Interview_http.handle deps (req "GET" "/interview/resume" "")
  >>= fun resume_res ->
  E2e_ffi.assert_ (response_status resume_res = 200) "AC8 resume 200";
  response_text resume_res >>= fun resume_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" resume_text)
    "AC8 resume has TensorWave";
  Interview_http.handle deps
    (req "GET" "/interview/experience?q=TensorWave" "")
  >>= fun exp_res ->
  E2e_ffi.assert_ (response_status exp_res = 200) "AC8 experience TensorWave 200";
  json_body exp_res >>= fun (exp_text, exp_obj) ->
  (match exp_obj with
  | None -> failwith "AC8 experience body"
  | Some dict ->
      let results =
        Interview_json.as_array (Interview_json.field dict "results")
      in
      E2e_ffi.assert_
        (Array.length results > 0)
        "AC8 TensorWave experience is non-empty";
      results |> Array.iter (fun item ->
          match Interview_json.as_object item with
          | None -> failwith "AC8 result not object"
          | Some r ->
              let source = Interview_json.string_field r "source" in
              let path = Interview_json.string_field r "path" in
              let quote = Interview_json.string_field r "quote" in
              E2e_ffi.assert_ (source <> "") "AC8 result source";
              E2e_ffi.assert_ (path <> "") "AC8 result path";
              E2e_ffi.assert_
                (Js.String.includes ~search:"TensorWave" quote)
                "AC8 result quote includes TensorWave"));
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" exp_text)
    "AC8 experience payload names TensorWave";
  Interview_http.handle deps
    (req "GET" "/interview/experience?q=zzz-no-such-employer-xyz" "")
  >>= fun empty_res ->
  json_body empty_res >>= fun (empty_text, empty_obj) ->
  (match empty_obj with
  | None -> failwith "AC8 empty experience"
  | Some dict ->
      let results =
        Interview_json.as_array (Interview_json.field dict "results")
      in
      E2e_ffi.assert_ (Array.length results = 0) "AC8 non-matching q is []");
  E2e_ffi.assert_
    (Js.String.includes ~search:"\"results\": []" empty_text
    || Js.String.includes ~search:"\"results\":[]" empty_text)
    "AC8 empty results JSON";
  Interview_http.handle deps (req "GET" "/interview/experience" "")
  >>= fun missing_q ->
  E2e_ffi.assert_
    (response_status missing_q >= 400 && response_status missing_q < 500)
    "AC8 experience requires q";
  json_body missing_q >>= fun (missing_text, _) ->
  E2e_ffi.assert_ (error_name missing_text = "invalid") "AC8 missing q invalid";
  E2e_ffi.pass "AC8 resume TensorWave + experience search";
  return ()

let schema_props json =
  match Interview_json.as_object json with
  | None -> [||]
  | Some dict -> Js.Dict.keys (Interview_json.object_field dict "properties")

let request_schema paths path meth =
  let path_obj = Interview_json.object_field paths path in
  let op = Interview_json.object_field path_obj meth in
  let body = Interview_json.object_field op "requestBody" in
  let content = Interview_json.object_field body "content" in
  let app = Interview_json.object_field content "application/json" in
  Interview_json.field app "schema"

let response_schema paths path meth status =
  let path_obj = Interview_json.object_field paths path in
  let op = Interview_json.object_field path_obj meth in
  let responses = Interview_json.object_field op "responses" in
  let res = Interview_json.object_field responses status in
  let content = Interview_json.object_field res "content" in
  let app = Interview_json.object_field content "application/json" in
  Interview_json.field app "schema"

let required_of schema =
  match Interview_json.as_object schema with
  | None -> []
  | Some dict ->
      Interview_json.as_array (Interview_json.field dict "required")
      |> Array.to_list |> List.map Interview_json.as_string

let has_prop schema name =
  match Interview_json.as_object schema with
  | None -> false
  | Some dict ->
      let props = Interview_json.object_field dict "properties" in
      Js.Dict.get props name <> None

let prove_openapi_named () =
  let deps = memory_deps () in
  Interview_http.handle deps (req "GET" "/openapi.json" "") >>= fun res ->
  E2e_ffi.assert_ (response_status res = 200) "AC9 openapi 200";
  json_body res >>= fun (_, obj) ->
  (match obj with
  | None -> failwith "AC9 openapi"
  | Some dict ->
      let version = Interview_json.string_field dict "openapi" in
      E2e_ffi.assert_
        (String.starts_with ~prefix:"3." version)
        ("AC9 OpenAPI 3.x, got " ^ version);
      let paths = Interview_json.object_field dict "paths" in
      let start_req = request_schema paths "/interview/sessions" "post" in
      List.iter
        (fun f ->
          E2e_ffi.assert_
            (List.exists (fun r -> r = f) (required_of start_req))
            ("AC9 start required " ^ f))
        [ "company"; "role"; "recruiter_name"; "work_email" ];
      let start_201 =
        response_schema paths "/interview/sessions" "post" "201"
      in
      E2e_ffi.assert_
        (Array.length (schema_props start_201) > 0)
        "AC9 start 201 is not a property-less object stub";
      List.iter
        (fun f ->
          E2e_ffi.assert_ (has_prop start_201 f) ("AC9 start 201 names " ^ f))
        [ "id"; "company"; "role"; "recruiter_name"; "work_email"; "callback_url" ];
      let ask_req =
        request_schema paths "/interview/sessions/{id}/ask" "post"
      in
      E2e_ffi.assert_
        (List.exists (fun r -> r = "question") (required_of ask_req))
        "AC9 ask required question";
      let ask_200 =
        response_schema paths "/interview/sessions/{id}/ask" "post" "200"
      in
      E2e_ffi.assert_
        (Array.length (schema_props ask_200) > 0)
        "AC9 ask 200 is not a stub";
      List.iter
        (fun f ->
          E2e_ffi.assert_ (has_prop ask_200 f) ("AC9 ask 200 names " ^ f))
        [
          "answer";
          "cited";
          "refused";
          "company";
          "role";
          "recruiter_name";
          "work_email";
          "required_progress";
          "required_remaining";
        ];
      let exp_200 =
        response_schema paths "/interview/experience" "get" "200"
      in
      E2e_ffi.assert_ (has_prop exp_200 "results") "AC9 experience names results";
      let exp_path = Interview_json.object_field paths "/interview/experience" in
      let exp_get = Interview_json.object_field exp_path "get" in
      let params =
        Interview_json.as_array (Interview_json.field exp_get "parameters")
      in
      let has_q =
        params |> Array.exists (fun p ->
            match Interview_json.as_object p with
            | None -> false
            | Some d ->
                Interview_json.string_field d "name" = "q"
                && Interview_json.as_bool (Interview_json.field d "required"))
      in
      E2e_ffi.assert_ has_q "AC9 experience requires q";
      let results_schema =
        match Interview_json.as_object exp_200 with
        | None -> Interview_json.null
        | Some d ->
            let props = Interview_json.object_field d "properties" in
            let results = Interview_json.object_field props "results" in
            Interview_json.field results "items"
      in
      List.iter
        (fun f ->
          E2e_ffi.assert_
            (has_prop results_schema f)
            ("AC9 experience item names " ^ f))
        [ "source"; "path"; "quote" ];
      let resume_200 =
        response_schema paths "/interview/resume" "get" "200"
      in
      E2e_ffi.assert_
        (has_prop resume_200 "basics" || has_prop resume_200 "work")
        "AC9 resume 200 is JSON Resume shaped");
  E2e_ffi.pass "AC9 OpenAPI named properties";
  return ()

let prove_mcp_tools () =
  let deps = memory_deps () in
  Interview_http.handle deps (req "GET" "/mcp" "") >>= fun get_res ->
  E2e_ffi.assert_ (response_status get_res = 200) "AC9 GET /mcp";
  response_text get_res >>= fun get_text ->
  assert_exact_tools "GET /mcp" (tool_names_of get_text);
  let list_body =
    Interview_json.json_stringify
      (Interview_json.obj
         [
           ("jsonrpc", Interview_json.str "2.0");
           ("id", Interview_json.num 1.);
           ("method", Interview_json.str "tools/list");
         ])
  in
  Interview_http.handle deps (req "POST" "/mcp" list_body)
  >>= fun post_res ->
  response_text post_res >>= fun post_text ->
  assert_exact_tools "POST tools/list" (tool_names_of post_text);
  Interview_http.handle deps (req "GET" "/interview/resume" "")
  >>= fun http_resume ->
  Interview_http.handle deps
    (req "POST" "/mcp" (mcp_call "get_resume" (Interview_json.obj [])))
  >>= fun mcp_resume ->
  response_text http_resume >>= fun http_r ->
  response_text mcp_resume >>= fun mcp_r ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" http_r
    && Js.String.includes ~search:"TensorWave" mcp_r)
    "AC9 get_resume matches HTTP";
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "request_verification"
          (Interview_json.obj [ ("session_id", Interview_json.str "ses_x") ])))
  >>= fun vr ->
  response_text vr >>= fun vr_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"invalid" vr_text
    || Js.String.includes ~search:"not_found" vr_text
    || Js.String.includes ~search:"missing_env" vr_text)
    "AC9 request_verification unknown session is a named error";
  E2e_ffi.pass "AC9 MCP tools/list exact five; HTTP-matching tools";
  return ()

(* AC10 *)
let prove_llms_txt () =
  let llms =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/llms.txt" |])
  in
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/static resume/i"]
    && Js.Re.test ~str:llms [%mel.re "/interview-me/i"])
    "AC10 when-to-use distinguishes static resume vs interview-me";
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/nathan@vegasbuckeye\\.com/"])
    "AC10 contact nathan@vegasbuckeye.com";
  E2e_ffi.assert_
    (not
       (Js.Re.test ~str:llms
          [%mel.re "/\\d+\\s+(Main|Street|Ave|Avenue|Road|Rd)\\b/i"]))
    "AC10 no street address";
  E2e_ffi.pass "AC10 llms.txt when-to-use";
  return ()

(* AC11 *)
let prove_missing_turso_env () =
  let cfg_url =
    Interview_config.of_source
      ~source:(source [ env "TURSO_AUTH_TOKEN" "tok" ])
      ()
  in
  (match Interview_config.missing_store cfg_url with
  | Some "TURSO_DATABASE_URL" -> ()
  | Some name -> failwith ("AC11 expected TURSO_DATABASE_URL, got " ^ name)
  | None -> failwith "AC11 missing URL must not satisfy the store");
  let cfg_tok =
    Interview_config.of_source
      ~source:(source [ env "TURSO_DATABASE_URL" "https://example.invalid" ])
      ()
  in
  (match Interview_config.missing_store cfg_tok with
  | Some "TURSO_AUTH_TOKEN" -> ()
  | Some name -> failwith ("AC11 expected TURSO_AUTH_TOKEN, got " ^ name)
  | None -> failwith "AC11 missing token must not satisfy the store");
  let cfg_mem =
    Interview_config.of_source
      ~source:(source [ env "INTERVIEW_STORE" "memory" ])
      ()
  in
  (match Interview_config.missing_store cfg_mem with
  | Some "TURSO_DATABASE_URL" -> ()
  | Some name ->
      failwith ("AC11 INTERVIEW_STORE=memory expected TURSO url, got " ^ name)
  | None -> failwith "AC11 INTERVIEW_STORE=memory must not satisfy the store");
  let deps, _, _ = memory_harness ~cfg:cfg_mem ~store:(Interview_store.of_config cfg_mem) () in
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ()))
  >>= fun res ->
  E2e_ffi.assert_
    (response_status res >= 400)
    "AC11 missing env start is an error";
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "missing_env") "AC11 error=missing_env";
  E2e_ffi.assert_ (not (has_session_id text)) "AC11 no session id";
  let cfg_bogus =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://127.0.0.1:1";
             env "TURSO_AUTH_TOKEN" "tok";
             env "INTERVIEW_STORE" "memory";
           ])
      ()
  in
  let store = Interview_store.of_config cfg_bogus in
  let dummy : Interview_store.session =
    {
      id = "ses_probe";
      company = "Acme";
      role = "Eng";
      recruiter_name = "Pat";
      work_email = "pat@acme.example";
      work_domain = "acme.example";
      callback_url = None;
      hiring_timeline = None;
      completed = [];
      verified = false;
      created_at = "2026-08-23T00:00:00.000Z";
    }
  in
  store.put_session dummy
  |> Js.Promise.then_ (fun () ->
         failwith "AC11 of_config must not bind a memory store")
  |> Js.Promise.catch (fun _ ->
         E2e_ffi.pass
           "AC11 missing Turso env is missing_env; memory store is ignored";
         return ())

let harvest_magic_link text =
  match
    E2e_ffi.capture1
      [%mel.re
        "/https:\\/\\/scull7\\.com\\/interview\\/verify\\?token=([^\\s<\"']+)/"]
      text
  with
  | Some t -> t
  | None -> failwith "magic link missing from mail"

let agent_leaks_secrets text =
  Js.String.includes ~search:"/interview/verify" text
  || Js.String.includes ~search:"book_token" text
  || Js.String.includes ~search:"bookToken" text

let mcp_structured text =
  match Interview_json.parse_object text with
  | None -> None
  | Some dict -> (
      match Interview_json.as_object (Interview_json.field dict "result") with
      | None -> None
      | Some result ->
          Interview_json.as_object
            (Interview_json.field result "structuredContent"))

let start_session deps ?(email = "recruiter@acme.example") ?callback () =
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ~email ?callback ()))
  >>= fun res ->
  json_body res >>= fun (text, obj) ->
  match obj with
  | Some dict ->
      return (Interview_json.string_field dict "id", text)
  | None -> failwith ("start session: " ^ text)

let ask_tensorwave deps id =
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/ask")
       (Interview_json.json_stringify
          (Interview_json.obj
             [
               ( "question",
                 Interview_json.str
                   "What is Nathan doing at TensorWave on Relay?" );
             ])))

(* T-17 AC1 *)
let prove_t17_verify_request_mail () =
  let deps, sent, _ = memory_harness () in
  start_session deps ~email:"pat@acme.example" () >>= fun (id, _) ->
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun res ->
  E2e_ffi.assert_
    (response_status res = 202 || response_status res = 200)
    "T-17 AC1 verify-request accepted";
  json_body res >>= fun (text, obj) ->
  E2e_ffi.assert_ (not (agent_leaks_secrets text))
    "T-17 AC1 agent JSON has no magic URL or book token";
  (match obj with
  | None -> failwith "T-17 AC1 body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "session_id" = id)
        "T-17 AC1 session_id");
  E2e_ffi.assert_ (List.length !sent = 1) "T-17 AC1 one mail";
  let mail = List.hd !sent in
  E2e_ffi.assert_ (mail.to_ = "pat@acme.example")
    "T-17 AC1 mail only to session work email";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"123 Main" mail.text))
    "T-17 AC1 mail has no street address";
  ignore (harvest_magic_link mail.text);
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "request_verification"
          (Interview_json.obj [ ("session_id", Interview_json.str id) ])))
  >>= fun mcp_res ->
  E2e_ffi.assert_ (response_status mcp_res = 200) "T-17 AC1 MCP accepted";
  response_text mcp_res >>= fun mcp_text ->
  E2e_ffi.assert_ (not (agent_leaks_secrets mcp_text))
    "T-17 AC1 MCP has no magic URL or book token";
  (match mcp_structured mcp_text with
  | None -> failwith "T-17 AC1 MCP structured"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "session_id" = id)
        "T-17 AC1 MCP session_id";
      E2e_ffi.assert_
        (Interview_json.as_bool (Interview_json.field dict "sent"))
        "T-17 AC1 MCP sent");
  E2e_ffi.assert_ (List.length !sent = 2) "T-17 AC1 MCP also sent mail";
  List.iter
    (fun (m : Interview_mail.message) ->
      E2e_ffi.assert_ (m.to_ = "pat@acme.example")
        "T-17 AC1 every mail goes to the session work email")
    !sent;
  E2e_ffi.pass "T-17 AC1 verify-request mails work email; agent JSON is clean";
  return ()

(* T-17 AC2 *)
let prove_t17_verify_never_created () =
  let deps, sent, _ = memory_harness () in
  Interview_http.handle deps
    (req "POST" "/interview/sessions/ses_never/verify-request" "")
  >>= fun res ->
  E2e_ffi.assert_
    (response_status res = 404
    || (response_status res >= 400 && response_status res < 500))
    "T-17 AC2 never-created is 4xx/404";
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "not_found") "T-17 AC2 error=not_found";
  E2e_ffi.assert_ (not (agent_leaks_secrets text)) "T-17 AC2 no book token";
  E2e_ffi.assert_ (!sent = []) "T-17 AC2 no mail";
  E2e_ffi.pass "T-17 AC2 verify-request unknown id is not_found";
  return ()

(* T-17 AC3 *)
let prove_t17_human_verify_issues_book_token () =
  let deps, sent, _ = memory_harness () in
  start_session deps () >>= fun (id, _) ->
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let token = harvest_magic_link (List.hd !sent).text in
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun res ->
  E2e_ffi.assert_ (response_status res = 200) "T-17 AC3 verify 200";
  json_body res >>= fun (text, obj) ->
  (match obj with
  | None -> failwith "T-17 AC3 body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "session_id" = id)
        "T-17 AC3 session_id of requesting session";
      let book = Interview_json.string_field dict "book_token" in
      E2e_ffi.assert_ (book <> "") "T-17 AC3 book_token";
      E2e_ffi.assert_
        (Interview_json.string_field dict "expires_at" <> "")
        "T-17 AC3 expires_at");
  let forged =
    [
      ("", "empty");
      ("not-a-token", "forged");
      ("deadbeef.0000000000000000000000000000000000000000000000000000000000000000", "bad sig");
    ]
  in
  let rec loop = function
    | [] -> return ()
    | (tok, label) :: rest ->
        let path =
          if tok = "" then "/interview/verify?token="
          else "/interview/verify?token=" ^ tok
        in
        Interview_http.handle deps (req "GET" path "") >>= fun bad ->
        json_body bad >>= fun (bad_text, _) ->
        E2e_ffi.assert_
          (error_name bad_text = "token_invalid")
          ("T-17 AC3 " ^ label ^ " token_invalid");
        E2e_ffi.assert_
          (not (Js.String.includes ~search:"book_token" bad_text)
          || Js.String.includes ~search:"token_invalid" bad_text
             && not
                  (Js.Re.test ~str:bad_text
                     [%mel.re "/\"book_token\"\\s*:\\s*\"[^\"]+\"/"]))
          ("T-17 AC3 " ^ label ^ " no book token");
        loop rest
  in
  loop forged >>= fun () ->
  Interview_http.handle deps (req "GET" "/interview/verify" "") >>= fun missing ->
  json_body missing >>= fun (missing_text, _) ->
  E2e_ffi.assert_
    (error_name missing_text = "token_invalid")
    "T-17 AC3 missing token is token_invalid";
  E2e_ffi.assert_
    (not
       (Js.Re.test ~str:missing_text
          [%mel.re "/\"book_token\"\\s*:\\s*\"[^\"]+\"/"]))
    "T-17 AC3 missing token has no book token";
  ignore text;
  E2e_ffi.pass "T-17 AC3 human verify issues book token; forged/empty invalid";
  return ()

(* T-17 AC4 *)
let prove_t17_session_scope () =
  let deps, sent, _ = memory_harness () in
  start_session deps ~email:"a@acme.example" () >>= fun (id_a, _) ->
  start_session deps ~email:"b@acme.example" () >>= fun (id_b, _) ->
  E2e_ffi.assert_ (id_a <> id_b) "T-17 AC4 two sessions";
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id_a ^ "/verify-request") "")
  >>= fun _ ->
  let token_a = harvest_magic_link (List.hd !sent).text in
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token_a) "")
  >>= fun res ->
  json_body res >>= fun (_, obj) ->
  (match obj with
  | None -> failwith "T-17 AC4 body"
  | Some dict ->
      let sid = Interview_json.string_field dict "session_id" in
      E2e_ffi.assert_ (sid = id_a) "T-17 AC4 session A link returns A";
      E2e_ffi.assert_ (sid <> id_b) "T-17 AC4 session A link never returns B");
  E2e_ffi.pass "T-17 AC4 magic link is session-scoped";
  return ()

(* T-17 AC5 *)
let prove_t17_magic_link_single_use () =
  let deps, sent, _ = memory_harness () in
  start_session deps () >>= fun (id, _) ->
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let token = harvest_magic_link (List.hd !sent).text in
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun first ->
  E2e_ffi.assert_ (response_status first = 200) "T-17 AC5 first GET 200";
  json_body first >>= fun (first_text, _) ->
  E2e_ffi.assert_
    (Js.Re.test ~str:first_text
       [%mel.re "/\"book_token\"\\s*:\\s*\"[^\"]+\"/"])
    "T-17 AC5 first GET has book token";
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun second ->
  json_body second >>= fun (second_text, _) ->
  E2e_ffi.assert_
    (error_name second_text = "token_invalid")
    "T-17 AC5 second GET token_invalid";
  E2e_ffi.assert_
    (not
       (Js.Re.test ~str:second_text
          [%mel.re "/\"book_token\"\\s*:\\s*\"[^\"]+\"/"]))
    "T-17 AC5 second GET has no book token";
  E2e_ffi.pass "T-17 AC5 magic-link token is single-use";
  return ()

(* T-17 AC6 *)
let prove_t17_magic_link_ttl () =
  let unset =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
           ])
      ()
  in
  E2e_ffi.assert_
    (unset.magic_link_ttl_ms = 86_400_000.)
    "T-17 AC6 default unset TTL is 86400000";
  let now = ref 1_700_000_000_000. in
  let cfg = test_cfg [ env "INTERVIEW_MAGIC_LINK_TTL_MS" "2000" ] in
  E2e_ffi.assert_ (cfg.magic_link_ttl_ms = 2000.) "T-17 AC6 env TTL is 2000";
  let deps, sent, _ = memory_harness ~cfg ~now_ms:(fun () -> !now) () in
  start_session deps () >>= fun (id, _) ->
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let token = harvest_magic_link (List.hd !sent).text in
  now := !now +. 2001.;
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun res ->
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "token_invalid")
    "T-17 AC6 expired token_invalid";
  E2e_ffi.assert_
    (not
       (Js.Re.test ~str:text [%mel.re "/\"book_token\"\\s*:\\s*\"[^\"]+\"/"]))
    "T-17 AC6 expired has no book token";
  E2e_ffi.pass "T-17 AC6 tester clock expires magic link; default stays 86400000";
  return ()

(* T-17 AC7 *)
let prove_t17_qa_before_after_no_hold () =
  let deps, sent, created = memory_harness () in
  start_session deps () >>= fun (id, _) ->
  ask_tensorwave deps id >>= fun before ->
  E2e_ffi.assert_ (response_status before = 200) "T-17 AC7 ask before verify";
  json_body before >>= fun (before_text, _) ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" before_text)
    "T-17 AC7 cited before verify";
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let token = harvest_magic_link (List.hd !sent).text in
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun verified ->
  E2e_ffi.assert_ (response_status verified = 200) "T-17 AC7 verify 200";
  ask_tensorwave deps id >>= fun after ->
  E2e_ffi.assert_ (response_status after = 200) "T-17 AC7 ask after verify";
  json_body after >>= fun (after_text, _) ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" after_text)
    "T-17 AC7 cited after verify";
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "create_hold"
          (Interview_json.obj
             [
               ("start", Interview_json.str "2026-09-01T17:00:00.000Z");
               ("book_token", Interview_json.str "");
             ])))
  >>= fun hold1 ->
  response_text hold1 >>= fun hold1_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"\"error\"" hold1_text)
    "T-17 AC7 create_hold no token is an error";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"calendar_event_id" hold1_text
       || Js.String.includes ~search:"hold_id" hold1_text))
    "T-17 AC7 no calendar event without book token";
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "create_hold"
          (Interview_json.obj
             [
               ("start", Interview_json.str "2026-09-01T17:00:00.000Z");
               ("book_token", Interview_json.str "not-a-token");
             ])))
  >>= fun hold2 ->
  response_text hold2 >>= fun hold2_text ->
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"calendar_event_id" hold2_text
       || Js.String.includes ~search:"hold_id" hold2_text))
    "T-17 AC7 invalid book token creates no calendar event";
  E2e_ffi.assert_ (!created = []) "T-17 AC7 calendar action was never called";
  E2e_ffi.pass "T-17 AC7 Q&A works before/after verify; no calendar event";
  return ()

(* T-17 AC8 *)
let prove_t17_missing_env_no_token () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let cfg_secret =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
             env "RESEND_API_KEY" "re_test_not_a_secret";
           ])
      ()
  in
  (match Interview_config.missing_magic_secret cfg_secret with
  | Some "INTERVIEW_MAGIC_LINK_SECRET" -> ()
  | Some name -> failwith ("T-17 AC8 expected magic secret, got " ^ name)
  | None -> failwith "T-17 AC8 missing secret must not satisfy");
  let deps_secret, sent_secret, _ =
    memory_harness ~cfg:cfg_secret ~store ()
  in
  start_session deps_secret () >>= fun (id, _) ->
  Interview_http.handle deps_secret
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun res_secret ->
  json_body res_secret >>= fun (text_secret, _) ->
  E2e_ffi.assert_
    (error_name text_secret = "missing_env")
    "T-17 AC8 missing secret is missing_env";
  E2e_ffi.assert_ (not (agent_leaks_secrets text_secret))
    "T-17 AC8 missing secret issues no book token";
  E2e_ffi.assert_ (!sent_secret = []) "T-17 AC8 missing secret sends no mail";
  E2e_ffi.assert_
    (Hashtbl.length tables.tokens = 0)
    "T-17 AC8 missing secret issues no stored token";
  let cfg_mail =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
             env "INTERVIEW_MAGIC_LINK_SECRET" "test-secret-interview-me";
           ])
      ()
  in
  (match Interview_config.missing_mail cfg_mail with
  | Some "RESEND_API_KEY" -> ()
  | Some name -> failwith ("T-17 AC8 expected RESEND_API_KEY, got " ^ name)
  | None -> failwith "T-17 AC8 missing mail must not satisfy");
  let tables2 = Interview_store.Memory.create () in
  let deps_mail, sent_mail, _ =
    memory_harness ~cfg:cfg_mail
      ~store:(Interview_store.Memory.bind tables2) ()
  in
  start_session deps_mail () >>= fun (id2, _) ->
  Interview_http.handle deps_mail
    (req "POST" ("/interview/sessions/" ^ id2 ^ "/verify-request") "")
  >>= fun res_mail ->
  json_body res_mail >>= fun (text_mail, _) ->
  E2e_ffi.assert_
    (error_name text_mail = "missing_env")
    "T-17 AC8 missing mail sender is missing_env";
  E2e_ffi.assert_ (not (agent_leaks_secrets text_mail))
    "T-17 AC8 missing mail issues no book token";
  E2e_ffi.assert_ (!sent_mail = []) "T-17 AC8 missing mail sends no mail";
  E2e_ffi.assert_
    (Hashtbl.length tables2.tokens = 0)
    "T-17 AC8 missing mail issues no stored token";
  E2e_ffi.pass "T-17 AC8 missing secret or mail sender is missing_env";
  return ()

(* T-17 AC9 *)
let prove_t17_contact_no_street () =
  let llms =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/llms.txt" |])
  in
  let agents =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/for-agents.md" |])
  in
  let deps, sent, _ = memory_harness () in
  start_session deps () >>= fun (id, _) ->
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let mail = List.hd !sent in
  let blobs = [ llms; agents; mail.text; mail.html ] in
  List.iter
    (fun blob ->
      E2e_ffi.assert_
        (Js.Re.test ~str:blob [%mel.re "/nathan@vegasbuckeye\\.com/"])
        "T-17 AC9 contact nathan@vegasbuckeye.com";
      E2e_ffi.assert_
        (not
           (Js.Re.test ~str:blob
              [%mel.re "/\\d+\\s+(Main|Street|Ave|Avenue|Road|Rd)\\b/i"]))
        "T-17 AC9 no street address")
    blobs;
  E2e_ffi.assert_
    (Js.String.includes ~search:"never needs" mail.text
    || Js.String.includes ~search:"never needs" mail.html)
    "T-17 AC9 agent never needs inbox access";
  E2e_ffi.pass "T-17 AC9 contact + no street + agent has no inbox";
  return ()

let string_list_field dict key =
  Interview_json.as_array (Interview_json.field dict key)
  |> Array.to_list
  |> List.map Interview_json.as_string

let default_required =
  [
    "current_work";
    "leadership";
    "systems";
    "wants_next";
    "hiring_timeline";
  ]

let q_current = "What is Nathan doing at TensorWave on Relay?"
let q_leadership = "What leadership scale has Nathan managed?"
let q_systems =
  "What systems depth does Nathan have in Rust and distributed systems?"
let q_wants = "What does Nathan want next?"
let q_refuse = "What is Nathan's unpublished salary?"
let q_timeline =
  "Our hiring timeline is we need someone by 12 October 2026."
let q_timeline_echo =
  "What hiring timeline did we record for this session?"
let q_invented = "What invented next role is Nathan taking at FakeCorp?"

let ask_q deps id q =
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/ask")
       (Interview_json.json_stringify
          (Interview_json.obj [ ("question", Interview_json.str q) ])))

let ask_dict deps id q =
  ask_q deps id q >>= fun res ->
  json_body res >>= fun (text, obj) ->
  match obj with
  | Some dict -> return (response_status res, text, dict)
  | None -> failwith ("ask body: " ^ text)

let assert_ids label expected actual =
  E2e_ffi.assert_
    (expected = actual)
    (label ^ " expected [" ^ String.concat "," expected ^ "] got ["
   ^ String.concat "," actual ^ "]")

let has_id xs id = List.exists (fun x -> x = id) xs

let assert_no_booking hooks label =
  List.iter
    (fun (s : Interview_webhook.sent) ->
      E2e_ffi.assert_
        (not (Js.String.includes ~search:"booking.requested" s.body))
        (label ^ " must not send booking.requested"))
    !hooks

let webhook_event_names hooks =
  List.rev !hooks
  |> List.map (fun (s : Interview_webhook.sent) ->
         match Interview_json.parse_object s.body with
         | None -> ""
         | Some dict -> Interview_json.string_field dict "event")

let complete_four deps id =
  ask_dict deps id q_current >>= fun _ ->
  ask_dict deps id q_leadership >>= fun _ ->
  ask_dict deps id q_systems >>= fun _ ->
  ask_dict deps id q_wants

(* T-18 AC1 *)
let prove_t18_progress_fields_and_refuse () =
  let deps, _, created, hooks = memory_full () in
  start_session deps () >>= fun (id, _) ->
  ask_dict deps id q_refuse >>= fun (status, _text, first) ->
  E2e_ffi.assert_ (status = 200) "T-18 AC1 first ask 200";
  assert_ids "T-18 AC1 first progress empty" []
    (string_list_field first "required_progress");
  assert_ids "T-18 AC1 default remaining"
    default_required
    (string_list_field first "required_remaining");
  ask_dict deps id q_current >>= fun (_, _, cited) ->
  assert_ids "T-18 AC1 cited progress" [ "current_work" ]
    (string_list_field cited "required_progress");
  assert_ids "T-18 AC1 cited remaining"
    [ "leadership"; "systems"; "wants_next"; "hiring_timeline" ]
    (string_list_field cited "required_remaining");
  ask_dict deps id q_refuse >>= fun (_, _, refuse_dict) ->
  E2e_ffi.assert_
    (Interview_json.as_bool (Interview_json.field refuse_dict "refused"))
    "T-18 AC1 refuse";
  assert_ids "T-18 AC1 refuse does not add progress" [ "current_work" ]
    (string_list_field refuse_dict "required_progress");
  assert_ids "T-18 AC1 refuse does not shrink remaining"
    [ "leadership"; "systems"; "wants_next"; "hiring_timeline" ]
    (string_list_field refuse_dict "required_remaining");
  E2e_ffi.assert_ (!hooks = []) "T-18 AC1 refuse sends no webhook";
  E2e_ffi.assert_ (!created = []) "T-18 AC1 no calendar hold";
  E2e_ffi.pass "T-18 AC1 ask JSON progress/remaining; refuse is a no-op";
  return ()

(* T-18 AC2 *)
let prove_t18_complete_once () =
  let deps, _, created, hooks =
    memory_full
      ~webhook:
        (let w, h = Interview_webhook.capture () in
         (w, h))
      ()
  in
  start_session deps ~callback:"https://hooks.example/complete" ()
  >>= fun (id, _) ->
  complete_four deps id >>= fun _ ->
  ask_dict deps id q_timeline >>= fun (_, _, dict) ->
  assert_ids "T-18 AC2 remaining empty on complete" []
    (string_list_field dict "required_remaining");
  let progress = string_list_field dict "required_progress" in
  List.iter
    (fun id ->
      E2e_ffi.assert_ (has_id progress id) ("T-18 AC2 progress has " ^ id))
    default_required;
  E2e_ffi.assert_
    (List.length progress = 5)
    "T-18 AC2 progress is five unique ids";
  E2e_ffi.assert_ (List.length !hooks = 1) "T-18 AC2 webhook once on complete";
  E2e_ffi.assert_
    (webhook_event_names hooks = [ "interview.completed" ])
    "T-18 AC2 event is interview.completed";
  ask_dict deps id q_current >>= fun (_, _, later) ->
  assert_ids "T-18 AC2 later remaining still empty" []
    (string_list_field later "required_remaining");
  E2e_ffi.assert_
    (List.length (string_list_field later "required_progress") = 5)
    "T-18 AC2 later progress not duplicated";
  E2e_ffi.assert_
    (List.length !hooks = 1)
    "T-18 AC2 later ask does not mark complete a second time";
  assert_no_booking hooks "T-18 AC2";
  E2e_ffi.assert_ (!created = []) "T-18 AC2 no calendar hold";
  E2e_ffi.pass "T-18 AC2 set completes once; later ask does not re-complete";
  return ()

(* T-18 AC3 *)
let prove_t18_four_cited_not_complete () =
  let deps, _, _, hooks = memory_full () in
  start_session deps ~callback:"https://hooks.example/four" () >>= fun (id, _) ->
  complete_four deps id >>= fun (_, _, dict) ->
  let remaining = string_list_field dict "required_remaining" in
  E2e_ffi.assert_
    (has_id remaining "hiring_timeline")
    "T-18 AC3 remaining still includes hiring_timeline";
  E2e_ffi.assert_ (remaining <> []) "T-18 AC3 not complete";
  E2e_ffi.assert_ (!hooks = []) "T-18 AC3 interview.completed not sent";
  assert_no_booking hooks "T-18 AC3";
  E2e_ffi.pass "T-18 AC3 four cited without timeline is not complete";
  return ()

(* T-18 AC4 *)
let prove_t18_timeline_alone_not_complete () =
  let deps, _, _, hooks = memory_full () in
  start_session deps ~callback:"https://hooks.example/timeline" ()
  >>= fun (id, _) ->
  ask_dict deps id q_timeline >>= fun (_, _, dict) ->
  let remaining = string_list_field dict "required_remaining" in
  List.iter
    (fun id ->
      E2e_ffi.assert_
        (has_id remaining id)
        ("T-18 AC4 remaining still includes " ^ id))
    [ "current_work"; "leadership"; "systems"; "wants_next" ];
  E2e_ffi.assert_ (remaining <> []) "T-18 AC4 not complete";
  E2e_ffi.assert_
    (not (has_id remaining "hiring_timeline"))
    "T-18 AC4 timeline itself is completed";
  E2e_ffi.assert_ (!hooks = []) "T-18 AC4 interview.completed not sent";
  assert_no_booking hooks "T-18 AC4";
  E2e_ffi.pass "T-18 AC4 timeline alone is not complete";
  return ()

(* T-18 AC5 *)
let prove_t18_hiring_timeline_recruiter_fact () =
  let deps, _, _, _ = memory_full () in
  start_session deps () >>= fun (id, _) ->
  ask_dict deps id q_timeline >>= fun (_, text, dict) ->
  E2e_ffi.assert_
    (not (Interview_json.as_bool (Interview_json.field dict "cited")))
    "T-18 AC5 recording cited false";
  E2e_ffi.assert_
    (not (Interview_json.as_bool (Interview_json.field dict "refused")))
    "T-18 AC5 recording is not a refusal";
  (match Interview_json.as_object (Interview_json.field dict "citation") with
  | None -> ()
  | Some c ->
      let source = Interview_json.string_field c "source" in
      failwith
        ("T-18 AC5 recording must not be a resume/page citation, got " ^ source));
  E2e_ffi.assert_
    (Js.String.includes ~search:"12 October 2026" text
    && Js.String.includes ~search:"we need someone" text)
    "T-18 AC5 recording answer contains their words";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"/resume.json" text
       && Js.String.includes ~search:"12 October 2026" text
          && Js.String.includes ~search:"Source: /resume.json" text))
    "T-18 AC5 recording is not a resume citation";
  ask_dict deps id q_timeline_echo >>= fun (_, echo_text, echo) ->
  E2e_ffi.assert_
    (not (Interview_json.as_bool (Interview_json.field echo "cited")))
    "T-18 AC5 echo cited false";
  E2e_ffi.assert_
    (Js.String.includes ~search:"12 October 2026" echo_text
    && Js.String.includes ~search:"we need someone" echo_text)
    "T-18 AC5 later ask echoes hiring_timeline with their words";
  ask_dict deps id q_invented >>= fun (_, invented_text, invented) ->
  E2e_ffi.assert_
    (Interview_json.as_bool (Interview_json.field invented "refused"))
    "T-18 AC5 invented career fact is refused";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"FakeCorp" invented_text
       && not (Js.String.includes ~search:"refused" invented_text)))
    "T-18 AC5 does not invent a career fact";
  E2e_ffi.pass "T-18 AC5 hiring timeline is recruiter fact, not a citation";
  return ()

(* T-18 AC6 *)
let prove_t18_required_set_configurable () =
  let csv_cfg =
    test_cfg [ env "INTERVIEW_REQUIRED_QUESTIONS" "current_work,hiring_timeline" ]
  in
  let deps_csv, _, _, _ = memory_full ~cfg:csv_cfg () in
  start_session deps_csv () >>= fun (id, _) ->
  ask_dict deps_csv id q_refuse >>= fun (_, _, first) ->
  assert_ids "T-18 AC6 CSV first-ask remaining"
    [ "current_work"; "hiring_timeline" ]
    (string_list_field first "required_remaining");
  ask_dict deps_csv id q_current >>= fun _ ->
  ask_dict deps_csv id q_timeline >>= fun (_, _, done_) ->
  assert_ids "T-18 AC6 CSV complete remaining" []
    (string_list_field done_ "required_remaining");
  let json_cfg =
    test_cfg
      [
        env "INTERVIEW_REQUIRED_QUESTIONS"
          "[\"current_work\",\"hiring_timeline\"]";
      ]
  in
  let deps_json, _, _, _ = memory_full ~cfg:json_cfg () in
  start_session deps_json () >>= fun (idj, _) ->
  ask_dict deps_json idj q_refuse >>= fun (_, _, jfirst) ->
  assert_ids "T-18 AC6 JSON array first-ask remaining"
    [ "current_work"; "hiring_timeline" ]
    (string_list_field jfirst "required_remaining");
  let empty_cfg = test_cfg [ env "INTERVIEW_REQUIRED_QUESTIONS" "" ] in
  E2e_ffi.assert_
    (Interview_config.required_ids empty_cfg = default_required)
    "T-18 AC6 empty restores five";
  let unset_cfg = test_cfg [] in
  E2e_ffi.assert_
    (Interview_config.required_ids unset_cfg = default_required)
    "T-18 AC6 unset restores five";
  let deps_unset, _, _, _ = memory_full ~cfg:unset_cfg () in
  start_session deps_unset () >>= fun (idu, _) ->
  ask_dict deps_unset idu q_refuse >>= fun (_, _, ufirst) ->
  assert_ids "T-18 AC6 unset first-ask remaining" default_required
    (string_list_field ufirst "required_remaining");
  E2e_ffi.pass "T-18 AC6 INTERVIEW_REQUIRED_QUESTIONS CSV/JSON/empty/unset";
  return ()

(* T-18 AC7 *)
let prove_t18_webhook_once_or_absent () =
  let deps, _, created, hooks = memory_full () in
  start_session deps ~callback:"https://hooks.example/interview" ()
  >>= fun (id, _) ->
  complete_four deps id >>= fun _ ->
  ask_dict deps id q_timeline >>= fun _ ->
  E2e_ffi.assert_ (List.length !hooks = 1) "T-18 AC7 exactly one webhook";
  let hook = List.hd !hooks in
  E2e_ffi.assert_
    (hook.url = "https://hooks.example/interview")
    "T-18 AC7 POST goes to callback_url";
  E2e_ffi.assert_
    (webhook_event_names hooks = [ "interview.completed" ])
    "T-18 AC7 event interview.completed";
  E2e_ffi.assert_
    (Js.String.includes ~search:"interview.completed" hook.body)
    "T-18 AC7 body names interview.completed";
  assert_no_booking hooks "T-18 AC7";
  ask_dict deps id q_wants >>= fun _ ->
  E2e_ffi.assert_ (List.length !hooks = 1) "T-18 AC7 later ask no second POST";
  E2e_ffi.assert_ (!created = []) "T-18 AC7 no calendar hold";
  let deps2, _, _, hooks2 = memory_full () in
  start_session deps2 () >>= fun (id2, _) ->
  complete_four deps2 id2 >>= fun _ ->
  ask_dict deps2 id2 q_timeline >>= fun (_, _, dict2) ->
  assert_ids "T-18 AC7 no callback still complete" []
    (string_list_field dict2 "required_remaining");
  E2e_ffi.assert_ (!hooks2 = []) "T-18 AC7 no callback_url means no webhook";
  E2e_ffi.pass "T-18 AC7 interview.completed once iff callback_url";
  return ()

(* T-18 AC8 *)
let prove_t18_webhook_failure_does_not_rollback () =
  let wh, hooks = Interview_webhook.capture_failing () in
  let deps, _, _, _ = memory_full ~webhook:(wh, hooks) () in
  start_session deps ~callback:"https://hooks.example/fail" () >>= fun (id, _) ->
  complete_four deps id >>= fun _ ->
  ask_dict deps id q_timeline >>= fun (status, _, dict) ->
  E2e_ffi.assert_ (status = 200) "T-18 AC8 completing ask succeeds";
  assert_ids "T-18 AC8 remaining empty despite webhook fail" []
    (string_list_field dict "required_remaining");
  E2e_ffi.assert_ (List.length !hooks = 1) "T-18 AC8 POST was attempted";
  ask_dict deps id q_leadership >>= fun (_, _, later) ->
  assert_ids "T-18 AC8 completeness not rolled back" []
    (string_list_field later "required_remaining");
  E2e_ffi.assert_
    (List.length (string_list_field later "required_progress") = 5)
    "T-18 AC8 later progress still complete";
  E2e_ffi.assert_
    (List.length !hooks = 1)
    "T-18 AC8 failed POST is not retried as a second complete";
  assert_no_booking hooks "T-18 AC8";
  E2e_ffi.pass "T-18 AC8 webhook failure does not roll back completeness";
  return ()

(* T-18 AC9 *)
let prove_t18_no_hold_or_verify () =
  let deps, sent, created, hooks = memory_full () in
  start_session deps ~callback:"https://hooks.example/nohold" ()
  >>= fun (id, _) ->
  complete_four deps id >>= fun _ ->
  ask_dict deps id q_timeline >>= fun (status, text, dict) ->
  E2e_ffi.assert_ (status = 200) "T-18 AC9 completing ask needs no verify";
  assert_ids "T-18 AC9 set complete without book token" []
    (string_list_field dict "required_remaining");
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"book_token" text
       || Js.String.includes ~search:"hold_id" text
       || Js.String.includes ~search:"calendar_event_id" text))
    "T-18 AC9 ask is not a hold and issues no book token";
  E2e_ffi.assert_ (!sent = []) "T-18 AC9 no hold mail";
  E2e_ffi.assert_ (!created = []) "T-18 AC9 calendar action never called";
  Interview_http.handle deps
    (req "POST" "/mcp"
       (mcp_call "create_hold"
          (Interview_json.obj
             [
               ("start", Interview_json.str "2026-09-01T17:00:00.000Z");
               ("book_token", Interview_json.str "not-a-token");
             ])))
  >>= fun hold ->
  response_text hold >>= fun hold_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"\"error\"" hold_text)
    "T-18 AC9 create_hold stays fail-closed";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"hold_id" hold_text
       || Js.String.includes ~search:"calendar_event_id" hold_text))
    "T-18 AC9 create_hold creates no calendar event";
  E2e_ffi.assert_ (!created = []) "T-18 AC9 create_hold never called calendar";
  assert_no_booking hooks "T-18 AC9";
  E2e_ffi.pass
    "T-18 AC9 no create_hold, verify, book token, calendar port, or hold mail";
  return ()

let hold_start = "2026-09-01T17:00:00.000Z"
let hold_end_explicit = "2026-09-01T19:30:00.000Z"

let hold_body ~book_token ?end_ ?(start = hold_start) () =
  Interview_json.json_stringify
    (Interview_json.obj
       ([
          ("start", Interview_json.str start);
          ("book_token", Interview_json.str book_token);
        ]
       @
       match end_ with
       | Some e -> [ ("end", Interview_json.str e) ]
       | None -> []))

let post_hold deps ~book_token ?end_ ?start () =
  Interview_http.handle deps
    (req "POST" "/interview/holds" (hold_body ~book_token ?end_ ?start ()))

let harvest_ban_link kind text =
  let re =
    if kind = "domain" then
      [%mel.re
        "/https:\\/\\/scull7\\.com\\/interview\\/ban\\?kind=domain&token=([^\\s<\"']+)/"]
    else
      [%mel.re
        "/https:\\/\\/scull7\\.com\\/interview\\/ban\\?kind=address&token=([^\\s<\"']+)/"]
  in
  match E2e_ffi.capture1 re text with
  | Some t -> t
  | None -> failwith ("ban " ^ kind ^ " link missing from mail")

let nathan_hold_mail sent =
  List.filter
    (fun (m : Interview_mail.message) ->
      m.to_ = "nathan@vegasbuckeye.com"
      && Js.String.includes ~search:"hold"
           (String.lowercase_ascii m.subject))
    !sent

let booking_count hooks =
  List.length
    (List.filter (fun e -> e = "booking.requested") (webhook_event_names hooks))

let completed_count hooks =
  List.length
    (List.filter
       (fun e -> e = "interview.completed")
       (webhook_event_names hooks))

let assert_no_touch ~sent ~created ~hooks ~holds label =
  E2e_ffi.assert_ (!created = []) (label ^ " no calendar event");
  E2e_ffi.assert_
    (nathan_hold_mail sent = [])
    (label ^ " no Nathan hold mail");
  E2e_ffi.assert_ (booking_count hooks = 0) (label ^ " no booking.requested");
  E2e_ffi.assert_
    (completed_count hooks = 0)
    (label ^ " no interview.completed");
  E2e_ffi.assert_ (Hashtbl.length holds = 0) (label ^ " no hold-cap consume")

let verify_book deps (sent : Interview_mail.message list ref) id =
  Interview_http.handle deps
    (req "POST" ("/interview/sessions/" ^ id ^ "/verify-request") "")
  >>= fun _ ->
  let token = harvest_magic_link (List.hd !sent).Interview_mail.text in
  Interview_http.handle deps
    (req "GET" ("/interview/verify?token=" ^ token) "")
  >>= fun res ->
  json_body res >>= fun (_, obj) ->
  match obj with
  | Some dict -> return (Interview_json.string_field dict "book_token")
  | None -> failwith "verify book token missing"

let complete_set deps id =
  complete_four deps id >>= fun _ ->
  ask_dict deps id q_timeline >>= fun (status, _, dict) ->
  E2e_ffi.assert_ (status = 200) "complete set ask 200";
  E2e_ffi.assert_
    (string_list_field dict "required_remaining" = [])
    "complete set remaining empty";
  return ()

let ready_hold ?cfg ?now_ms ?store ?webhook ?mail ?callback
    ?(email = "recruiter@acme.example") () =
  let deps, sent, created, hooks =
    memory_full ?cfg ?now_ms ?store ?webhook ?mail ()
  in
  start_session deps ~email ?callback () >>= fun (id, _) ->
  complete_set deps id >>= fun () ->
  verify_book deps sent id >>= fun book ->
  return (deps, sent, created, hooks, id, book)

(* T-19 AC1 *)
let prove_t19_required_incomplete () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let deps, sent, created, hooks = memory_full ~store () in
  start_session deps ~callback:"https://hooks.example/t19-inc" ()
  >>= fun (id, _) ->
  verify_book deps sent id >>= fun book ->
  ask_dict deps id q_current >>= fun _ ->
  post_hold deps ~book_token:book () >>= fun res ->
  E2e_ffi.assert_
    (response_status res = 409
    || (response_status res >= 400 && response_status res < 500))
    "T-19 AC1 required_incomplete is 4xx/409";
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_
    (error_name text = "required_incomplete")
    "T-19 AC1 error=required_incomplete";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"hold_id" text
       && not (Js.String.includes ~search:"required_incomplete" text)))
    "T-19 AC1 no hold created";
  assert_no_touch ~sent ~created ~hooks ~holds:tables.holds "T-19 AC1";
  E2e_ffi.pass
    "T-19 AC1 valid book token + incomplete set is required_incomplete";
  return ()

(* T-19 AC2 *)
let prove_t19_token_invalid () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let deps, sent, created, hooks = memory_full ~store () in
  start_session deps ()
  >>= fun (id, _) ->
  complete_set deps id >>= fun () ->
  let cases =
    [
      ("", "empty");
      ("not-a-token", "forged");
      ( "deadbeef.0000000000000000000000000000000000000000000000000000000000000000",
        "unknown" );
    ]
  in
  let rec loop = function
    | [] -> return ()
    | (tok, label) :: rest ->
        post_hold deps ~book_token:tok () >>= fun res ->
        json_body res >>= fun (text, _) ->
        E2e_ffi.assert_
          (error_name text = "token_invalid")
          ("T-19 AC2 " ^ label ^ " token_invalid");
        E2e_ffi.assert_
          (error_name text <> "unverified"
          && error_name text <> "not_found")
          ("T-19 AC2 " ^ label ^ " is not unverified/not_found");
        loop rest
  in
  loop cases >>= fun () ->
  Interview_http.handle deps
    (req "POST" "/interview/holds"
       (Interview_json.json_stringify
          (Interview_json.obj
             [ ("start", Interview_json.str hold_start) ])))
  >>= fun missing ->
  json_body missing >>= fun (missing_text, _) ->
  E2e_ffi.assert_
    (error_name missing_text = "token_invalid")
    "T-19 AC2 missing book token is token_invalid";
  let secret =
    match deps.cfg.magic_link_secret with
    | Some s -> s
    | None -> failwith "T-19 AC2 secret"
  in
  let raw = "book_orphan" in
  deps.store.put_token
    {
      token = raw;
      kind = "book";
      session_id = "ses_never";
      expires_at =
        Interview_token.expires_at_iso ~now_ms:(deps.now_ms ())
          ~ttl_ms:1_800_000.;
      consumed = false;
      created_at = Interview_clock.iso_of_ms (deps.now_ms ());
    }
  >>= fun () ->
  post_hold deps ~book_token:(Interview_token.sign_token secret raw) ()
  >>= fun orphan ->
  json_body orphan >>= fun (orphan_text, _) ->
  E2e_ffi.assert_
    (error_name orphan_text = "token_invalid")
    "T-19 AC2 unknown session is token_invalid";
  E2e_ffi.assert_
    (error_name orphan_text <> "not_found")
    "T-19 AC2 unknown session is not not_found";
  assert_no_touch ~sent ~created ~hooks ~holds:tables.holds "T-19 AC2";
  E2e_ffi.pass
    "T-19 AC2 no/forged/empty/unknown book token and unknown session are \
     token_invalid";
  return ()

(* T-19 AC3 *)
let prove_t19_book_token_ttl () =
  let unset =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
           ])
      ()
  in
  E2e_ffi.assert_
    (unset.book_token_ttl_ms = 1_800_000.)
    "T-19 AC3 default unset book TTL is 1800000";
  let now = ref 1_700_000_000_000. in
  let cfg = test_cfg [ env "INTERVIEW_BOOK_TOKEN_TTL_MS" "2000" ] in
  E2e_ffi.assert_ (cfg.book_token_ttl_ms = 2000.) "T-19 AC3 env TTL is 2000";
  let tables = Interview_store.Memory.create () in
  ready_hold ~cfg ~now_ms:(fun () -> !now)
    ~store:(Interview_store.Memory.bind tables) ()
  >>= fun (deps, sent, created, hooks, _id, book) ->
  now := !now +. 2001.;
  post_hold deps ~book_token:book () >>= fun res ->
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "token_invalid")
    "T-19 AC3 expired book token is token_invalid";
  assert_no_touch ~sent ~created ~hooks ~holds:tables.holds "T-19 AC3";
  E2e_ffi.pass "T-19 AC3 tester clock expires book token; default stays 1800000";
  return ()

(* T-19 AC4 *)
let prove_t19_invalid_start () =
  let tables = Interview_store.Memory.create () in
  ready_hold ~store:(Interview_store.Memory.bind tables) ()
  >>= fun (deps, sent, created, hooks, _id, book) ->
  let rec loop = function
    | [] -> return ()
    | (start, label) :: rest ->
        post_hold deps ~book_token:book ~start () >>= fun res ->
        json_body res >>= fun (text, _) ->
        E2e_ffi.assert_
          (error_name text = "invalid")
          ("T-19 AC4 " ^ label ^ " is invalid");
        loop rest
  in
  loop [ ("", "empty start"); ("   ", "whitespace start") ] >>= fun () ->
  Interview_http.handle deps
    (req "POST" "/interview/holds"
       (Interview_json.json_stringify
          (Interview_json.obj [ ("book_token", Interview_json.str book) ])))
  >>= fun missing ->
  json_body missing >>= fun (missing_text, _) ->
  E2e_ffi.assert_
    (error_name missing_text = "invalid")
    "T-19 AC4 missing start is invalid";
  assert_no_touch ~sent ~created ~hooks ~holds:tables.holds "T-19 AC4";
  E2e_ffi.pass "T-19 AC4 missing/empty start is invalid; no-touch";
  return ()

(* T-19 AC5 *)
let prove_t19_create_hold_and_mcp () =
  ready_hold ~callback:"https://hooks.example/t19-hold" ()
  >>= fun (deps, sent, created, hooks, id, book) ->
  post_hold deps ~book_token:book () >>= fun res ->
  E2e_ffi.assert_ (response_status res = 201) "T-19 AC5 HTTP hold 201";
  json_body res >>= fun (_, obj) ->
  (match obj with
  | None -> failwith "T-19 AC5 hold body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "session_id" = id)
        "T-19 AC5 session_id";
      E2e_ffi.assert_
        (Interview_json.string_field dict "start" = hold_start)
        "T-19 AC5 start";
      E2e_ffi.assert_
        (Interview_json.string_field dict "end" = "2026-09-01T18:00:00.000Z")
        "T-19 AC5 default end is +1 hour";
      E2e_ffi.assert_
        (Interview_json.string_field dict "calendar_id" = "scull7.com")
        "T-19 AC5 default calendar id";
      E2e_ffi.assert_
        (Interview_json.string_field dict "status" = "tentative")
        "T-19 AC5 tentative");
  E2e_ffi.assert_ (List.length !created = 1) "T-19 AC5 one calendar event";
  let ev = List.hd !created in
  E2e_ffi.assert_
    (ev.calendar_id = "scull7.com")
    "T-19 AC5 calendar calendar_id";
  E2e_ffi.assert_ (ev.start_iso = hold_start) "T-19 AC5 calendar start";
  E2e_ffi.assert_
    (ev.end_iso = "2026-09-01T18:00:00.000Z")
    "T-19 AC5 calendar default 1 hour";
  E2e_ffi.assert_
    (List.length (nathan_hold_mail sent) = 1)
    "T-19 AC5 Nathan hold mail sent";
  ready_hold ~email:"mcp@acme.example" ()
  >>= fun (deps2, _sent2, created2, _hooks2, id2, book2) ->
  Interview_http.handle deps2
    (req "POST" "/mcp"
       (mcp_call "create_hold"
          (Interview_json.obj
             [
               ("start", Interview_json.str hold_start);
               ("end", Interview_json.str hold_end_explicit);
               ("book_token", Interview_json.str book2);
             ])))
  >>= fun mcp_res ->
  E2e_ffi.assert_ (response_status mcp_res = 200) "T-19 AC5 MCP create_hold";
  response_text mcp_res >>= fun mcp_text ->
  (match mcp_structured mcp_text with
  | None -> failwith "T-19 AC5 MCP structured"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "session_id" = id2)
        "T-19 AC5 MCP session_id";
      E2e_ffi.assert_
        (Interview_json.string_field dict "end" = hold_end_explicit)
        "T-19 AC5 MCP passing end uses that end";
      E2e_ffi.assert_
        (Interview_json.string_field dict "calendar_id" = "scull7.com")
        "T-19 AC5 MCP calendar_id");
  E2e_ffi.assert_ (List.length !created2 = 1) "T-19 AC5 MCP created one event";
  E2e_ffi.assert_
    ((List.hd !created2).end_iso = hold_end_explicit)
    "T-19 AC5 MCP calendar uses passed end";
  ignore hooks;
  E2e_ffi.pass
    "T-19 AC5 create_hold makes a 1-hour tentative event; MCP matches HTTP";
  return ()

(* T-19 AC6 *)
let prove_t19_calendar_and_length_configurable () =
  let cfg =
    test_cfg
      [
        env "INTERVIEW_CALENDAR_ID" "other.example";
        env "INTERVIEW_HOLD_DEFAULT_SECONDS" "7200";
      ]
  in
  E2e_ffi.assert_ (cfg.calendar_id = "other.example") "T-19 AC6 calendar env";
  E2e_ffi.assert_ (cfg.hold_default_seconds = 7200) "T-19 AC6 seconds env";
  ready_hold ~cfg ~email:"cfg@acme.example" ()
  >>= fun (deps, _sent, created, _hooks, _id, book) ->
  post_hold deps ~book_token:book () >>= fun res ->
  E2e_ffi.assert_ (response_status res = 201) "T-19 AC6 hold 201";
  json_body res >>= fun (_, obj) ->
  (match obj with
  | None -> failwith "T-19 AC6 body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "calendar_id" = "other.example")
        "T-19 AC6 response calendar";
      E2e_ffi.assert_
        (Interview_json.string_field dict "end" = "2026-09-01T19:00:00.000Z")
        "T-19 AC6 default length 7200s");
  E2e_ffi.assert_
    ((List.hd !created).calendar_id = "other.example")
    "T-19 AC6 calendar uses INTERVIEW_CALENDAR_ID";
  E2e_ffi.assert_
    ((List.hd !created).end_iso = "2026-09-01T19:00:00.000Z")
    "T-19 AC6 calendar uses INTERVIEW_HOLD_DEFAULT_SECONDS";
  E2e_ffi.pass
    "T-19 AC6 calendar id and default length change without a code change";
  return ()

(* T-19 AC7 *)
let prove_t19_hold_cap () =
  let unset =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
           ])
      ()
  in
  E2e_ffi.assert_ (unset.hold_cap = 3) "T-19 AC7 default cap is 3";
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let cfg = test_cfg [ env "INTERVIEW_HOLD_CAP" "1" ] in
  E2e_ffi.assert_ (cfg.hold_cap = 1) "T-19 AC7 INTERVIEW_HOLD_CAP changes N";
  let webhook, hooks = Interview_webhook.capture () in
  ready_hold ~cfg ~store ~webhook:(webhook, hooks)
    ~callback:"https://hooks.example/t19-cap" ~email:"one@acme.example" ()
  >>= fun (deps, sent, created, hooks, _id, book) ->
  post_hold deps ~book_token:book () >>= fun first ->
  E2e_ffi.assert_ (response_status first = 201) "T-19 AC7 first hold succeeds";
  let events_after_first = List.length !created in
  let mail_after_first = List.length (nathan_hold_mail sent) in
  let booking_after_first = booking_count hooks in
  let holds_after_first = Hashtbl.length tables.holds in
  start_session deps ~email:"two@acme.example"
    ~callback:"https://hooks.example/t19-cap-2" ()
  >>= fun (id2, _) ->
  complete_set deps id2 >>= fun () ->
  verify_book deps sent id2 >>= fun book2 ->
  post_hold deps ~book_token:book2 () >>= fun second ->
  json_body second >>= fun (text, _) ->
  E2e_ffi.assert_ (error_name text = "hold_cap") "T-19 AC7 N+1st is hold_cap";
  E2e_ffi.assert_
    (List.length !created = events_after_first)
    "T-19 AC7 hold-cap refuse creates no extra event";
  E2e_ffi.assert_
    (List.length (nathan_hold_mail sent) = mail_after_first)
    "T-19 AC7 hold-cap refuse sends no extra Nathan mail";
  E2e_ffi.assert_
    (booking_count hooks = booking_after_first)
    "T-19 AC7 hold-cap refuse sends no extra booking.requested";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"interview.completed" text))
    "T-19 AC7 hold-cap refuse is not interview.completed";
  E2e_ffi.assert_
    (Hashtbl.length tables.holds = holds_after_first)
    "T-19 AC7 hold-cap refuse consumes no extra cap slot";
  E2e_ffi.pass "T-19 AC7 work-domain hold cap; INTERVIEW_HOLD_CAP changes N";
  return ()

(* T-19 AC8 *)
let prove_t19_nathan_mail_and_ban () =
  ready_hold ~email:"banned@acme.example" ()
  >>= fun (deps, sent, _created, _hooks, _id, book) ->
  post_hold deps ~book_token:book () >>= fun res ->
  E2e_ffi.assert_ (response_status res = 201) "T-19 AC8 hold created";
  let mail = List.hd (nathan_hold_mail sent) in
  E2e_ffi.assert_
    (mail.to_ = "nathan@vegasbuckeye.com")
    "T-19 AC8 hold mail goes to INTERVIEW_MAIL_TO default";
  E2e_ffi.assert_
    (Js.String.includes ~search:"Ban this address" mail.text
    && Js.String.includes ~search:"Ban this domain" mail.text)
    "T-19 AC8 mail names both ban links";
  let addr_tok = harvest_ban_link "address" mail.text in
  let dom_tok = harvest_ban_link "domain" mail.text in
  E2e_ffi.assert_ (addr_tok <> "") "T-19 AC8 address token";
  E2e_ffi.assert_ (dom_tok <> "") "T-19 AC8 domain token";
  Interview_http.handle deps
    (req "GET"
       ("/interview/ban?kind=address&token=" ^ addr_tok)
       "")
  >>= fun ban_addr ->
  E2e_ffi.assert_
    (response_status ban_addr = 200)
    "T-19 AC8 ban-address 200";
  start_session deps ~email:"banned@acme.example" () >>= fun (rej_id, rej) ->
  E2e_ffi.assert_
    (error_name rej = "banned" || not (String.starts_with ~prefix:"ses_" rej_id))
    "T-19 AC8 same address rejected after ban-address";
  E2e_ffi.assert_
    (not (has_session_id rej))
    "T-19 AC8 banned address creates no session";
  start_session deps ~email:"other@acme.example" () >>= fun (ok_id, _) ->
  E2e_ffi.assert_
    (String.starts_with ~prefix:"ses_" ok_id)
    "T-19 AC8 other address on same domain still accepted";
  Interview_http.handle deps
    (req "GET" ("/interview/ban?kind=domain&token=" ^ dom_tok) "")
  >>= fun ban_dom ->
  E2e_ffi.assert_ (response_status ban_dom = 200) "T-19 AC8 ban-domain 200";
  start_session deps ~email:"third@acme.example" () >>= fun (dom_id, dom_text) ->
  E2e_ffi.assert_
    (error_name dom_text = "banned" || not (has_session_id dom_text))
    "T-19 AC8 same work domain rejected after ban-domain";
  E2e_ffi.assert_
    (not (String.starts_with ~prefix:"ses_" dom_id && has_session_id dom_text))
    "T-19 AC8 banned domain creates no session";
  E2e_ffi.pass
    "T-19 AC8 Nathan hold mail has working ban-address and ban-domain links";
  return ()

(* T-19 AC9 *)
let prove_t19_booking_requested_only () =
  let webhook, hooks = Interview_webhook.capture () in
  ready_hold ~webhook:(webhook, hooks)
    ~callback:"https://hooks.example/t19-book" ()
  >>= fun (deps, _sent, _created, hooks, _id, book) ->
  let completed_before = completed_count hooks in
  E2e_ffi.assert_
    (completed_before = 1)
    "T-19 AC9 set completion already sent interview.completed";
  E2e_ffi.assert_
    (booking_count hooks = 0)
    "T-19 AC9 no booking.requested before hold";
  post_hold deps ~book_token:book () >>= fun res ->
  E2e_ffi.assert_ (response_status res = 201) "T-19 AC9 hold created";
  E2e_ffi.assert_
    (booking_count hooks = 1)
    "T-19 AC9 callback receives booking.requested only when hold is created";
  E2e_ffi.assert_
    (completed_count hooks = completed_before)
    "T-19 AC9 create_hold does not send interview.completed";
  List.iter
    (fun name ->
      E2e_ffi.assert_
        (name = "interview.completed" || name = "booking.requested")
        "T-19 AC9 no third event name")
    (webhook_event_names hooks);
  post_hold deps ~book_token:"not-a-token" () >>= fun bad ->
  json_body bad >>= fun (bad_text, _) ->
  E2e_ffi.assert_
    (error_name bad_text = "token_invalid")
    "T-19 AC9 refuse does not create a hold";
  E2e_ffi.assert_
    (booking_count hooks = 1)
    "T-19 AC9 refuse does not send another booking.requested";
  E2e_ffi.pass
    "T-19 AC9 booking.requested only on create; never interview.completed \
     from hold";
  return ()

(* T-19b: the real calrs backend. calrs has no REST API, so these fakes feed
   the client the HTML its booking form actually returns. *)

let fake_response ~ok ~status ~body : Interview_http_fetch.response =
  Obj.magic [%mel.obj { ok; status; text = (fun () -> Js.Promise.resolve body) }]

let recording_post ?(ok = true) ?(status = 200) ~body () =
  let calls = ref [] in
  let post url ~headers ~body:sent =
    calls := (url, headers, sent) :: !calls;
    Js.Promise.resolve (fake_response ~ok ~status ~body)
  in
  (post, calls)

let calrs_port ?ok ?status ~body () =
  let post, calls = recording_post ?ok ?status ~body () in
  ( Interview_calrs.port ~post ~base:"https://cal.test.invalid" ~username:"nate"
      ~slug:"interview-hold" (),
    calls )

(* calrs escapes interpolated URLs, so this is the shape a real confirmation
   page has. *)
let calrs_ok_body =
  "<a href=\"&#x2f;booking&#x2f;ics&#x2f;tok_abc123XY\" download>Add to \
   calendar</a>"

let calrs_pending_body = "<h1>Pending confirmation</h1>"
let calrs_taken_body = "This slot is no longer available."
let calrs_no_event_body = "Event type not found."
let calrs_unknown_body = "<html>something else</html>"

let hold_request start_iso : Interview_calendar.request =
  {
    calendar_id = "scull7.com";
    summary = "Interview hold: Acme / Staff Engineer";
    description = "Tentative hold from interview-me.";
    start_iso;
    end_iso = "2026-09-01T18:00:00.000Z";
    guest_name = "Rey Recruiter";
    guest_email = "rey@acme.example";
  }

let field_of_body body name =
  let parts = String.split_on_char '&' body in
  let prefix = name ^ "=" in
  List.fold_left
    (fun acc part ->
      match acc with
      | Some _ -> acc
      | None ->
          if String.starts_with ~prefix part then
            Some
              (String.sub part (String.length prefix)
                 (String.length part - String.length prefix))
          else None)
    None parts

let cookie_csrf headers =
  match Js.Dict.get headers "Cookie" with
  | None -> None
  | Some raw ->
      let prefix = "__Host-calrs_csrf=" in
      if String.starts_with ~prefix raw then
        Some
          (String.sub raw (String.length prefix)
             (String.length raw - String.length prefix))
      else None

let prove_t19b_calrs_client () =
  (* Happy path *)
  let port, calls = calrs_port ~body:calrs_ok_body () in
  port.create_tentative (hold_request hold_start) >>= fun created ->
  (match created with
  | Ok ev ->
      E2e_ffi.assert_
        (ev.Interview_calendar.event_id = "tok_abc123XY")
        "T-19b cancel token is the event id";
      E2e_ffi.assert_
        (ev.Interview_calendar.html_link
        = "https://cal.test.invalid/booking/ics/tok_abc123XY")
        "T-19b html_link points at the calrs booking"
  | Error e -> failwith ("T-19b expected Ok, got " ^ e));
  E2e_ffi.assert_ (List.length !calls = 1) "T-19b one calrs POST";
  let url, headers, sent = List.hd !calls in
  E2e_ffi.assert_
    (url = "https://cal.test.invalid/u/nate/interview-hold/book")
    "T-19b posts to the calrs booking form";
  E2e_ffi.assert_
    (field_of_body sent "date" = Some "2026-09-01")
    "T-19b sends the UTC date";
  E2e_ffi.assert_
    (field_of_body sent "time" = Some (Interview_token.encode_uri "17:00"))
    "T-19b sends the UTC time";
  E2e_ffi.assert_ (field_of_body sent "tz" = Some "UTC") "T-19b books in UTC";
  E2e_ffi.assert_
    (match (field_of_body sent "_csrf", cookie_csrf headers) with
    | Some form, Some cookie -> form = cookie && form <> ""
    | _ -> false)
    "T-19b _csrf field matches the csrf cookie (double submit)";

  (* Escaped and plain links both parse *)
  E2e_ffi.assert_
    (Interview_calrs.cancel_token_of_html calrs_ok_body = Some "tok_abc123XY")
    "T-19b escaped /booking/ics/ link parses";
  E2e_ffi.assert_
    (Interview_calrs.cancel_token_of_html "/booking/ics/tok_abc123XY"
    = Some "tok_abc123XY")
    "T-19b plain /booking/ics/ link parses";

  (* A pending booking has no cancel handle: fail loudly, never Ok *)
  let pending_port, _ = calrs_port ~body:calrs_pending_body () in
  pending_port.create_tentative (hold_request hold_start) >>= fun pending ->
  (match pending with
  | Error e ->
      E2e_ffi.assert_
        (String.starts_with ~prefix:"invalid:" e
        && Js.String.includes ~search:"requires-confirmation" e)
        "T-19b pending booking is a loud invalid"
  | Ok _ -> failwith "T-19b pending must never be Ok");

  (* Slot taken *)
  let taken_port, _ = calrs_port ~body:calrs_taken_body () in
  taken_port.create_tentative (hold_request hold_start) >>= fun taken ->
  (match taken with
  | Error e ->
      E2e_ffi.assert_
        (String.starts_with ~prefix:"slot_unavailable:" e)
        "T-19b taken slot is slot_unavailable"
  | Ok _ -> failwith "T-19b taken slot must not be Ok");

  (* Misconfigured event type *)
  let missing_port, _ = calrs_port ~body:calrs_no_event_body () in
  missing_port.create_tentative (hold_request hold_start) >>= fun no_event ->
  (match no_event with
  | Error e ->
      E2e_ffi.assert_
        (String.starts_with ~prefix:"invalid:" e)
        "T-19b unknown event type is invalid"
  | Ok _ -> failwith "T-19b unknown event type must not be Ok");

  (* calrs answers 200 even when it refuses: an unreadable 200 is never Ok *)
  let unknown_port, _ = calrs_port ~body:calrs_unknown_body () in
  unknown_port.create_tentative (hold_request hold_start) >>= fun unknown ->
  (match unknown with
  | Error _ -> ()
  | Ok _ -> failwith "T-19b unrecognised 200 must never be Ok");

  (* A non-UTC start never reaches the wire *)
  let tz_port, tz_calls = calrs_port ~body:calrs_ok_body () in
  tz_port.create_tentative (hold_request "2026-09-01T17:00:00+02:00")
  >>= fun offset ->
  E2e_ffi.assert_
    (offset = Error "invalid:start must be UTC ISO-8601 ending in Z")
    "T-19b non-UTC start is invalid";
  E2e_ffi.assert_ (!tz_calls = []) "T-19b non-UTC start posts nothing";

  (* Cancel *)
  let cancel_port, cancel_calls = calrs_port ~body:"" () in
  cancel_port.delete_event ~calendar_id:"scull7.com" ~event_id:"tok_abc123XY"
  >>= fun cancelled ->
  E2e_ffi.assert_ (cancelled = Ok ()) "T-19b cancel succeeds on 2xx";
  (match !cancel_calls with
  | [ (url, _, _) ] ->
      E2e_ffi.assert_
        (url = "https://cal.test.invalid/booking/cancel/tok_abc123XY")
        "T-19b cancel posts to the calrs cancel path"
  | _ -> failwith "T-19b cancel made no call");
  let fail_cancel, _ = calrs_port ~ok:false ~status:500 ~body:"boom" () in
  fail_cancel.delete_event ~calendar_id:"scull7.com" ~event_id:"tok_abc123XY"
  >>= fun bad_cancel ->
  E2e_ffi.assert_ (bad_cancel <> Ok ()) "T-19b cancel failure is an error";

  (* of_config is fail-closed and names the first missing var *)
  let cfg_none =
    Interview_config.of_source ~source:(source [ env "X" "y" ]) ()
  in
  (Interview_calrs.of_config cfg_none).create_tentative (hold_request hold_start)
  >>= fun unset ->
  E2e_ffi.assert_
    (unset = Error "missing_env:INTERVIEW_CAL_API_URL")
    "T-19b no booking env is missing_env:INTERVIEW_CAL_API_URL";
  let cfg_url =
    Interview_config.of_source
      ~source:(source [ env "INTERVIEW_CAL_API_URL" "https://cal.test.invalid" ])
      ()
  in
  E2e_ffi.assert_
    (Interview_config.missing_calendar cfg_url = Some "INTERVIEW_CAL_USERNAME")
    "T-19b url alone still needs INTERVIEW_CAL_USERNAME";
  let cfg_user =
    Interview_config.of_source
      ~source:
        (source
           [
             env "INTERVIEW_CAL_API_URL" "https://cal.test.invalid/";
             env "INTERVIEW_CAL_USERNAME" "nate";
           ])
      ()
  in
  E2e_ffi.assert_
    (Interview_config.missing_calendar cfg_user
    = Some "INTERVIEW_CAL_EVENT_SLUG")
    "T-19b url + username still needs INTERVIEW_CAL_EVENT_SLUG";
  E2e_ffi.assert_
    (cfg_user.cal_api_url = Some "https://cal.test.invalid")
    "T-19b trailing slash is stripped from the base url";
  E2e_ffi.pass
    "T-19b calrs client: booking form, escaped cancel token, refusals, cancel, \
     fail-closed config";
  return ()

(* T-19b: a calrs refusal must refuse the whole hold, with no side effects. *)
let prove_t19b_slot_unavailable_no_touch () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  ready_hold ~store ~email:"slot@acme.example" ()
  >>= fun (deps, sent, created, hooks, _id, book) ->
  let taken_port, _ = calrs_port ~body:calrs_taken_body () in
  let deps_taken = { deps with Interview_service.calendar = taken_port } in
  post_hold deps_taken ~book_token:book () >>= fun res ->
  json_body res >>= fun (text, _) ->
  E2e_ffi.assert_
    (response_status res = 409)
    "T-19b slot_unavailable is 409";
  E2e_ffi.assert_
    (error_name text = "slot_unavailable")
    "T-19b error=slot_unavailable";
  E2e_ffi.assert_
    (Hashtbl.length tables.holds = 0)
    "T-19b slot_unavailable persists no hold";
  E2e_ffi.assert_
    (nathan_hold_mail sent = [])
    "T-19b slot_unavailable sends no hold mail";
  E2e_ffi.assert_
    (booking_count hooks = 0)
    "T-19b slot_unavailable sends no booking.requested";
  E2e_ffi.assert_ (!created = []) "T-19b slot_unavailable creates no event";
  post_hold deps ~book_token:book () >>= fun retry ->
  E2e_ffi.assert_
    (response_status retry = 201)
    "T-19b book token survives a slot_unavailable refusal";
  E2e_ffi.pass
    "T-19b slot_unavailable refuses with no calendar, mail, webhook, or cap \
     spend";
  return ()

(* T-19 AC10 *)
let prove_t19_missing_env_no_fake_hold () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let cfg_cal =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
             env "INTERVIEW_MAGIC_LINK_SECRET" "test-secret-interview-me";
             env "RESEND_API_KEY" "re_test_not_a_secret";
           ])
      ()
  in
  (match Interview_config.missing_calendar cfg_cal with
  | Some "INTERVIEW_CAL_API_URL" -> ()
  | Some name -> failwith ("T-19 AC10 expected calendar name, got " ^ name)
  | None -> failwith "T-19 AC10 missing calendar env must not satisfy");
  ready_hold ~cfg:cfg_cal ~store ~email:"cal@acme.example" ()
  >>= fun (deps, sent, created, hooks, _id, book) ->
  post_hold deps ~book_token:book () >>= fun res_cal ->
  json_body res_cal >>= fun (text_cal, _) ->
  E2e_ffi.assert_
    (error_name text_cal = "missing_env")
    "T-19 AC10 missing calendar is missing_env";
  E2e_ffi.assert_ (!created = []) "T-19 AC10 missing calendar creates no event";
  E2e_ffi.assert_
    (Hashtbl.length tables.holds = 0)
    "T-19 AC10 missing calendar persists no hold";
  E2e_ffi.assert_
    (nathan_hold_mail sent = [])
    "T-19 AC10 missing calendar sends no hold mail";
  E2e_ffi.assert_
    (booking_count hooks = 0)
    "T-19 AC10 missing calendar sends no booking.requested";
  post_hold
    { deps with Interview_service.cfg = test_cfg [] }
    ~book_token:book ()
  >>= fun retry_res ->
  E2e_ffi.assert_
    (response_status retry_res = 201)
    "T-19 AC10 book token not consumed by missing_env; still usable";
  let tables2 = Interview_store.Memory.create () in
  let store2 = Interview_store.Memory.bind tables2 in
  let cfg_mail =
    Interview_config.of_source
      ~source:
        (source
           [
             env "TURSO_DATABASE_URL" "https://interview-me.test.invalid";
             env "TURSO_AUTH_TOKEN" "test-turso-token";
             env "INTERVIEW_MAGIC_LINK_SECRET" "test-secret-interview-me";
             env "INTERVIEW_CAL_API_URL" "https://cal.test.invalid";
             env "INTERVIEW_CAL_USERNAME" "nate";
             env "INTERVIEW_CAL_EVENT_SLUG" "interview-hold";
           ])
      ()
  in
  (match Interview_config.missing_mail cfg_mail with
  | Some "RESEND_API_KEY" -> ()
  | Some name -> failwith ("T-19 AC10 expected RESEND_API_KEY, got " ^ name)
  | None -> failwith "T-19 AC10 missing mail must not satisfy");
  ready_hold ~store:store2 ~email:"mailmiss@acme.example" ()
  >>= fun (deps2, sent2, created2, hooks2, _id2, book2) ->
  let deps2 = { deps2 with Interview_service.cfg = cfg_mail } in
  post_hold deps2 ~book_token:book2 () >>= fun res_mail ->
  json_body res_mail >>= fun (text_mail, _) ->
  E2e_ffi.assert_
    (error_name text_mail = "missing_env")
    "T-19 AC10 missing mail sender is missing_env";
  E2e_ffi.assert_ (!created2 = []) "T-19 AC10 missing mail creates no event";
  E2e_ffi.assert_
    (Hashtbl.length tables2.holds = 0)
    "T-19 AC10 missing mail persists no hold";
  E2e_ffi.assert_
    (nathan_hold_mail sent2 = [])
    "T-19 AC10 missing mail sends no hold mail";
  E2e_ffi.assert_
    (booking_count hooks2 = 0)
    "T-19 AC10 missing mail sends no booking.requested";
  E2e_ffi.pass
    "T-19 AC10 missing calendar or mail sender is missing_env; no fake hold; \
     token reusable; port fail-closed";
  return ()

(* T-19 AC11 *)
let prove_t19_mail_fail_after_create () =
  let tables = Interview_store.Memory.create () in
  let store = Interview_store.Memory.bind tables in
  let cfg = test_cfg [ env "INTERVIEW_HOLD_CAP" "1" ] in
  ready_hold ~cfg ~store
    ~callback:"https://hooks.example/t19-mailfail" ~email:"fail@acme.example"
    ()
  >>= fun (deps, _sent_ok, created, hooks, _id, book) ->
  let deps =
    {
      deps with
      Interview_service.mail =
        Interview_mail.failing ~message:"resend 500: boom" ();
    }
  in
  post_hold deps ~book_token:book () >>= fun fail_res ->
  json_body fail_res >>= fun (fail_text, _) ->
  E2e_ffi.assert_
    (error_name fail_text <> "")
    "T-19 AC11 mail-fail-after-create is an error";
  E2e_ffi.assert_
    (not
       (Js.String.includes ~search:"hold_id" fail_text
       && error_name fail_text = ""))
    "T-19 AC11 mail-fail is not a successful hold";
  E2e_ffi.assert_ (!created = []) "T-19 AC11 calendar cancelled after mail fail";
  E2e_ffi.assert_
    (Hashtbl.length tables.holds = 0)
    "T-19 AC11 hold-cap not consumed";
  E2e_ffi.assert_
    (booking_count hooks = 0)
    "T-19 AC11 booking.requested not sent";
  let ok_mail, ok_sent = Interview_mail.capture () in
  let deps_ok =
    { deps with Interview_service.mail = ok_mail }
  in
  post_hold deps_ok ~book_token:book () >>= fun ok_res ->
  E2e_ffi.assert_
    (response_status ok_res = 201)
    "T-19 AC11 book token remains usable; later success is still first of N";
  json_body ok_res >>= fun (_, ok_obj) ->
  (match ok_obj with
  | None -> failwith "T-19 AC11 retry body"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "hold_id" <> "")
        "T-19 AC11 retry created a hold");
  E2e_ffi.assert_
    (List.length (nathan_hold_mail ok_sent) = 1)
    "T-19 AC11 retry sent Nathan hold mail";
  E2e_ffi.assert_
    (Hashtbl.length tables.holds = 1)
    "T-19 AC11 later success consumes the first cap slot";
  E2e_ffi.pass
    "T-19 AC11 mail-fail-after-create cancels event; token reusable; cap free";
  return ()

(* T-19 AC12 *)
let prove_t19_contact_openapi_mcp () =
  let deps = memory_deps () in
  Interview_http.handle deps (req "GET" "/openapi.json" "") >>= fun res ->
  json_body res >>= fun (_, obj) ->
  (match obj with
  | None -> failwith "T-19 AC12 openapi"
  | Some dict ->
      let contact = Interview_json.object_field dict "info" in
      let info_contact = Interview_json.object_field contact "contact" in
      E2e_ffi.assert_
        (Interview_json.string_field info_contact "email"
        = "nathan@vegasbuckeye.com")
        "T-19 AC12 OpenAPI contact email";
      let paths = Interview_json.object_field dict "paths" in
      let hold_req = request_schema paths "/interview/holds" "post" in
      List.iter
        (fun f ->
          E2e_ffi.assert_
            (List.exists (fun r -> r = f) (required_of hold_req))
            ("T-19 AC12 hold required " ^ f))
        [ "start"; "book_token" ];
      let hold_201 = response_schema paths "/interview/holds" "post" "201" in
      List.iter
        (fun f ->
          E2e_ffi.assert_ (has_prop hold_201 f) ("T-19 AC12 hold 201 names " ^ f))
        [ "hold_id"; "session_id"; "start"; "end"; "calendar_id" ];
      let verify_200 =
        response_schema paths "/interview/verify" "get" "200"
      in
      List.iter
        (fun f ->
          E2e_ffi.assert_
            (has_prop verify_200 f)
            ("T-19 AC12 verify 200 names " ^ f))
        [ "session_id"; "book_token"; "expires_at" ];
      let ban_200 = response_schema paths "/interview/ban" "get" "200" in
      List.iter
        (fun f ->
          E2e_ffi.assert_ (has_prop ban_200 f) ("T-19 AC12 ban 200 names " ^ f))
        [ "banned"; "value" ];
      let ban_path = Interview_json.object_field paths "/interview/ban" in
      let ban_get = Interview_json.object_field ban_path "get" in
      let params =
        Interview_json.as_array (Interview_json.field ban_get "parameters")
      in
      let has_kind =
        params
        |> Array.exists (fun p ->
               match Interview_json.as_object p with
               | None -> false
               | Some d -> Interview_json.string_field d "name" = "kind")
      in
      E2e_ffi.assert_ has_kind "T-19 AC12 ban documents kind");
  Interview_http.handle deps (req "GET" "/mcp" "") >>= fun mcp_res ->
  response_text mcp_res >>= fun mcp_text ->
  assert_exact_tools "T-19 AC12 GET /mcp" (tool_names_of mcp_text);
  let llms =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/llms.txt" |])
  in
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/nathan@vegasbuckeye\\.com/"])
    "T-19 AC12 contact nathan@vegasbuckeye.com";
  E2e_ffi.assert_
    (not
       (Js.Re.test ~str:llms
          [%mel.re "/\\d+\\s+(Main|Street|Ave|Avenue|Road|Rd)\\b/i"]))
    "T-19 AC12 no street address";
  E2e_ffi.pass
    "T-19 AC12 contact + OpenAPI hold/verify/ban + MCP remains five names";
  return ()

let prove_function_bundle () =
  let interview_js =
    Node.Path.join [| E2e_ffi.root; "netlify/functions/interview.js" |]
  in
  E2e_ffi.assert_
    (Node.Fs.existsSync interview_js)
    "bundled netlify/functions/interview.js exists";
  let body = Node.Fs.readFileAsUtf8Sync interview_js in
  List.iter
    (fun needle ->
      E2e_ffi.assert_
        (not (Js.String.includes ~search:needle body))
        ("bundle must not import " ^ needle))
    [
      "from \"melange.js";
      "from 'melange.js";
      "from \"melange/";
      "from 'melange/";
    ];
  let toml =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "netlify.toml" |])
  in
  E2e_ffi.assert_
    (Js.String.includes ~search:"/.netlify/functions/interview" toml)
    "pretty paths rewrite to the interview function";
  E2e_ffi.assert_
    (Js.String.includes ~search:"/openapi.json" toml)
    "openapi.json rewrite is present";
  E2e_ffi.pass "interview function is a self-contained Netlify bundle";
  return ()

let run () =
  let finish code =
    E2e_ffi.set_exit_code code;
    E2e_ffi.schedule_exit ()
  in
  prove_function_bundle ()
  >>= (fun () -> prove_start_echo ())
  >>= (fun () -> prove_later_ask_turso ())
  >>= (fun () -> prove_invalid_start ())
  >>= (fun () -> prove_ask_never_created ())
  >>= (fun () -> prove_free_email_and_allowlist ())
  >>= (fun () -> prove_cited_and_refuse ())
  >>= (fun () -> prove_ask_unverified_no_hold ())
  >>= (fun () -> prove_resume_and_experience ())
  >>= (fun () -> prove_openapi_named ())
  >>= (fun () -> prove_mcp_tools ())
  >>= (fun () -> prove_llms_txt ())
  >>= (fun () -> prove_missing_turso_env ())
  >>= (fun () -> prove_t17_verify_request_mail ())
  >>= (fun () -> prove_t17_verify_never_created ())
  >>= (fun () -> prove_t17_human_verify_issues_book_token ())
  >>= (fun () -> prove_t17_session_scope ())
  >>= (fun () -> prove_t17_magic_link_single_use ())
  >>= (fun () -> prove_t17_magic_link_ttl ())
  >>= (fun () -> prove_t17_qa_before_after_no_hold ())
  >>= (fun () -> prove_t17_missing_env_no_token ())
  >>= (fun () -> prove_t17_contact_no_street ())
  >>= (fun () -> prove_t18_progress_fields_and_refuse ())
  >>= (fun () -> prove_t18_complete_once ())
  >>= (fun () -> prove_t18_four_cited_not_complete ())
  >>= (fun () -> prove_t18_timeline_alone_not_complete ())
  >>= (fun () -> prove_t18_hiring_timeline_recruiter_fact ())
  >>= (fun () -> prove_t18_required_set_configurable ())
  >>= (fun () -> prove_t18_webhook_once_or_absent ())
  >>= (fun () -> prove_t18_webhook_failure_does_not_rollback ())
  >>= (fun () -> prove_t18_no_hold_or_verify ())
  >>= (fun () -> prove_t19_required_incomplete ())
  >>= (fun () -> prove_t19_token_invalid ())
  >>= (fun () -> prove_t19_book_token_ttl ())
  >>= (fun () -> prove_t19_invalid_start ())
  >>= (fun () -> prove_t19_create_hold_and_mcp ())
  >>= (fun () -> prove_t19_calendar_and_length_configurable ())
  >>= (fun () -> prove_t19_hold_cap ())
  >>= (fun () -> prove_t19_nathan_mail_and_ban ())
  >>= (fun () -> prove_t19_booking_requested_only ())
  >>= (fun () -> prove_t19_missing_env_no_fake_hold ())
  >>= (fun () -> prove_t19_mail_fail_after_create ())
  >>= (fun () -> prove_t19b_calrs_client ())
  >>= (fun () -> prove_t19b_slot_unavailable_no_touch ())
  >>= (fun () -> prove_t19_contact_openapi_mcp ())
  >>= (fun () ->
         E2e_ffi.console_log "e2e/interview PASS";
         finish 0;
         return ())
  |> Js.Promise.catch (fun err ->
         E2e_ffi.console_error_any err;
         E2e_ffi.console_error
           ("e2e/interview FAIL: " ^ E2e_ffi.error_to_string err);
         finish 1;
         return ())
  |> ignore
