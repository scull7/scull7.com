(* Real OpenAPI 3 contract for interview-me. Not a stub. *)

let schema_error extra =
  Interview_json.obj
    ([
       ( "type",
         Interview_json.str "object" );
       ("required", Interview_json.arr [ Interview_json.str "error" ]);
       ( "properties",
         Interview_json.obj
           ([
              ( "error",
                Interview_json.obj
                  [ ("type", Interview_json.str "string") ] );
            ]
           @ extra) );
     ])

let json_content schema =
  Interview_json.obj
    [
      ( "application/json",
        Interview_json.obj [ ("schema", schema) ] );
    ]

let string_prop = Interview_json.obj [ ("type", Interview_json.str "string") ]

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
                "Recruiter-agent interview of Nathan Sculli against published \
                 facts, plus a tentative Google Calendar hold after work-email \
                 verify. Q&A does not require verification. create_hold does."
            );
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
      ( "tags",
        Interview_json.arr
          [
            Interview_json.obj
              [
                ("name", Interview_json.str "interview");
                ( "description",
                  Interview_json.str "Named sessions, cited Q&A, verify, holds"
                );
              ];
          ] );
      ( "paths",
        Interview_json.obj
          [
            ( "/interview/sessions",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("tags", Interview_json.arr [ Interview_json.str "interview" ]);
                        ("operationId", Interview_json.str "startSession");
                        ( "summary",
                          Interview_json.str
                            "Start a named recruiter-agent session" );
                        ( "requestBody",
                          Interview_json.obj
                            [
                              ("required", Interview_json.bool true);
                              ( "content",
                                json_content
                                  (Interview_json.obj
                                     [
                                       ("type", Interview_json.str "object");
                                       ( "required",
                                         Interview_json.arr
                                           [
                                             Interview_json.str "company";
                                             Interview_json.str "role";
                                             Interview_json.str "recruiter_name";
                                             Interview_json.str "work_email";
                                           ] );
                                       ( "properties",
                                         Interview_json.obj
                                           [
                                             ("company", string_prop);
                                             ("role", string_prop);
                                             ("recruiter_name", string_prop);
                                             ("work_email", string_prop);
                                             ("callback_url", string_prop);
                                           ] );
                                     ]) );
                            ] );
                        ( "responses",
                          Interview_json.obj
                            [
                              ( "201",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str "Session created" );
                                    ("content", json_content (Interview_json.obj [ ("type", Interview_json.str "object") ]));
                                  ] );
                              ( "400",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Invalid input or free-email blocklist"
                                    );
                                    ("content", json_content (schema_error []));
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
                              ( "content",
                                json_content
                                  (Interview_json.obj
                                     [
                                       ("type", Interview_json.str "object");
                                       ( "required",
                                         Interview_json.arr
                                           [ Interview_json.str "question" ] );
                                       ( "properties",
                                         Interview_json.obj
                                           [ ("question", string_prop) ] );
                                     ]) );
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
                                    ( "content",
                                      json_content
                                        (Interview_json.obj
                                           [ ("type", Interview_json.str "object") ])
                                    );
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
                            "Email a magic link to the session work email" );
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
                                        "Verification email sent; agent never \
                                         reads inbox" );
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
                            "Human magic-link click; issues a book token" );
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
                                        "Book token issued for this session" );
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
                            "Create a tentative Google Calendar hold" );
                        ( "description",
                          Interview_json.str
                            "Requires a book token from verify, a completed \
                             required question set (refuses do not count), and \
                             a work domain under the active-hold cap. Default \
                             hold length is 1 hour when end is omitted. Calendar \
                             id is configurable (default scull7.com)." );
                        ( "requestBody",
                          Interview_json.obj
                            [
                              ("required", Interview_json.bool true);
                              ( "content",
                                json_content
                                  (Interview_json.obj
                                     [
                                       ("type", Interview_json.str "object");
                                       ( "required",
                                         Interview_json.arr
                                           [
                                             Interview_json.str "start";
                                             Interview_json.str "book_token";
                                           ] );
                                       ( "properties",
                                         Interview_json.obj
                                           [
                                             ( "start",
                                               Interview_json.obj
                                                 [
                                                   ( "type",
                                                     Interview_json.str "string"
                                                   );
                                                   ("format", Interview_json.str "date-time");
                                                 ] );
                                             ( "end",
                                               Interview_json.obj
                                                 [
                                                   ( "type",
                                                     Interview_json.str "string"
                                                   );
                                                   ("format", Interview_json.str "date-time");
                                                 ] );
                                             ("book_token", string_prop);
                                           ] );
                                     ]) );
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
                                  ] );
                              ( "409",
                                Interview_json.obj
                                  [
                                    ( "description",
                                      Interview_json.str
                                        "Required set incomplete or domain hold cap"
                                    );
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
                                  [ ("description", Interview_json.str "JSON Resume") ]
                              );
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
                                      Interview_json.str "Cited experience hits"
                                    );
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
                        ("operationId", Interview_json.str "banFromHoldEmail");
                        ( "summary",
                          Interview_json.str
                            "One-click ban from the hold notification email" );
                        ( "parameters",
                          Interview_json.arr
                            [
                              Interview_json.obj
                                [
                                  ("name", Interview_json.str "kind");
                                  ("in", Interview_json.str "query");
                                  ("required", Interview_json.bool true);
                                  ( "schema",
                                    Interview_json.obj
                                      [
                                        ("type", Interview_json.str "string");
                                        ( "enum",
                                          Interview_json.arr
                                            [
                                              Interview_json.str "address";
                                              Interview_json.str "domain";
                                            ] );
                                      ] );
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
                                  [ ("description", Interview_json.str "Banned") ]
                              );
                            ] );
                      ] );
                ] );
            ( "/mcp",
              Interview_json.obj
                [
                  ( "post",
                    Interview_json.obj
                      [
                        ("operationId", Interview_json.str "mcp");
                        ( "summary",
                          Interview_json.str
                            "MCP JSON-RPC. Tools: start_interview, ask_nathan, \
                             request_verification, create_hold, get_resume" );
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
