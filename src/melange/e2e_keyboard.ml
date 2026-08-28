(* Playwright e2e — T-22 keyboard: Esc cycle, j/k after the palette, and
   terminal autofocus on opening the buffer (not on page load). *)

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
external page_evaluate_str : page -> string -> string Js.Promise.t = "evaluate" [@@mel.send]
external page_evaluate_bool : page -> string -> bool Js.Promise.t = "evaluate" [@@mel.send]
external locator_click : locator -> unit Js.Promise.t = "click" [@@mel.send]
external locator_inner_text : locator -> string Js.Promise.t = "innerText" [@@mel.send]
external locator_count : locator -> int Js.Promise.t = "count" [@@mel.send]
external keyboard_press : keyboard -> string -> unit Js.Promise.t = "press" [@@mel.send]
external error_message : 'a -> string = "message" [@@mel.get]

let base = E2e_ffi.env_or "BASE_URL" "http://127.0.0.1:4173"
let timeout = 15_000.
let ( >>= ) p f = Js.Promise.then_ f p

let wait_ready page =
  page_goto page (base ^ "/") [%mel.obj { waitUntil = "networkidle"; timeout }]
  >>= fun _ ->
  page_wait_for_selector page "#vim-root" [%mel.obj { timeout }] >>= fun _ ->
  page_wait_for_timeout page 400

let settle page = page_wait_for_timeout page 300

(* Calculations over the DOM, expressed as the smallest queries that can
   distinguish the states the card names. *)
let active_id = "(document.activeElement && document.activeElement.id) || ''"

let selected_name =
  "(function(){var e=document.querySelector('#buffer-items \
   .buffer-item[aria-selected=\"true\"] .name');return e?e.textContent.trim():'';})()"

let selected_is_focused =
  "!!document.querySelector('#buffer-items \
   .buffer-item[aria-selected=\"true\"].focused')"

let palette_open page = locator_count (page_locator page "#palette.open")

let open_terminal page =
  locator_click
    (page_locator_opts page "#buffer-items .buffer-item .name"
       [%mel.obj { hasText = [%mel.re "/^terminal$/"] }])
  >>= fun () -> settle page

(* j/k after the palette — the card's point is that palette use must not
   leave list navigation broken. *)
let prove_jk_after_palette page =
  page_evaluate_str page selected_name >>= fun before ->
  E2e_ffi.assert_ (before <> "") "T-22 no buffer row starts aria-selected";
  page_evaluate_bool page selected_is_focused >>= fun focused_before ->
  E2e_ffi.assert_ focused_before "T-22 selected row lacks .focused before palette";
  keyboard_press (page_keyboard page) ":" >>= fun () ->
  settle page >>= fun () ->
  palette_open page >>= fun opened ->
  E2e_ffi.assert_ (opened = 1) "T-22 palette did not open on :";
  keyboard_press (page_keyboard page) "Escape" >>= fun () ->
  settle page >>= fun () ->
  palette_open page >>= fun closed ->
  E2e_ffi.assert_ (closed = 0) "T-22 palette still open after Esc";
  keyboard_press (page_keyboard page) "j" >>= fun () ->
  settle page >>= fun () ->
  page_evaluate_str page selected_name >>= fun after_j ->
  E2e_ffi.assert_
    (after_j <> "" && after_j <> before)
    ("T-22 j did not move selection after palette, still " ^ after_j);
  page_evaluate_bool page selected_is_focused >>= fun focused_j ->
  E2e_ffi.assert_ focused_j "T-22 row selected by j lacks .focused";
  keyboard_press (page_keyboard page) "k" >>= fun () ->
  settle page >>= fun () ->
  page_evaluate_str page selected_name >>= fun after_k ->
  E2e_ffi.assert_
    (after_k = before)
    ("T-22 k did not return to " ^ before ^ ", got " ^ after_k);
  E2e_ffi.console_log "  ✓ j/k move aria-selected after the palette";
  Js.Promise.resolve ()

(* Autofocus is a property of opening the terminal buffer, not of page load. *)
let prove_terminal_autofocus page =
  page_evaluate_str page active_id >>= fun before ->
  E2e_ffi.assert_
    (before <> "terminal-input")
    "T-22 terminal-input already focused before opening the buffer";
  open_terminal page >>= fun () ->
  page_evaluate_str page active_id >>= fun after ->
  E2e_ffi.assert_
    (after = "terminal-input")
    ("T-22 terminal did not autofocus, active=" ^ after);
  E2e_ffi.console_log "  ✓ opening the terminal buffer focuses #terminal-input";
  Js.Promise.resolve ()

(* Esc from the terminal must leave NORMAL with no palette, then : must
   still open the palette and Esc close it. *)
let prove_esc_cycle page =
  keyboard_press (page_keyboard page) "Escape" >>= fun () ->
  settle page >>= fun () ->
  palette_open page >>= fun opened_by_esc ->
  E2e_ffi.assert_ (opened_by_esc = 0) "T-22 Esc from terminal opened the palette";
  page_evaluate_str page active_id >>= fun after_esc ->
  E2e_ffi.assert_
    (after_esc <> "terminal-input")
    "T-22 Esc left focus in #terminal-input";
  locator_inner_text (page_locator page "#vim-root .statusline .mode")
  >>= fun mode ->
  E2e_ffi.assert_
    (Js.String.includes ~search:"NORMAL" mode)
    ("T-22 statusline mode is not NORMAL after Esc, got " ^ mode);
  keyboard_press (page_keyboard page) ":" >>= fun () ->
  settle page >>= fun () ->
  palette_open page >>= fun reopened ->
  E2e_ffi.assert_ (reopened = 1) "T-22 : did not reopen the palette after Esc";
  page_evaluate_str page active_id >>= fun palette_focus ->
  E2e_ffi.assert_
    (palette_focus = "palette-input")
    ("T-22 palette not focused after :, active=" ^ palette_focus);
  keyboard_press (page_keyboard page) "Escape" >>= fun () ->
  settle page >>= fun () ->
  palette_open page >>= fun reclosed ->
  E2e_ffi.assert_ (reclosed = 0) "T-22 palette did not close on the second Esc";
  E2e_ffi.console_log "  ✓ Esc leaves NORMAL, then : / Esc cycle the palette";
  Js.Promise.resolve ()

let run () =
  launch chromium
  >>= (fun browser ->
        new_page browser >>= fun page ->
        let errors = ref [] in
        page_on page "pageerror" (fun e -> errors := error_message e :: !errors);
        wait_ready page >>= fun () ->
        prove_jk_after_palette page >>= fun () ->
        prove_terminal_autofocus page >>= fun () ->
        prove_esc_cycle page >>= fun () ->
        E2e_ffi.assert_ (!errors = [])
          ("page errors: " ^ String.concat "; " (List.rev !errors));
        E2e_ffi.console_log "e2e/keyboard PASS";
        close_browser browser >>= fun () ->
        E2e_ffi.set_exit_code 0;
        Node.Process.exit 0)
  |> Js.Promise.catch (fun err ->
         E2e_ffi.console_error_any err;
         E2e_ffi.console_error
           ("e2e/keyboard FAIL: " ^ E2e_ffi.error_to_string err);
         E2e_ffi.set_exit_code 1;
         Node.Process.exit 1)
  |> ignore
