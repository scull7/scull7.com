(* Interview-me v1 proofs: sessions, cited Q&A, verify, hold gates, OpenAPI, MCP. *)

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

external response_status : Interview_http.response -> int = "status" [@@mel.get]
external response_text : Interview_http.response -> string Js.Promise.t = "text"
[@@mel.send]

let env name value =
  (name, value)

let source pairs name =
  try Some (List.assoc name pairs) with Not_found -> None

let test_cfg extras =
  Interview_config.of_source
    ~source:
      (source
         (extras
         @ [
             env "INTERVIEW_STORE" "memory";
             env "INTERVIEW_MAGIC_LINK_SECRET" "test-secret-interview-me";
             env "INTERVIEW_SITE_URL" "https://scull7.com";
             env "INTERVIEW_CALENDAR_ID" "scull7.com";
             env "INTERVIEW_HOLD_CAP" "3";
             env "INTERVIEW_MAIL_FROM" "nathan@vegasbuckeye.com";
             env "INTERVIEW_MAIL_TO" "nathan@vegasbuckeye.com";
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
    [
      ("/about.md", about);
      ( "/test-next.md",
        "Nathan wants next to keep leading GPU-cloud platform teams and \
         shipping distributed systems in Rust." );
    ]

let make_deps ?cfg () =
  let cfg =
    match cfg with Some c -> c | None -> test_cfg []
  in
  let mail, sent_mail = Interview_mail.capture () in
  let calendar, created = Interview_calendar.capture () in
  let webhook, sent_hooks = Interview_service.capturing_webhook () in
  ( {
      Interview_service.now_ms = Interview_crypto.now_ms;
      random_id = Interview_crypto.random_id;
      cfg;
      store = Interview_store.Memory.bind (Interview_store.Memory.create ());
      corpus = test_corpus ();
      mail;
      calendar;
      webhook;
    },
    sent_mail,
    created,
    sent_hooks )

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

let start_session deps email =
  Interview_service.start deps
    {
      company = "Acme";
      role = "Director of Engineering";
      recruiter_name = "Pat Recruiter";
      work_email = email;
      callback_url = Some "https://hooks.example/interview";
    }
  >>= fun r -> return (must_ok "start" r)

let complete_required deps session_id =
  let questions =
    [
      "What is Nathan doing at TensorWave on Relay?";
      "What leadership scale has Nathan managed?";
      "What systems depth does Nathan have in Rust and distributed systems?";
      "What does Nathan want next?";
      "Our hiring timeline is two weeks to first onsite.";
    ]
  in
  let rec loop = function
    | [] -> return ()
    | q :: rest ->
        Interview_service.ask deps ~session_id ~question:q >>= fun r ->
        ignore (must_ok ("ask " ^ q) r);
        loop rest
  in
  loop questions

let prove_session_and_ask () =
  let deps, _, _, _ = make_deps () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  E2e_ffi.assert_ (session.company = "Acme") "session company";
  Interview_service.ask deps ~session_id:session.id
    ~question:"What is Nathan doing at TensorWave on Relay?"
  >>= fun r ->
  let out = must_ok "cited ask" r in
  E2e_ffi.assert_ out.cited "TensorWave ask should be cited";
  E2e_ffi.assert_ (not out.refused) "TensorWave ask should not refuse";
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" out.answer
    || Js.String.includes ~search:"Relay" out.answer)
    "cited answer mentions TensorWave or Relay";
  (match out.citation with
  | None -> failwith "missing citation"
  | Some c ->
      E2e_ffi.assert_
        (c.source = "/resume.json" || c.source = "/about.md")
        ("citation source " ^ c.source));
  Interview_service.ask deps ~session_id:session.id
    ~question:"What is Nathan's unpublished salary and favorite color?"
  >>= fun r2 ->
  let refused = must_ok "refuse" r2 in
  E2e_ffi.assert_ refused.refused "unpublished fact must refuse";
  E2e_ffi.assert_ (not refused.cited) "refusal is not cited";
  E2e_ffi.assert_ (refused.completed_item = None) "refuse does not complete";
  E2e_ffi.pass "session start + cited ask + refuse";
  return ()

let prove_free_email () =
  let deps, _, _, _ = make_deps () in
  Interview_service.start deps
    {
      company = "Acme";
      role = "Eng";
      recruiter_name = "Pat";
      work_email = "pat@gmail.com";
      callback_url = None;
    }
  >>= function
  | Error (Interview_service.Free_email domain) ->
      E2e_ffi.assert_ (domain = "gmail.com") "gmail domain";
      E2e_ffi.pass "free-email reject";
      return ()
  | Error e ->
      failwith
        ("expected free_email, got "
        ^ Interview_json.json_stringify (Interview_service.error_json e))
  | Ok _ -> failwith "gmail should be rejected"

let prove_qa_without_verify_hold_refused () =
  let deps, _, _, _ = make_deps () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  Interview_service.ask deps ~session_id:session.id
    ~question:"What is Nathan doing at TensorWave on Relay?"
  >>= fun r ->
  let out = must_ok "qa" r in
  E2e_ffi.assert_ out.cited "Q&A works without verification";
  Interview_service.create_hold deps
    ~start:"2026-09-01T17:00:00.000Z" ~end_:None ~book_token:"not-a-token"
  >>= function
  | Error (Interview_service.Token_invalid _)
  | Error Interview_service.Unverified ->
      E2e_ffi.pass "hold refused without verification";
      return ()
  | Error e ->
      E2e_ffi.assert_
        (Interview_service.error_code e >= 400)
        "hold without verify is an error";
      E2e_ffi.pass "hold refused without verification";
      return ()
  | Ok _ -> failwith "hold must be impossible without verify"

let prove_verify_book_token () =
  let deps, sent, _, _ = make_deps () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  Interview_service.request_verification deps ~session_id:session.id
  >>= fun r ->
  ignore (must_ok "verify-request" r);
  E2e_ffi.assert_ (!sent <> []) "magic link email sent";
  let mail = List.hd !sent in
  E2e_ffi.assert_ (mail.to_ = "recruiter@acme.example") "mail to work email";
  let link =
    match
      E2e_ffi.capture1
        [%mel.re "/https:\\/\\/scull7\\.com\\/interview\\/verify\\?token=([^\\s<]+)/"]
        mail.text
    with
    | Some t -> t
    | None -> failwith "magic link missing from email"
  in
  Interview_service.verify deps ~signed:link >>= fun r2 ->
  let out = must_ok "verify" r2 in
  E2e_ffi.assert_ (out.session_id = session.id) "book token scoped to session";
  E2e_ffi.assert_ (String.contains out.book_token '.') "signed book token";
  E2e_ffi.pass "verify + book token";
  return (session, out.book_token)

let prove_hold_requires_questions () =
  let deps, sent, _, _ = make_deps () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  Interview_service.request_verification deps ~session_id:session.id
  >>= fun r ->
  ignore (must_ok "vr" r);
  let mail = List.hd !sent in
  let link =
    match
      E2e_ffi.capture1
        [%mel.re "/https:\\/\\/scull7\\.com\\/interview\\/verify\\?token=([^\\s<]+)/"]
        mail.text
    with
    | Some t -> t
    | None -> failwith "link"
  in
  Interview_service.verify deps ~signed:link >>= fun r2 ->
  let tok = must_ok "v" r2 in
  Interview_service.create_hold deps ~start:"2026-09-01T17:00:00.000Z"
    ~end_:None ~book_token:tok.book_token
  >>= function
  | Error (Interview_service.Required_incomplete missing) ->
      E2e_ffi.assert_ (missing <> []) "missing required items";
      E2e_ffi.pass "hold refused without required set";
      return ()
  | Error e ->
      failwith
        ("expected required_incomplete "
        ^ Interview_json.json_stringify (Interview_service.error_json e))
  | Ok _ -> failwith "hold must wait for required set"

let prove_hold_cap_and_success () =
  let cfg = test_cfg [ env "INTERVIEW_HOLD_CAP" "1" ] in
  let deps, sent, created, hooks = make_deps ~cfg () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  complete_required deps session.id >>= fun () ->
  Interview_service.request_verification deps ~session_id:session.id
  >>= fun r ->
  ignore (must_ok "vr" r);
  let link =
    match
      E2e_ffi.capture1
        [%mel.re "/https:\\/\\/scull7\\.com\\/interview\\/verify\\?token=([^\\s<]+)/"]
        (List.hd !sent).text
    with
    | Some t -> t
    | None -> failwith "link"
  in
  Interview_service.verify deps ~signed:link >>= fun r2 ->
  let tok = must_ok "v" r2 in
  Interview_service.create_hold deps ~start:"2026-09-01T17:00:00.000Z"
    ~end_:None ~book_token:tok.book_token
  >>= fun h1 ->
  let hold = must_ok "hold1" h1 in
  E2e_ffi.assert_ (hold.calendar_id = "scull7.com") "configurable calendar id";
  E2e_ffi.assert_ (!created <> []) "calendar connector called";
  let end_ms = Interview_crypto.ms_of_iso hold.end_ in
  let start_ms = Interview_crypto.ms_of_iso hold.start in
  E2e_ffi.assert_
    (abs_float (end_ms -. start_ms -. 3600000.) < 1000.)
    "default hold length 1 hour";
  let notice =
    List.find_opt
      (fun (m : Interview_mail.message) ->
        Js.String.includes ~search:"Ban this address" m.text
        && Js.String.includes ~search:"Ban this domain" m.text)
      !sent
  in
  E2e_ffi.assert_ (notice <> None) "hold notification has ban links";
  E2e_ffi.assert_
    (List.exists
       (fun (_, body) ->
         Js.String.includes ~search:"interview.completed" body)
       !hooks)
    "interview.completed webhook";
  E2e_ffi.assert_
    (List.exists
       (fun (_, body) ->
         Js.String.includes ~search:"booking.requested" body)
       !hooks)
    "booking.requested webhook";
  (* second hold same domain, cap 1 *)
  Interview_service.request_verification deps ~session_id:session.id
  >>= fun r3 ->
  ignore (must_ok "vr2" r3);
  let link2 =
    match
      E2e_ffi.capture1
        [%mel.re "/https:\\/\\/scull7\\.com\\/interview\\/verify\\?token=([^\\s<]+)/"]
        (List.hd !sent).text
    with
    | Some t -> t
    | None -> failwith "link2"
  in
  Interview_service.verify deps ~signed:link2 >>= fun r4 ->
  let tok2 = must_ok "v2" r4 in
  Interview_service.create_hold deps ~start:"2026-09-02T17:00:00.000Z"
    ~end_:None ~book_token:tok2.book_token
  >>= function
  | Error (Interview_service.Hold_cap n) ->
      E2e_ffi.assert_ (n = 1) "cap is configurable";
      E2e_ffi.pass "hold created when gates pass + refused over domain cap";
      return ()
  | Error e ->
      failwith
        ("expected hold_cap "
        ^ Interview_json.json_stringify (Interview_service.error_json e))
  | Ok _ -> failwith "second hold should hit domain cap"

let prove_openapi_mcp () =
  let deps, _, _, _ = make_deps () in
  Interview_http.handle deps (req "GET" "/openapi.json" "") >>= fun res ->
  E2e_ffi.assert_ (response_status res = 200) "GET /openapi.json";
  json_body res >>= fun (text, obj) ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"\"openapi\"" text)
    "OpenAPI has openapi field";
  (match obj with
  | None -> failwith "openapi not an object"
  | Some dict ->
      E2e_ffi.assert_
        (Interview_json.string_field dict "openapi" = "3.0.3")
        "openapi 3.0.3";
      let paths = Interview_json.object_field dict "paths" in
      E2e_ffi.assert_
        (Js.Dict.get paths "/interview/sessions" <> None)
        "path /interview/sessions";
      E2e_ffi.assert_
        (Js.Dict.get paths "/mcp" <> None)
        "path /mcp");
  let mcp_list =
    Interview_json.json_stringify
      (Interview_json.obj
         [
           ("jsonrpc", Interview_json.str "2.0");
           ("id", Interview_json.num 1.);
           ("method", Interview_json.str "tools/list");
         ])
  in
  Interview_http.handle deps (req "POST" "/mcp" mcp_list) >>= fun mcp_res ->
  E2e_ffi.assert_ (response_status mcp_res = 200) "POST /mcp tools/list";
  response_text mcp_res >>= fun mcp_text ->
  List.iter
    (fun tool ->
      E2e_ffi.assert_
        (Js.String.includes ~search:tool mcp_text)
        ("MCP missing " ^ tool))
    [
      "start_interview";
      "ask_nathan";
      "request_verification";
      "create_hold";
      "get_resume";
    ];
  E2e_ffi.assert_
    (not (Js.String.includes ~search:"practice" mcp_text))
    "no extra practice tool";
  let start =
    Interview_json.json_stringify
      (Interview_json.obj
         [
           ("jsonrpc", Interview_json.str "2.0");
           ("id", Interview_json.num 2.);
           ("method", Interview_json.str "tools/call");
           ( "params",
             Interview_json.obj
               [
                 ("name", Interview_json.str "start_interview");
                 ( "arguments",
                   Interview_json.json_parse (start_body ()) );
               ] );
         ])
  in
  Interview_http.handle deps (req "POST" "/mcp" start) >>= fun start_res ->
  E2e_ffi.assert_ (response_status start_res = 200) "MCP start_interview";
  response_text start_res >>= fun start_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"ses_" start_text
    || Js.String.includes ~search:"session" start_text)
    "MCP start returns session";
  Interview_http.handle deps (req "POST" "/interview/sessions" (start_body ()))
  >>= fun http_start ->
  E2e_ffi.assert_
    (response_status http_start = 201)
    ("POST /interview/sessions "
    ^ string_of_int (response_status http_start));
  Interview_http.handle deps
    (req "POST" "/interview/sessions" (start_body ~email:"pat@gmail.com" ()))
  >>= fun gmail_res ->
  E2e_ffi.assert_
    (response_status gmail_res = 400 || response_status gmail_res = 422)
    "POST /interview/sessions rejects gmail";
  json_body gmail_res >>= fun (gmail_text, _) ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"gmail" (String.lowercase_ascii gmail_text)
    || Js.String.includes ~search:"free" (String.lowercase_ascii gmail_text))
    "gmail rejection names the free-email problem";
  Interview_http.handle deps (req "GET" "/interview/resume" "")
  >>= fun resume_res ->
  E2e_ffi.assert_ (response_status resume_res = 200) "GET /interview/resume";
  response_text resume_res >>= fun resume_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"TensorWave" resume_text
    || Js.String.includes ~search:"basics" resume_text
    || Js.String.includes ~search:"work" resume_text)
    "resume surface has published facts";
  Interview_http.handle deps
    (req "GET" "/.netlify/functions/interview/openapi.json" "")
  >>= fun mounted_oa ->
  E2e_ffi.assert_
    (response_status mounted_oa = 200)
    "function-mount GET /openapi.json";
  Interview_http.handle deps
    (req "GET" "/.netlify/functions/interview/interview/resume" "")
  >>= fun mounted_resume ->
  E2e_ffi.assert_
    (response_status mounted_resume = 200)
    "function-mount GET /interview/resume";
  Interview_http.handle deps
    (req "POST" "/.netlify/functions/interview/interview/sessions"
       (start_body ~email:"second@acme.example" ()))
  >>= fun mounted_start ->
  E2e_ffi.assert_
    (response_status mounted_start = 201)
    "function-mount POST /interview/sessions";
  E2e_ffi.pass "OpenAPI and MCP surfaces exist";
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
  E2e_ffi.assert_ (Js.String.includes ~search:"export" body) "bundle exports";
  E2e_ffi.assert_ (Js.String.includes ~search:"config" body) "bundle has config";
  E2e_ffi.assert_
    (Js.String.includes ~search:"/.netlify/functions/interview" body)
    "config keeps the default function URL";
  let toml =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "netlify.toml" |])
  in
  E2e_ffi.assert_
    (Js.String.includes ~search:"[[redirects]]" toml)
    "netlify.toml has redirects";
  E2e_ffi.assert_
    (Js.String.includes ~search:"/.netlify/functions/interview" toml)
    "pretty paths rewrite to the interview function";
  E2e_ffi.assert_
    (Js.String.includes ~search:"/openapi.json" toml)
    "openapi.json rewrite is present";
  E2e_ffi.assert_
    (Js.String.includes ~search:"included_files" toml)
    "function bundle includes published corpus files";
  E2e_ffi.pass "interview function is a self-contained Netlify bundle";
  return ()

let prove_refuse_does_not_complete () =
  let deps, _, _, _ = make_deps () in
  start_session deps "recruiter@acme.example" >>= fun session ->
  Interview_service.ask deps ~session_id:session.id
    ~question:"What does Nathan want next if we invent a secret next role?"
  >>= fun r ->
  (* The invented part should still match wants_next pattern; completion
     requires a cited wants-next passage. The question matches wants_next.
     Our test corpus HAS a wants-next page, so this might complete.
     Ask something that matches wants_next pattern but we temporarily
     use a corpus without that page. *)
  ignore r;
  let corpus = Interview_corpus.of_resume_json (load_resume ()) in
  let deps =
    { deps with corpus }
  in
  start_session deps "lead@acme.example" >>= fun session2 ->
  Interview_service.ask deps ~session_id:session2.id
    ~question:"What does Nathan want next?"
  >>= fun r2 ->
  let out = must_ok "wants next unpublished" r2 in
  E2e_ffi.assert_ out.refused "unpublished wants-next refuses";
  E2e_ffi.assert_ (out.completed_item = None) "refusal does not complete item";
  E2e_ffi.assert_
    (List.exists (fun id -> id = "wants_next") out.required_remaining)
    "wants_next still remaining";
  E2e_ffi.pass "refusal does not complete required item";
  return ()

let run () =
  let finish code =
    E2e_ffi.set_exit_code code;
    E2e_ffi.schedule_exit ()
  in
  prove_function_bundle ()
  >>= (fun () -> prove_session_and_ask ())
  >>= (fun () -> prove_free_email ())
  >>= (fun () -> prove_qa_without_verify_hold_refused ())
  >>= (fun () -> prove_hold_requires_questions ())
  >>= (fun () -> prove_hold_cap_and_success ())
  >>= (fun () -> prove_openapi_mcp ())
  >>= (fun () -> prove_refuse_does_not_complete ())
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
