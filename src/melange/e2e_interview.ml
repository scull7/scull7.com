(* T-16 + T-17 proofs: named Turso session, cited Q&A, human magic-link
   verify / book token, resume/experience, OpenAPI + MCP + llms.txt.
   Each AC has an inversion. *)

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

let memory_harness ?cfg ?now_ms ?store () =
  let cfg = match cfg with Some c -> c | None -> test_cfg [] in
  let store =
    match store with
    | Some s -> s
    | None -> Interview_store.Memory.bind (Interview_store.Memory.create ())
  in
  let mail, sent = Interview_mail.capture () in
  let calendar, created = Interview_calendar.capture () in
  ( {
      Interview_service.now_ms =
        (match now_ms with Some f -> f | None -> Interview_clock.now_ms);
      random_id = Interview_clock.random_id;
      cfg;
      store;
      corpus = test_corpus ();
      mail;
      calendar;
    },
    sent,
    created )

let memory_deps ?cfg ?now_ms () =
  let deps, _, _ = memory_harness ?cfg ?now_ms () in
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
  ( {
      Interview_service.now_ms =
        (match now_ms with Some f -> f | None -> Interview_clock.now_ms);
      random_id = Interview_clock.random_id;
      cfg;
      store = Interview_store.turso ~url ~token ();
      corpus = test_corpus ();
      mail;
      calendar;
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

let start_session deps ?(email = "recruiter@acme.example") () =
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ~email ()))
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
