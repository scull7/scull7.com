(* Playwright e2e — buffer navigation + palette focus. *)

type browser
type page
type locator
type keyboard
type chromium

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

external page_locator : page -> string -> locator = "locator" [@@mel.send]
external page_locator_opts : page -> string -> 'a -> locator = "locator" [@@mel.send]
external page_keyboard : page -> keyboard = "keyboard" [@@mel.get]
external page_on : page -> string -> ('a -> unit) -> unit = "on" [@@mel.send]
external page_evaluate : page -> string -> 'a Js.Promise.t = "evaluate" [@@mel.send]
external locator_click : locator -> unit Js.Promise.t = "click" [@@mel.send]

external locator_text_content : locator -> string Js.null Js.Promise.t
  = "textContent"
[@@mel.send]

external locator_inner_text : locator -> string Js.Promise.t = "innerText"
[@@mel.send]

external locator_count : locator -> int Js.Promise.t = "count" [@@mel.send]
external locator_first : locator -> locator = "first" [@@mel.send]
external keyboard_press : keyboard -> string -> unit Js.Promise.t = "press" [@@mel.send]
external keyboard_type : keyboard -> string -> unit Js.Promise.t = "type" [@@mel.send]
external error_message : 'a -> string = "message" [@@mel.get]

let base = E2e_ffi.env_or "BASE_URL" "http://127.0.0.1:4173"
let timeout = 15_000.

let ( >>= ) p f = Js.Promise.then_ f p

let wait_ready page =
  page_goto page (base ^ "/")
    [%mel.obj { waitUntil = "networkidle"; timeout }]
  >>= fun _ ->
  page_wait_for_selector page "#vim-root" [%mel.obj { timeout }] >>= fun _ ->
  page_wait_for_timeout page 400

let has_text text = [%mel.obj { hasText = text }]

let run () =
  launch chromium
  >>= (fun browser ->
        new_page browser >>= fun page ->
        let errors = ref [] in
        page_on page "pageerror" (fun e ->
            errors := error_message e :: !errors);
        wait_ready page >>= fun () ->
        locator_text_content (page_locator page "#buffer-body .hero h1")
        >>= fun hero_null ->
        let hero =
          match Js.Null.toOption hero_null with Some s -> s | None -> ""
        in
        E2e_ffi.assert_
          (Js.String.includes ~search:"Nathan Sculli" hero)
          ("hero name missing: " ^ hero);
        locator_inner_text (page_locator page "#buffer-body")
        >>= fun home_body ->
        E2e_ffi.assert_ (String.length home_body > 40) "home body empty";
        locator_click
          (page_locator_opts page "#buffer-items .buffer-item"
             (has_text "experience.md"))
        >>= fun () ->
        page_wait_for_timeout page 350 >>= fun () ->
        locator_inner_text (page_locator page "#buffer-body") >>= fun exp_body ->
        E2e_ffi.assert_
          (Js.Re.test ~str:exp_body [%mel.re "/work experience/i"]
          || Js.String.includes ~search:"TensorWave" exp_body)
          "experience body did not load (regression: tab-only switch)";
        E2e_ffi.assert_ (exp_body <> home_body)
          "body text unchanged after experience click";
        locator_click
          (page_locator_opts page "#buffer-items .buffer-item .name"
             [%mel.obj { hasText = [%mel.re "/^skills\\.md$/"] }])
        >>= fun () ->
        page_wait_for_timeout page 350 >>= fun () ->
        locator_inner_text (page_locator page "#buffer-body")
        >>= fun skills_body ->
        E2e_ffi.assert_ (skills_body <> exp_body)
          "body text unchanged after skills click";
        E2e_ffi.assert_
          (Js.Re.test ~str:skills_body [%mel.re "/language|skill|rust|stack/i"])
          ("skills body unexpected: " ^ Js.String.slice ~start:0 ~end_:120 skills_body);
        locator_click
          (page_locator_opts page "#buffer-items .buffer-item" (has_text "cents.rs"))
        >>= fun () ->
        page_wait_for_timeout page 350 >>= fun () ->
        locator_count (page_locator page "#buffer-body pre.code-block .kw")
        >>= fun kw ->
        E2e_ffi.assert_ (kw > 0) "code highlight missing .kw spans";
        keyboard_press (page_keyboard page) ":" >>= fun () ->
        page_wait_for_timeout page 300 >>= fun () ->
        page_evaluate page
          "() => document.activeElement && document.activeElement.id"
        >>= fun focused ->
        E2e_ffi.assert_ (focused = "palette-input")
          ("palette not focused, got " ^ focused);
        locator_count (page_locator page "#palette.open") >>= fun open_count ->
        E2e_ffi.assert_ (open_count = 1) "palette not open";
        keyboard_type (page_keyboard page) "exp" >>= fun () ->
        page_wait_for_timeout page 150 >>= fun () ->
        locator_inner_text (page_locator page ".cmdline .msg") >>= fun echo ->
        E2e_ffi.assert_
          (String.starts_with ~prefix:":exp" echo)
          ("cmdline echo missing, got \"" ^ echo ^ "\"");
        locator_inner_text
          (locator_first (page_locator page ".palette-results li"))
        >>= fun top_label ->
        E2e_ffi.assert_
          (Js.Re.test ~str:top_label [%mel.re "/experience/i"])
          ("fuzzy rank failed, top=\"" ^ top_label ^ "\"");
        keyboard_press (page_keyboard page) "Escape" >>= fun () ->
        page_wait_for_timeout page 250 >>= fun () ->
        locator_count (page_locator page "#palette.open") >>= fun closed ->
        E2e_ffi.assert_ (closed = 0) "palette still open after Esc";
        locator_click
          (page_locator_opts page "#buffer-items .buffer-item" (has_text "help.txt"))
        >>= fun () ->
        page_wait_for_timeout page 300 >>= fun () ->
        locator_inner_text (page_locator page "#buffer-body") >>= fun help ->
        E2e_ffi.assert_
          (Js.Re.test ~str:help [%mel.re "/NORMAL/"]
          && Js.Re.test ~str:help [%mel.re "/COMMAND/"])
          "help mode diagram missing";
        keyboard_press (page_keyboard page) ":" >>= fun () ->
        page_wait_for_timeout page 200 >>= fun () ->
        keyboard_press (page_keyboard page) "Control+[" >>= fun () ->
        page_wait_for_timeout page 250 >>= fun () ->
        locator_count (page_locator page "#palette.open") >>= fun after_ctrl ->
        E2e_ffi.assert_ (after_ctrl = 0) "Ctrl-[ did not close palette";
        E2e_ffi.assert_ (!errors = [])
          ("page errors: " ^ String.concat "; " (List.rev !errors));
        E2e_ffi.console_log "e2e/navigation PASS";
        close_browser browser >>= fun () ->
        E2e_ffi.set_exit_code 0;
        Node.Process.exit 0)
  |> Js.Promise.catch (fun err ->
         let msg =
           match Js.Exn.message (Obj.magic err) with
           | Some m -> m
           | None ->
               (try Printexc.to_string (Obj.magic err)
                with _ -> "unknown error")
         in
         E2e_ffi.console_error ("e2e/navigation FAIL: " ^ msg);
         E2e_ffi.set_exit_code 1;
         Node.Process.exit 1)
  |> ignore
