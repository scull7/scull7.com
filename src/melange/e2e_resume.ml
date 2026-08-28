(* Playwright e2e — T-24: a failed /resume.json keeps the shell up and
   offers :reload, for every fault class, and the retry is a new fetch
   rather than a document reload. *)

type browser
type page
type locator
type keyboard
type chromium
type route

external chromium : chromium = "chromium" [@@mel.module "playwright"]
external launch : chromium -> browser Js.Promise.t = "launch" [@@mel.send]
external new_page : browser -> page Js.Promise.t = "newPage" [@@mel.send]
external close_browser : browser -> unit Js.Promise.t = "close" [@@mel.send]
external page_goto : page -> string -> 'a -> 'b Js.Promise.t = "goto" [@@mel.send]

external page_wait_for_selector : page -> string -> 'a -> 'b Js.Promise.t
  = "waitForSelector"
[@@mel.send]

external page_wait_for_timeout : page -> int -> unit Js.Promise.t
  = "waitForTimeout"
[@@mel.send]

external page_route : page -> string -> (route -> unit) -> unit Js.Promise.t
  = "route"
[@@mel.send]

external page_unroute_all : page -> unit Js.Promise.t = "unrouteAll" [@@mel.send]
external route_abort : route -> unit Js.Promise.t = "abort" [@@mel.send]
external route_fulfill : route -> 'a -> unit Js.Promise.t = "fulfill" [@@mel.send]
external page_locator : page -> string -> locator = "locator" [@@mel.send]
external page_keyboard : page -> keyboard = "keyboard" [@@mel.get]
external page_on : page -> string -> ('a -> unit) -> unit = "on" [@@mel.send]
external page_evaluate_str : page -> string -> string Js.Promise.t = "evaluate" [@@mel.send]
external locator_count : locator -> int Js.Promise.t = "count" [@@mel.send]
external locator_inner_text : locator -> string Js.Promise.t = "innerText" [@@mel.send]
external keyboard_press : keyboard -> string -> unit Js.Promise.t = "press" [@@mel.send]
external keyboard_type : keyboard -> string -> unit Js.Promise.t = "type" [@@mel.send]
external error_message : 'a -> string = "message" [@@mel.get]

let base = E2e_ffi.env_or "BASE_URL" "http://127.0.0.1:4173"
let timeout = 15_000.
let ( >>= ) p f = Js.Promise.then_ f p
let resume_glob = "**/resume.json"

let valid_resume =
  {|{"basics":{"name":"Ada Lovelace","label":"Mathematician","email":"ada@example.com","url":"https://example.com","summary":"First algorithm.","location":{"city":"London","region":"","countryCode":"GB"},"profiles":[]},"work":[]}|}

let settle page = page_wait_for_timeout page 400

let count page sel = locator_count (page_locator page sel)

(* Every fault class must land in the same place: chrome up, failure named,
   :reload offered, and no resume content behind it. *)
let assert_failure_ux page label =
  count page "#vim-root" >>= fun root ->
  E2e_ffi.assert_ (root = 1) (label ^ ": #vim-root missing");
  count page "#vim-root .statusline" >>= fun status ->
  E2e_ffi.assert_ (status = 1) (label ^ ": #vim-root .statusline missing");
  count page "#vim-root .cmdline" >>= fun cmd ->
  E2e_ffi.assert_ (cmd = 1) (label ^ ": #vim-root .cmdline missing");
  count page "#buffer-body .hero h1" >>= fun hero ->
  E2e_ffi.assert_ (hero = 0) (label ^ ": stale resume rendered behind the failure");
  (* Browser.element replaces #app with the rendered root, so the mount
     point is asked for null-safely: the point is that the page is not blank. *)
  page_evaluate_str page
    "((document.getElementById('app') || document.getElementById('vim-root') \
     || document.body).innerText || '').trim()"
  >>= fun app_text ->
  E2e_ffi.assert_ (app_text <> "") (label ^ ": the mount point rendered nothing");
  locator_inner_text (page_locator page "#vim-root") >>= fun shell_text ->
  E2e_ffi.assert_
    (Js.String.includes ~search:":reload" shell_text)
    (label ^ ": :reload is not visible to the user");
  E2e_ffi.assert_
    (Js.Re.test ~str:shell_text [%mel.re "/resume\\.json/i"])
    (label ^ ": the failure does not name resume.json");
  E2e_ffi.console_log ("  ✓ " ^ label);
  Js.Promise.resolve ()

let boot_with page fault label =
  page_unroute_all page >>= fun () ->
  page_route page resume_glob fault >>= fun () ->
  page_goto page (base ^ "/") [%mel.obj { waitUntil = "load"; timeout }]
  >>= fun _ ->
  page_wait_for_selector page "#vim-root" [%mel.obj { timeout }] >>= fun _ ->
  settle page >>= fun () -> assert_failure_ux page label

let abort route = route_abort route |> ignore

let status_fault code route =
  route_fulfill route
    [%mel.obj { status = code; contentType = "application/json"; body = "{}" }]
  |> ignore

let bad_json route =
  route_fulfill route
    [%mel.obj { status = 200; contentType = "application/json"; body = "not json at all" }]
  |> ignore

let ok_resume route =
  route_fulfill route
    [%mel.obj
      { status = 200; contentType = "application/json"; body = valid_resume }]
  |> ignore

(* :reload must re-fetch in place. A document load would reset this marker. *)
let mark_document page =
  page_evaluate_str page "(window.__t24 = 'same-document') || ''"

let run_reload page =
  keyboard_press (page_keyboard page) ":" >>= fun () ->
  page_wait_for_timeout page 250 >>= fun () ->
  keyboard_type (page_keyboard page) "reload" >>= fun () ->
  page_wait_for_timeout page 150 >>= fun () ->
  keyboard_press (page_keyboard page) "Enter" >>= fun () ->
  page_wait_for_timeout page 700

let run () =
  launch chromium
  >>= (fun browser ->
        new_page browser >>= fun page ->
        let errors = ref [] in
        page_on page "pageerror" (fun e -> errors := error_message e :: !errors);
        let fetches = ref 0 in
        page_on page "request" (fun _ -> ());
        boot_with page abort "abort" >>= fun () ->
        boot_with page (status_fault 404) "404" >>= fun () ->
        boot_with page (status_fault 500) "500" >>= fun () ->
        boot_with page bad_json "200 invalid json" >>= fun () ->
        (* Retry while the fault remains: still failing, still no resume. *)
        mark_document page >>= fun _ ->
        run_reload page >>= fun () ->
        assert_failure_ux page "retry while still failing" >>= fun () ->
        page_evaluate_str page "window.__t24 || ''" >>= fun marker ->
        E2e_ffi.assert_
          (marker = "same-document")
          "retry performed a full document load";
        (* Retry once the route is healthy: content renders, still no reload. *)
        page_unroute_all page >>= fun () ->
        page_route page resume_glob ok_resume >>= fun () ->
        run_reload page >>= fun () ->
        locator_inner_text (page_locator page "#buffer-body .hero h1")
        >>= fun hero ->
        E2e_ffi.assert_
          (Js.String.includes ~search:"Ada Lovelace" hero)
          ("reload did not render the served resume, hero=" ^ hero);
        page_evaluate_str page "window.__t24 || ''" >>= fun marker2 ->
        E2e_ffi.assert_
          (marker2 = "same-document")
          "successful retry performed a full document load";
        E2e_ffi.console_log "  ✓ :reload retries in place and recovers";
        ignore !fetches;
        E2e_ffi.assert_ (!errors = [])
          ("page errors: " ^ String.concat "; " (List.rev !errors));
        E2e_ffi.console_log "e2e/resume PASS";
        close_browser browser >>= fun () ->
        E2e_ffi.set_exit_code 0;
        Node.Process.exit 0)
  |> Js.Promise.catch (fun err ->
         E2e_ffi.console_error_any err;
         E2e_ffi.console_error
           ("e2e/resume FAIL: " ^ E2e_ffi.error_to_string err);
         E2e_ffi.set_exit_code 1;
         Node.Process.exit 1)
  |> ignore
