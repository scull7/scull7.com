(* OpenAPI 3 contract for T-16 through T-19 surfaces. Named request/response
   properties, not path-name stubs. Hold request requires start + book_token. *)

let string_prop = Interview_json.obj [ ("type", Interview_json.str "string") ]

let bool_prop = Interview_json.obj [ ("type", Interview_json.str "boolean") ]

let string_array_prop =
  Interview_json.obj
    [
      ("type", Interview_json.str "array");
      ("items", string_prop);
    ]

let object_schema ~required properties =
  Interview_json.obj
    [
      ("type", Interview_json.str "object");
      ( "required",
        Interview_json.arr (List.map Interview_json.str required) );
      ("properties", Interview_json.obj properties);
    ]

let json_content schema =
  Interview_json.obj
    [ ("application/json", Interview_json.obj [ ("schema", schema) ]) ]

let schema_error =
  object_schema ~required:[ "error" ]
    [
      ( "error",
        Interview_json.obj
          [
            ("type", Interview_json.str "string");
            ( "enum",
              Interview_json.arr
                [
                  Interview_json.str "invalid";
                  Interview_json.str "not_found";
                  Interview_json.str "free_email";
                  Interview_json.str "missing_env";
                  Interview_json.str "token_invalid";
                  Interview_json.str "required_incomplete";
                  Interview_json.str "hold_cap";
                  Interview_json.str "banned";
                ] );
          ] );
      ("message", string_prop);
      ("name", string_prop);
      ("domain", string_prop);
      ("missing", string_array_prop);
      ("cap", Interview_json.obj [ ("type", Interview_json.str "number") ]);
      ("value", string_prop);
    ]

let session_fields =
  [
    ("id", string_prop);
    ("company", string_prop);
    ("role", string_prop);
    ("recruiter_name", string_prop);
    ("work_email", string_prop);
    ("callback_url", string_prop);
    ("verified", bool_prop);
  ]

let start_request =
  object_schema
    ~required:[ "company"; "role"; "recruiter_name"; "work_email" ]
    [
      ("company", string_prop);
      ("role", string_prop);
      ("recruiter_name", string_prop);
      ("work_email", string_prop);
      ("callback_url", string_prop);
    ]

let start_201 =
  object_schema
    ~required:[ "id"; "company"; "role"; "recruiter_name"; "work_email" ]
    session_fields

let ask_request =
  object_schema ~required:[ "question" ] [ ("question", string_prop) ]

let ask_200 =
  object_schema
    ~required:
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
      ]
    ([
       ("answer", string_prop);
       ("cited", bool_prop);
       ("refused", bool_prop);
       ("required_progress", string_array_prop);
       ("required_remaining", string_array_prop);
       ("session_id", string_prop);
       ( "citation",
         object_schema ~required:[ "source"; "path"; "quote" ]
           [
             ("source", string_prop);
             ("path", string_prop);
             ("quote", string_prop);
           ] );
     ]
    @ session_fields)

let experience_item =
  object_schema ~required:[ "source"; "path"; "quote" ]
    [
      ("source", string_prop);
      ("path", string_prop);
      ("quote", string_prop);
    ]

let verify_request_202 =
  object_schema ~required:[ "session_id"; "sent" ]
    [ ("session_id", string_prop); ("sent", bool_prop) ]

let verify_200 =
  object_schema ~required:[ "session_id"; "book_token"; "expires_at" ]
    [
      ("session_id", string_prop);
      ("book_token", string_prop);
      ("expires_at", string_prop);
    ]

let hold_request =
  object_schema ~required:[ "start"; "book_token" ]
    [
      ("start", string_prop);
      ("book_token", string_prop);
      ("end", string_prop);
    ]

let hold_201 =
  object_schema
    ~required:
      [
        "hold_id";
        "session_id";
        "start";
        "end";
        "status";
        "calendar_id";
        "calendar_event_id";
      ]
    [
      ("hold_id", string_prop);
      ("session_id", string_prop);
      ("start", string_prop);
      ("end", string_prop);
      ("status", string_prop);
      ("calendar_id", string_prop);
      ("calendar_event_id", string_prop);
      ("html_link", string_prop);
    ]

let ban_200 =
  object_schema ~required:[ "banned"; "value" ]
    [ ("banned", string_prop); ("value", string_prop) ]

let experience_200 =
  object_schema ~required:[ "results" ]
    [
      ( "results",
        Interview_json.obj
          [
            ("type", Interview_json.str "array");
            ("items", experience_item);
          ] );
    ]

let resume_200 =
  object_schema ~required:[ "basics" ]
    [
      ( "basics",
        object_schema ~required:[]
          [
            ("name", string_prop);
            ("label", string_prop);
            ("email", string_prop);
            ("summary", string_prop);
          ] );
      ( "work",
        Interview_json.obj
          [ ("type", Interview_json.str "array"); ("items", string_prop) ] );
      ("$schema", string_prop);
    ]

let document ~site_url =
  Interview_json.obj
    [
      ("openapi", Interview_json.str "3.0.3");
      ( "info",
        Interview_json.obj
          [
            ("title", Interview_json.str "interview-me");
            ("version", Interview_json.str "1.0.0");
            ( "description",
              Interview_json.str
                "Recruiter-agent interview of Nathan Sculli: named Turso \
                 sessions, cited Q&A, human work-email magic-link verify, \
                 tentative calendar hold, resume and experience search. \
                 Discover via OpenAPI and MCP." );
            ( "contact",
              Interview_json.obj
                [
                  ("name", Interview_json.str "Nathan Sculli");
                  ("email", Interview_json.str "nathan@vegasbuckeye.com");
                  ("url", Interview_json.str site_url);
                ] );
          ] );
      ( "servers",
        Interview_json.arr
          [ Interview_json.obj [ ("url", Interview_json.str site_url) ] ] );
      ( "paths",
        Interview_json.obj
          [
            ( "/interview/sessions",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "startSession");
                        ( "summary",
                          Interview_json.str
                            "Start a named recruiter-agent session" );
                        ( "requestBody",
                          Interview_json.obj
                            [
                              ("required", Interview_json.bool true);
                              ("content", json_content start_request);
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "201",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "Session created" );
                                    ("content", json_content start_201);
                                  ] );
                              ( "400",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "invalid or free_email" );
                                    ("content", json_content schema_error);
                                  ] );
                              ( "503",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "missing_env" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/sessions/{id}/ask",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "askQuestion");
                        ( "summary",
                          Interview_json.str
                            "Ask a question; cited answer or refusal" );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "id");
                                  ("in", Interview_json.str "path");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                            ] );
                        ( "requestBody",
                          Interview_json.obj
                            [
                              ("required", Interview_json.bool true);
                              ("content", json_content ask_request);
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Cited answer or published-fact refusal"
                                    );
                                    ("content", json_content ask_200);
                                  ] );
                              ( "404",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "not_found" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/sessions/{id}/verify-request",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "requestVerification");
                        ( "summary",
                          Interview_json.str
                            "Send a magic-link email to the session work \
                             email. Does not return the magic URL or book \
                             token." );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "id");
                                  ("in", Interview_json.str "path");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "202",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Magic-link mail accepted" );
                                    ("content", json_content verify_request_202);
                                  ] );
                              ( "404",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "not_found" );
                                    ("content", json_content schema_error);
                                  ] );
                              ( "503",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "missing_env" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/verify",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "verifyMagicLink");
                        ( "summary",
                          Interview_json.str
                            "Human magic-link click. Issues a short-lived \
                             book token scoped to that session." );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "token");
                                  ("in", Interview_json.str "query");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Book token for the requesting session"
                                    );
                                    ("content", json_content verify_200);
                                  ] );
                              ( "401",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "token_invalid" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/holds",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "createHold");
                        ( "summary",
                          Interview_json.str
                            "Create a tentative calendar hold. \
                             Book-token only: start + book_token, optional \
                             end. No session path param." );
                        ( "requestBody",
                          Interview_json.obj
                            [
                              ("required", Interview_json.bool true);
                              ("content", json_content hold_request);
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "201",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Tentative hold created" );
                                    ("content", json_content hold_201);
                                  ] );
                              ( "400",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "invalid" );
                                    ("content", json_content schema_error);
                                  ] );
                              ( "401",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "token_invalid" );
                                    ("content", json_content schema_error);
                                  ] );
                              ( "409",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "required_incomplete or hold_cap" );
                                    ("content", json_content schema_error);
                                  ] );
                              ( "503",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "missing_env" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/ban",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "banWorkIdentity");
                        ( "summary",
                          Interview_json.str
                            "One-click ban of the session work address or \
                             domain from Nathan's hold-notification mail." );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "kind");
                                  ("in", Interview_json.str "query");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "token");
                                  ("in", Interview_json.str "query");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "Ban recorded" );
                                    ("content", json_content ban_200);
                                  ] );
                              ( "401",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "token_invalid" );
                                    ("content", json_content schema_error);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/resume",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "getResume");
                        ( "summary",
                          Interview_json.str
                            "Published resume facts from the same corpus" );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "JSON Resume" );
                                    ("content", json_content resume_200);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/interview/experience",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "searchExperience");
                        ( "summary",
                          Interview_json.str
                            "Search published experience facts" );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "q");
                                  ("in", Interview_json.str "query");
                                  ("required", Interview_json.bool true);
                                  ("schema", string_prop);
                                ];
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Cited experience hits" );
                                    ("content", json_content experience_200);
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/mcp",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "mcpToolsList");
                        ( "summary",
                          Interview_json.str
                            "MCP tools/list: start_interview, ask_nathan, \
                             request_verification, create_hold, get_resume" );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "MCP tools list" );
                                  ] );
                            ] );
                      ] );
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "mcp");
                        ( "summary",
                          Interview_json.str
                            "MCP JSON-RPC. start_interview, ask_nathan, and \
                             get_resume match HTTP. request_verification \
                             matches HTTP verify-request. create_hold matches \
                             HTTP POST /interview/holds." );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "JSON-RPC response" );
                                  ] );
                            ] );
                      ] );
                ] );
            ( "/openapi.json",
              Interview_json.obj
                [
                  ( "get",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "getOpenApi");
                        ( "summary",
                          Interview_json.str "This OpenAPI document" );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "200",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "OpenAPI 3.0.3" );
                                  ] );
                            ] );
                      ] );
                ] );
          ] );
    ]
