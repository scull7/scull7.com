(* Agent-readiness proofs: Accept parsing, markdown negotiation, 404 recovery,
   trust-page length, llms.txt / sitemap. *)

let port = E2e_ffi.env_or "AGENTIC_PORT" "4176"
let base = "http://127.0.0.1:" ^ port

let prove_accept_parsing () =
  let cases =
    [
      (Some "text/markdown", Some "text/markdown");
      (Some "text/markdown, text/html;q=0.8", Some "text/markdown");
      (Some "text/html", Some "text/html");
      (Some "text/markdown;q=0, text/html", Some "text/html");
      (Some "text/markdown, text/html", Some "text/markdown");
      (Some "text/html, text/markdown;q=0.8", Some "text/html");
      (Some "*/*", Some "text/html");
      (None, Some "text/html");
      (Some "", Some "text/html");
      ( Some
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        Some "text/html" );
    ]
  in
  List.iter
    (fun (header, expect) ->
      let got = Accept.preferred_type header Accept.produces in
      let show = function None -> "null" | Some s -> s in
      E2e_ffi.assert_
        (got = expect)
        ("Accept \""
        ^ (match header with None -> "null" | Some s -> s)
        ^ "\" → " ^ show got ^ ", want " ^ show expect))
    cases;
  E2e_ffi.assert_
    (Accept.preferred_type (Some "application/pdf") Accept.produces = None)
    "application/pdf should 406";
  E2e_ffi.assert_
    (Accept.preferred_type (Some "text/markdown;q=0") [ "text/markdown" ] = None)
    "markdown q=0 against md-only should 406";
  E2e_ffi.pass "Accept parsing q-values / 406 / browser header"

let prove_missing_path_markdown_plan () =
  let missing_md =
    Plan.plan_negotiation ~accept:(Some "text/markdown") ~page_md_exists:false
      ~origin_status:404 ()
  in
  E2e_ffi.assert_
    (missing_md.action = "not-found-markdown" && missing_md.status = 404)
    ("missing path + Accept: text/markdown → " ^ missing_md.action ^ " "
    ^ string_of_int missing_md.status
    ^ " (want not-found-markdown 404, not 406)");
  let missing_html =
    Plan.plan_negotiation ~accept:None ~page_md_exists:false ~origin_status:404
      ()
  in
  E2e_ffi.assert_
    (missing_html.action = "not-found-html" && missing_html.status = 404)
    ("missing path + browser Accept → " ^ missing_html.action);
  let pdf =
    Plan.plan_negotiation ~accept:(Some "application/pdf") ~page_md_exists:false
      ~origin_status:404 ()
  in
  E2e_ffi.assert_
    (pdf.action = "not-acceptable" && pdf.status = 406)
    ("application/pdf → " ^ pdf.action ^ " " ^ string_of_int pdf.status);
  let page_md =
    Plan.plan_negotiation ~accept:(Some "text/markdown") ~page_md_exists:true
      ~origin_status:200 ()
  in
  E2e_ffi.assert_
    (page_md.action = "page-markdown" && page_md.status = 200)
    ("existing .md sibling → " ^ page_md.action);
  E2e_ffi.pass "edge plan: missing path + Accept markdown is 404, not 406"

let prove_trust_page_files () =
  List.iter
    (fun name ->
      let html =
        Node.Fs.readFileAsUtf8Sync
          (Node.Path.join [| E2e_ffi.root; "public/" ^ name ^ ".html" |])
      in
      let text = E2e_ffi.visible_text html in
      E2e_ffi.assert_
        (String.length text >= 500)
        (name ^ ".html visible text " ^ string_of_int (String.length text)
       ^ " < 500");
      E2e_ffi.assert_
        (Js.Re.test ~str:text [%mel.re "/Nathan Sculli/"])
        (name ^ ".html missing name");
      E2e_ffi.assert_
        (Js.Re.test ~str:text [%mel.re "/vegasbuckeye\\.com/"])
        (name ^ ".html missing email");
      let md =
        Node.Fs.readFileAsUtf8Sync
          (Node.Path.join [| E2e_ffi.root; "public/" ^ name ^ ".md" |])
      in
      E2e_ffi.assert_
        (String.length md >= 500)
        (name ^ ".md " ^ string_of_int (String.length md) ^ " < 500"))
    [ "about"; "contact"; "privacy" ];
  let llms =
    Node.Fs.readFileAsUtf8Sync
      (Node.Path.join [| E2e_ffi.root; "public/llms.txt" |])
  in
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/When to use this/i"])
    "llms.txt missing When to use this";
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/not a SaaS API/i"]
    && Js.Re.test ~str:llms [%mel.re "/not an MCP server/i"])
    "llms.txt missing not-for jobs";
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/TensorWave/"])
    "llms.txt missing TensorWave";
  E2e_ffi.pass "trust pages + llms.txt on disk"

let fetch_path path accept =
  let headers = Js.Dict.empty () in
  (match accept with Some value -> Js.Dict.set headers "Accept" value | None -> ());
  E2e_ffi.fetch2 (base ^ path) [%mel.obj { cache = "no-store"; headers }]

let content_type headers = E2e_ffi.header_get headers "content-type"

let ( >>= ) p f = Js.Promise.then_ f p

let require_ok res label =
  E2e_ffi.assert_ (E2e_ffi.response_ok res)
    (label ^ " " ^ string_of_int (E2e_ffi.response_status res));
  res

let rec fold_pages pages f =
  match pages with
  | [] -> Js.Promise.resolve ()
  | page :: rest -> f page >>= fun () -> fold_pages rest f

let prove_trust_pages () =
  fold_pages [ "/about"; "/contact"; "/privacy" ] (fun page ->
      fetch_path page None >>= fun res ->
      ignore (require_ok res ("GET " ^ page));
      E2e_ffi.response_text res >>= fun html ->
      let text = E2e_ffi.visible_text html in
      E2e_ffi.assert_
        (String.length text >= 500)
        (page ^ " text " ^ string_of_int (String.length text) ^ " < 500");
      fetch_path page (Some "text/markdown") >>= fun md_res ->
      E2e_ffi.assert_
        (String.starts_with ~prefix:"text/markdown"
           (content_type (E2e_ffi.response_headers md_res)))
        (page ^ " markdown Content-Type");
      Js.Promise.resolve ())

let prove_missing_tokens body kind =
  List.iter
    (fun token ->
      E2e_ffi.assert_
        (Js.String.includes ~search:token (String.lowercase_ascii body))
        (kind ^ " missing " ^ token))
    [ "sitemap"; "llms.txt"; "about"; "contact"; "privacy" ]

let prove_http () : unit Js.Promise.t =
  fetch_path "/" None >>= fun home ->
  ignore (require_ok home "GET /");
  E2e_ffi.response_text home >>= fun home_html ->
  let home_text = E2e_ffi.visible_text home_html in
  E2e_ffi.assert_
    (String.length home_text >= 500)
    ("GET / visible text " ^ string_of_int (String.length home_text) ^ " < 500");
  E2e_ffi.assert_
    (Js.Re.test ~str:home_html [%mel.re "/<h1\\b/i"])
    "GET / missing H1";
  E2e_ffi.assert_
    (E2e_ffi.header_has (E2e_ffi.response_headers home) "vary" "accept")
    ("GET / Vary=" ^ E2e_ffi.header_get (E2e_ffi.response_headers home) "vary");
  fetch_path "/" (Some "text/markdown") >>= fun md ->
  ignore (require_ok md "GET / markdown");
  let md_type = content_type (E2e_ffi.response_headers md) in
  E2e_ffi.assert_
    (String.starts_with ~prefix:"text/markdown" md_type
    && Js.String.includes ~search:"charset=utf-8" md_type)
    ("GET / markdown Content-Type=" ^ md_type);
  E2e_ffi.assert_
    (E2e_ffi.header_has (E2e_ffi.response_headers md) "vary" "accept")
    ("markdown Vary=" ^ E2e_ffi.header_get (E2e_ffi.response_headers md) "vary");
  E2e_ffi.response_text md >>= fun md_body ->
  E2e_ffi.assert_
    (Js.Re.test ~str:md_body [%mel.re "/Nathan Sculli/"])
    "markdown home missing name";
  E2e_ffi.assert_
    (Js.Re.test ~str:md_body [%mel.re "/TensorWave/"])
    "markdown home missing TensorWave";
  E2e_ffi.pass "GET / HTML + Accept: text/markdown";
  fetch_path "/" (Some "text/markdown, text/html;q=0.8") >>= fun q ->
  E2e_ffi.assert_
    (String.starts_with ~prefix:"text/markdown"
       (content_type (E2e_ffi.response_headers q)))
    "q-value markdown preference lost";
  fetch_path "/"
    (Some
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,*/*;q=0.8")
  >>= fun chrome ->
  E2e_ffi.assert_ (E2e_ffi.response_ok chrome) "browser Accept should not 406";
  E2e_ffi.assert_
    (Js.String.includes ~search:"text/html"
       (content_type (E2e_ffi.response_headers chrome)))
    "browser Accept should stay HTML";
  fetch_path "/" (Some "application/pdf") >>= fun not_acceptable ->
  E2e_ffi.assert_
    (E2e_ffi.response_status not_acceptable = 406)
    ("pdf Accept status "
    ^ string_of_int (E2e_ffi.response_status not_acceptable));
  E2e_ffi.assert_
    (E2e_ffi.header_has (E2e_ffi.response_headers not_acceptable) "vary" "accept")
    "406 missing Vary Accept";
  E2e_ffi.pass "q-values, browser Accept, 406";
  prove_trust_pages () >>= fun () ->
  E2e_ffi.pass "trust pages HTML + markdown";
  let missing = "/__missing_agentic_404__" in
  fetch_path missing None >>= fun html404 ->
  E2e_ffi.assert_
    (E2e_ffi.response_status html404 = 404)
    ("missing path status " ^ string_of_int (E2e_ffi.response_status html404));
  E2e_ffi.response_text html404 >>= fun body404 ->
  prove_missing_tokens body404 "404 HTML";
  fetch_path missing (Some "text/markdown") >>= fun md404 ->
  E2e_ffi.assert_
    (E2e_ffi.response_status md404 = 404)
    ("missing path + Accept: text/markdown status "
    ^ string_of_int (E2e_ffi.response_status md404)
    ^ " (must be 404 with 404.md, not 406)");
  E2e_ffi.assert_
    (String.starts_with ~prefix:"text/markdown"
       (content_type (E2e_ffi.response_headers md404)))
    ("markdown 404 Content-Type="
    ^ content_type (E2e_ffi.response_headers md404));
  E2e_ffi.assert_
    (E2e_ffi.response_status md404 <> 406)
    "missing path + Accept: text/markdown must not 406 before /404.md";
  E2e_ffi.response_text md404 >>= fun md404_body ->
  prove_missing_tokens md404_body "404 markdown";
  E2e_ffi.pass "404 HTML + markdown recovery";
  fold_pages [ "/llms.txt"; "/sitemap.xml"; "/for-agents"; "/resume.json" ]
    (fun p ->
      fetch_path p None >>= fun res ->
      ignore (require_ok res ("GET " ^ p));
      Js.Promise.resolve ())
  >>= fun () ->
  E2e_ffi.fetch1 (base ^ "/llms.txt") >>= E2e_ffi.response_text >>= fun llms ->
  E2e_ffi.assert_
    (Js.Re.test ~str:llms [%mel.re "/When to use this/"])
    "served llms.txt missing When to use this";
  E2e_ffi.pass "llms.txt sitemap for-agents resume.json";
  Js.Promise.resolve ()

let run () =
  let preview = ref None in
  let finish code =
    E2e_ffi.stop_preview port !preview;
    E2e_ffi.set_exit_code code;
    E2e_ffi.wait_port_free port 40
    |> Js.Promise.catch (fun _ -> Js.Promise.resolve ())
    |> Js.Promise.then_ (fun () ->
           E2e_ffi.schedule_exit ();
           Js.Promise.resolve ())
    |> ignore
  in
  try
    prove_accept_parsing ();
    prove_missing_path_markdown_plan ();
    prove_trust_page_files ();
    (if E2e_ffi.env_get "SKIP_BUILD" <> Some "1" then (
       E2e_ffi.console_log "→ npm run build";
       E2e_ffi.run_or_throw "npm" [ "run"; "build" ] "npm run build"));
    E2e_ffi.console_log ("→ vite preview :" ^ port);
    E2e_ffi.wait_port_free port 40
    |> Js.Promise.then_ (fun () ->
           preview := Some (E2e_ffi.start_preview port);
           E2e_ffi.wait_http ~cache:false (base ^ "/") 40)
    |> Js.Promise.then_ (fun () -> prove_http ())
    |> Js.Promise.then_ (fun () ->
           E2e_ffi.console_log "e2e/agentic PASS";
           finish 0;
           Js.Promise.resolve ())
    |> Js.Promise.catch (fun err ->
           let msg =
             try Js.Exn.message (Obj.magic err) |> fun o ->
                 match o with Some m -> m | None -> "unknown error"
             with _ -> "unknown error"
           in
           E2e_ffi.console_error ("e2e/agentic FAIL: " ^ msg);
           finish 1;
           Js.Promise.resolve ())
    |> ignore
  with exn ->
    E2e_ffi.console_error ("e2e/agentic FAIL: " ^ Printexc.to_string exn);
    finish 1
