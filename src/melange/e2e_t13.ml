(* T-13 crawlable proof: HTTP GET of Vite preview (no JS) plus local
   resume.json fixtures. Playwright is not used — crawlers do not execute JS. *)

let resume_rel = "public/resume.json"
let resume_path = Node.Path.join2 E2e_ffi.root resume_rel
let port = E2e_ffi.env_or "T13_PORT" "4175"
let base = "http://127.0.0.1:" ^ port

module Fixture = struct
  let name = "PBI-T-13 Fixture Name"
  let summary = "PBI-T-13-SUMMARY-TOKEN"
  let employer = "PBI-T-13-EMPLOYER"
  let crates = "https://example.invalid/pbi-t13"
end

module Prod = struct
  let name = "Nathan Sculli"
  let summary = "Director of Engineering at TensorWave"
  let employer = "TensorWave"
  let sub_zero = "Sub Zero Corp"
  let crates = "https://crates.io/users/scull7"
  let mailto = "mailto:nathan@vegasbuckeye.com"
  let github = "https://github.com/scull7"
  let tensorwave = "https://tensorwave.com"
  let banner = "Banner"
  let banner_url = "https://withbanner.com"
  let backtrace = "Backtrace.io"
  let marker_trax = "Marker Trax"
  let title = "Nathan Sculli"
  let og_title = {js|Nathan Sculli — scull7.com|js}
  let description = {js|Builder-leader · 20+ years · Rust · Distributed Systems|js}
  let job_title = "Director of Engineering"
end

let banner_highlights =
  [
    "Cut React web build time from 10 minutes to under 1 minute";
    "Fixed concurrency bugs in MongoDB call paths";
    "DevOps infrastructure design and implementation";
  ]

let ( >>= ) p f = Js.Promise.then_ f p

let extract_fragment html =
  match
    E2e_ffi.capture1
      [%mel.re
        "/<main\\s+id=[\"']crawlable-resume[\"']\\s*>([\\s\\S]*?)<\\/main>/i"]
      html
  with
  | Some inner -> inner
  | None -> failwith "missing <main id=\"crawlable-resume\"> in GET body"

let without_noscript html =
  Js.String.replaceByRe
    ~regexp:[%mel.re "/<noscript\\b[\\s\\S]*?<\\/noscript>/gi"]
    ~replacement:"" html

let visible_body_text html =
  let body =
    match E2e_ffi.capture1 [%mel.re "/<body[^>]*>([\\s\\S]*)<\\/body>/i"] html with
    | Some b -> b
    | None -> html
  in
  without_noscript body
  |> Js.String.replaceByRe
       ~regexp:[%mel.re "/<script\\b[\\s\\S]*?<\\/script>/gi"]
       ~replacement:" "
  |> Js.String.replaceByRe
       ~regexp:[%mel.re "/<style\\b[\\s\\S]*?<\\/style>/gi"]
       ~replacement:" "
  |> Js.String.replaceByRe ~regexp:[%mel.re "/<[^>]+>/g"] ~replacement:" "
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\s+/g"] ~replacement:" "
  |> String.trim

let assert_no_js_document html =
  let visible = without_noscript html in
  E2e_ffi.assert_
    (Js.Re.test ~str:visible [%mel.re "/<h1\\b[^>]*>[\\s\\S]*?<\\/h1>/i"])
    "AC no-JS: H1 missing outside noscript";
  E2e_ffi.assert_
    (Js.Re.test ~str:visible [%mel.re "/<h2\\b[^>]*>[\\s\\S]*?<\\/h2>/i"])
    "AC no-JS: H2 missing outside noscript";
  E2e_ffi.assert_
    (Js.Re.test ~str:visible [%mel.re "/<h3\\b[^>]*>[\\s\\S]*?<\\/h3>/i"])
    "AC no-JS: H3 missing outside noscript";
  E2e_ffi.assert_
    (not (Js.Re.test ~str:visible [%mel.re "/<a\\b[^>]*>\\s*<h[1-3]\\b/i"]))
    "AC no-JS: heading trapped inside a link";
  let text = visible_body_text html in
  E2e_ffi.assert_
    (String.length text >= 500)
    ("AC no-JS: need 500+ body chars outside noscript, got "
    ^ string_of_int (String.length text))

let hrefs fragment =
  E2e_ffi.global_captures
    [%mel.re "/<a\\s[^>]*href=[\"']([^\"']*)[\"']/gi"]
    fragment

let heading_texts fragment =
  E2e_ffi.global_captures [%mel.re "/<h2>([\\s\\S]*?)<\\/h2>/gi"] fragment
  |> List.map (fun s ->
         s
         |> Js.String.replaceByRe ~regexp:[%mel.re "/<[^>]+>/g"] ~replacement:""
         |> String.trim)

external regexp : string -> string -> Js.Re.t = "RegExp" [@@mel.new]

let meta html attr value =
  let re =
    regexp
      ("<meta\\s+" ^ attr ^ "=[\"']" ^ value ^ "[\"']\\s+content=[\"']([^\"']*)[\"']")
      "i"
  in
  match E2e_ffi.capture1 re html with Some v -> v | None -> ""

let page_title html =
  match E2e_ffi.capture1 [%mel.re "/<title>([^<]*)<\\/title>/i"] html with
  | Some t -> t
  | None -> ""

let person_json_ld html =
  match
    E2e_ffi.capture1
      [%mel.re
        "/<script\\s+type=[\"']application\\/ld\\+json[\"']\\s*>([\\s\\S]*?)<\\/script>/i"]
      html
  with
  | None -> failwith "missing Person JSON-LD in GET body"
  | Some raw -> Js.Json.parseExn raw

let as_dict json =
  match Js.Json.classify json with
  | JSONObject d -> d
  | _ -> failwith "expected object"

let as_array json =
  match Js.Json.classify json with
  | JSONArray a -> a
  | _ -> [||]

let string_field dict key =
  match Js.Dict.get dict key with
  | Some json -> ( match Js.Json.classify json with JSONString s -> s | _ -> "")
  | None -> ""

let object_field dict key =
  match Js.Dict.get dict key with
  | Some json -> as_dict json
  | None -> Js.Dict.empty ()

let has_href urls target =
  let strip u =
    let rec loop s =
      let n = String.length s in
      if n > 0 && s.[n - 1] = '/' then loop (String.sub s 0 (n - 1)) else s
    in
    loop u
  in
  List.exists (fun u -> u = target || strip u = strip target) urls

let tensorwave_hrefs urls =
  List.filter (fun u -> Js.Re.test ~str:u [%mel.re "/^https:\\/\\/tensorwave\\.com\\/?$/i"]) urls

let clone_json json = Js.Json.parseExn (Js.Json.stringify json)

let find_profile_idx profiles url =
  let rec loop i =
    if i >= Array.length profiles then None
    else
      let dict = as_dict profiles.(i) in
      if string_field dict "url" = url then Some i else loop (i + 1)
  in
  loop 0

let set_profile_url profiles idx url =
  let dict = as_dict profiles.(idx) in
  Js.Dict.set dict "url" (Js.Json.string url)

let mutate_resume doc =
  let next = clone_json doc in
  let root = as_dict next in
  let basics = object_field root "basics" in
  Js.Dict.set basics "name" (Js.Json.string Fixture.name);
  Js.Dict.set basics "summary" (Js.Json.string Fixture.summary);
  let work = as_array (Js.Dict.unsafeGet root "work") in
  let job0 = as_dict work.(0) in
  Js.Dict.set job0 "name" (Js.Json.string Fixture.employer);
  let profiles = as_array (Js.Dict.unsafeGet basics "profiles") in
  match find_profile_idx profiles Prod.crates with
  | None -> failwith "mutation: crates.io profile missing"
  | Some i ->
      set_profile_url profiles i Fixture.crates;
      next

let empty_urls doc =
  let next = clone_json doc in
  let root = as_dict next in
  let work = as_array (Js.Dict.unsafeGet root "work") in
  let job0 = as_dict work.(0) in
  Js.Dict.set job0 "url" (Js.Json.string "");
  let basics = object_field root "basics" in
  let profiles = as_array (Js.Dict.unsafeGet basics "profiles") in
  match find_profile_idx profiles Prod.github with
  | None -> failwith "empty-url: github profile missing"
  | Some i ->
      set_profile_url profiles i "";
      next

let remove_banner doc =
  let next = clone_json doc in
  let root = as_dict next in
  let work = as_array (Js.Dict.unsafeGet root "work") in
  let job2 = as_dict work.(2) in
  if string_field job2 "name" <> Prod.banner then
    failwith
      ("missing-job: work[2] is " ^ string_field job2 "name" ^ ", not Banner");
  let empty = Js.Dict.empty () in
  Js.Dict.set empty "name" (Js.Json.string "");
  Js.Dict.set empty "position" (Js.Json.string "");
  Js.Dict.set empty "url" (Js.Json.string "");
  Js.Dict.set empty "startDate" (Js.Json.string "");
  Js.Dict.set empty "endDate" (Js.Json.string "");
  Js.Dict.set empty "highlights" (Js.Json.array [||]);
  work.(2) <- Js.Json.object_ empty;
  next

let assert_ac1 fragment =
  E2e_ffi.assert_
    (Js.String.includes ~search:Prod.name fragment)
    "AC1: Nathan Sculli missing in crawlable main";
  E2e_ffi.assert_
    (Js.String.includes ~search:Prod.summary fragment)
    "AC1: summary sentence missing in crawlable main";
  E2e_ffi.assert_
    (Js.String.includes ~search:Prod.employer fragment)
    "AC1: TensorWave missing in crawlable main";
  let urls = hrefs fragment in
  E2e_ffi.assert_
    (has_href urls Prod.mailto || has_href urls Prod.crates)
    ("AC1: need mailto or crates.io href in noscript, got "
    ^ String.concat ", " urls)

let assert_identity_lock html =
  E2e_ffi.assert_ (page_title html = Prod.title) ("title drifted: " ^ page_title html);
  E2e_ffi.assert_
    (meta html "property" "og:title" = Prod.og_title)
    ("og:title drifted: " ^ meta html "property" "og:title");
  E2e_ffi.assert_
    (meta html "name" "description" = Prod.description)
    "meta description drifted";
  E2e_ffi.assert_
    (meta html "property" "og:description" = Prod.description)
    "og:description drifted";
  E2e_ffi.assert_
    (meta html "name" "twitter:description" = Prod.description)
    "twitter:description drifted";
  let ld = as_dict (person_json_ld html) in
  E2e_ffi.assert_
    (string_field ld "name" = Prod.name)
    ("JSON-LD name drifted: " ^ string_field ld "name");
  let desc = string_field ld "description" in
  E2e_ffi.assert_
    (String.length desc > 20)
    ("JSON-LD description missing: " ^ desc);
  E2e_ffi.assert_
    (string_field ld "jobTitle" = Prod.job_title)
    ("JSON-LD jobTitle drifted: " ^ string_field ld "jobTitle");
  let works_for = object_field ld "worksFor" in
  E2e_ffi.assert_
    (string_field works_for "name" = Prod.employer)
    ("JSON-LD worksFor drifted: " ^ string_field works_for "name");
  let contact = object_field works_for "contactPoint" in
  E2e_ffi.assert_
    (string_field contact "email" = "nathan@vegasbuckeye.com")
    "JSON-LD Organization contactPoint.email missing";
  let address = object_field works_for "address" in
  E2e_ffi.assert_
    (string_field address "addressLocality" = "Las Vegas")
    "JSON-LD Organization address missing"

let assert_mutation fragment html =
  E2e_ffi.assert_
    (Js.String.includes ~search:Fixture.name fragment)
    "mutation: fixture name missing";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.name fragment))
    "mutation: leftover Nathan Sculli in noscript (append-only inject?)";
  E2e_ffi.assert_
    (Js.String.includes ~search:Fixture.summary fragment)
    "mutation: summary token missing";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.summary fragment))
    "mutation: leftover production summary in noscript";
  E2e_ffi.assert_
    (Js.String.includes ~search:Fixture.employer fragment)
    "mutation: employer token missing";
  let headings = heading_texts fragment in
  let first_heading = match headings with h :: _ -> h | [] -> "" in
  E2e_ffi.assert_
    (first_heading = Fixture.employer)
    ("mutation: work[0] heading \"" ^ first_heading ^ "\" is not "
   ^ Fixture.employer);
  E2e_ffi.assert_
    (not (List.mem Prod.employer headings))
    "mutation: leftover TensorWave work[0] heading";
  let urls = hrefs fragment in
  E2e_ffi.assert_ (has_href urls Fixture.crates) "mutation: example.invalid href missing";
  E2e_ffi.assert_
    (not (has_href urls Prod.crates))
    "mutation: leftover crates.io href in noscript";
  assert_identity_lock html

let assert_empty_url fragment =
  let urls = hrefs fragment in
  let leftover = tensorwave_hrefs urls in
  E2e_ffi.assert_
    (leftover = [])
    ("empty-url: tensorwave.com href still present: " ^ String.concat ", " leftover);
  E2e_ffi.assert_
    (not (has_href urls Prod.github))
    "empty-url: emptied github href still present"

let assert_missing_job fragment =
  E2e_ffi.assert_ (String.trim fragment <> "") "missing-job: empty fragment";
  E2e_ffi.assert_
    (Js.String.includes ~search:Prod.employer fragment)
    "missing-job: TensorWave missing";
  E2e_ffi.assert_
    (Js.String.includes ~search:Prod.sub_zero fragment)
    "missing-job: Sub Zero Corp missing";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.banner fragment))
    "missing-job: Banner still in fragment";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.banner_url fragment))
    "missing-job: withbanner.com still in fragment";
  List.iter
    (fun highlight ->
      E2e_ffi.assert_
        (not (Js.String.includes ~search:highlight fragment))
        ("missing-job: Banner highlight still present: " ^ highlight))
    banner_highlights;
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.backtrace fragment))
    "missing-job: Backtrace.io substituted as third job";
  E2e_ffi.assert_
    (not (Js.String.includes ~search:Prod.marker_trax fragment))
    "missing-job: Marker Trax substituted"

let read_resume () =
  Js.Json.parseExn (Node.Fs.readFileAsUtf8Sync resume_path)

let write_resume doc =
  Node.Fs.writeFileAsUtf8Sync resume_path
    (E2e_ffi.json_stringify doc Js.Null.empty 2 ^ "\n")

let restore_resume () =
  let result =
    E2e_ffi.run_sync "git" [ "checkout"; "--"; resume_rel ]
      [%mel.obj { cwd = E2e_ffi.root; encoding = "utf8" }]
  in
  if E2e_ffi.status_of result <> 0 then
    failwith
      ("git checkout -- " ^ resume_rel ^ " exited "
      ^ string_of_int (E2e_ffi.status_of result)
      ^ ": " ^ result##stderr)

let inject_dist () =
  E2e_ffi.run_or_throw "npm" [ "run"; "inject:resume:dist" ]
    "npm run inject:resume:dist"

let inject_dist_status () =
  E2e_ffi.run_sync "npm" [ "run"; "inject:resume:dist" ]
    [%mel.obj
      {
        cwd = E2e_ffi.root;
        encoding = "utf8";
        env = Node.Process.process##env;
      }]

let resume_diff () =
  E2e_ffi.run_sync "git" [ "diff"; "--"; resume_rel ]
    [%mel.obj { cwd = E2e_ffi.root; encoding = "utf8" }]

let start_preview_ready () =
  E2e_ffi.wait_port_free port 40 >>= fun () ->
  let child = E2e_ffi.start_preview port in
  E2e_ffi.wait_http ~cache:false (base ^ "/") 40
  |> Js.Promise.then_ (fun () -> Js.Promise.resolve child)
  |> Js.Promise.catch (fun err ->
         E2e_ffi.stop_preview port (Some child);
         E2e_ffi.wait_port_free port 40 >>= fun () -> Js.Promise.reject (Obj.magic err))

let recycle_preview child =
  E2e_ffi.stop_preview port (Some child);
  E2e_ffi.wait_port_free port 40 >>= fun () -> start_preview_ready ()

let get_home () =
  E2e_ffi.fetch2 (base ^ "/") [%mel.obj { cache = "no-store" }] >>= fun res ->
  E2e_ffi.assert_ (E2e_ffi.response_ok res)
    ("GET / status " ^ string_of_int (E2e_ffi.response_status res));
  E2e_ffi.response_text res

let with_resume_restored label fn =
  Js.Promise.make (fun ~resolve ~reject ->
      let ok () =
        restore_resume ();
        E2e_ffi.pass label;
        let u = () in
        resolve u [@u]
      in
      let fail err =
        (try restore_resume () with _ -> ());
        reject (Obj.magic err : exn) [@u]
      in
      (try fn ()
       with exn -> Js.Promise.reject exn)
      |> Js.Promise.then_ (fun () ->
             ok ();
             Js.Promise.resolve ())
      |> Js.Promise.catch (fun err ->
             fail err;
             Js.Promise.resolve ())
      |> ignore)

let prove_ac1 () =
  get_home () >>= fun html ->
  assert_ac1 (extract_fragment html);
  assert_no_js_document html;
  E2e_ffi.pass "AC1 HTTP GET / crawlable main (no JS)";
  Js.Promise.resolve ()

let current_preview preview_ref =
  match !preview_ref with
  | Some child -> child
  | None -> failwith "preview not started"

let prove_mutation committed preview_ref =
  with_resume_restored "AC mutation fixture" (fun () ->
      write_resume (mutate_resume committed);
      inject_dist ();
      recycle_preview (current_preview preview_ref) >>= fun child ->
      preview_ref := Some child;
      get_home () >>= fun html ->
      assert_mutation (extract_fragment html) html;
      Js.Promise.resolve ())

let prove_empty_url committed preview_ref =
  with_resume_restored "AC empty-URL fixture" (fun () ->
      write_resume (empty_urls committed);
      inject_dist ();
      recycle_preview (current_preview preview_ref) >>= fun child ->
      preview_ref := Some child;
      get_home () >>= fun html ->
      assert_empty_url (extract_fragment html);
      Js.Promise.resolve ())

let prove_missing_job committed preview_ref =
  with_resume_restored "AC missing-job fixture" (fun () ->
      write_resume (remove_banner committed);
      inject_dist ();
      recycle_preview (current_preview preview_ref) >>= fun child ->
      preview_ref := Some child;
      get_home () >>= fun html ->
      assert_missing_job (extract_fragment html);
      Js.Promise.resolve ())

let prove_invalid_json () =
  with_resume_restored "AC invalid JSON" (fun () ->
      Node.Fs.writeFileAsUtf8Sync resume_path "{ this is not json\n";
      let result = inject_dist_status () in
      let status = E2e_ffi.status_of result in
      E2e_ffi.assert_ (status <> 0)
        ("invalid JSON inject exited " ^ string_of_int status ^ " (want non-zero)");
      E2e_ffi.console_log
        ("  inject:resume:dist exited " ^ string_of_int status);
      Js.Promise.resolve ())

let assert_resume_clean () =
  let diff = resume_diff () in
  E2e_ffi.assert_
    (diff##stdout = "")
    ("public/resume.json dirty after restore:\n" ^ diff##stdout);
  E2e_ffi.pass "public/resume.json restored (git diff empty)"

let run () =
  let preview = ref None in
  let finish code =
    (try restore_resume ()
     with exn ->
       E2e_ffi.console_error ("resume restore failed: " ^ Printexc.to_string exn);
       E2e_ffi.set_exit_code 1);
    E2e_ffi.stop_preview port !preview;
    E2e_ffi.set_exit_code
      (if code <> 0 then code
       else
         match Js.Undefined.toOption (E2e_ffi.exit_code ()) with
         | Some c -> c
         | None -> 0);
    E2e_ffi.wait_port_free port 40
    |> Js.Promise.catch (fun _ -> Js.Promise.resolve ())
    |> Js.Promise.then_ (fun () ->
           E2e_ffi.schedule_exit ();
           Js.Promise.resolve ())
    |> ignore
  in
  let body =
    (if E2e_ffi.env_get "SKIP_BUILD" <> Some "1" then (
       E2e_ffi.console_log "→ npm run build";
       E2e_ffi.run_or_throw "npm" [ "run"; "build" ] "npm run build"));
    E2e_ffi.console_log ("→ vite preview :" ^ port);
    start_preview_ready () >>= fun child ->
    preview := Some child;
    let committed = read_resume () in
    prove_ac1 () >>= fun () ->
    prove_mutation committed preview >>= fun () ->
    prove_empty_url committed preview >>= fun () ->
    prove_missing_job committed preview >>= fun () ->
    prove_invalid_json () >>= fun () ->
    inject_dist ();
    assert_resume_clean ();
    E2e_ffi.console_log "e2e/t13-crawlable PASS";
    finish 0;
    Js.Promise.resolve ()
  in
  body
  |> Js.Promise.catch (fun err ->
         E2e_ffi.console_error_any err;
         E2e_ffi.console_error
           ("e2e/t13-crawlable FAIL: " ^ E2e_ffi.error_to_string err);
         finish 1;
         Js.Promise.resolve ())
  |> ignore
