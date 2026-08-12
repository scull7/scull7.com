(* Melange entry — boots Elm and wires ports (focus, blur, scroll, key preventDefault). *)

type scroll_msg = {
  action : string;
  dir : int;
}

type 'a port = { subscribe : ('a -> unit) -> unit }

type ports = {
  focus : string port;
  blur : string port;
  scrollBuffer : scroll_msg port;
}

type elm_app = { ports : ports }
type flags = { isMobile : bool }

type init_args = {
  node : Dom.element;
  flags : flags;
}

type main_ns = { init : init_args -> elm_app }
type elm_root = { main : main_ns [@mel.as "Main"] }

(* Vite resolves leading-/ from project root *)
external elm : elm_root = "Elm" [@@mel.module "/src/elm/Main.elm"]

external document : Dom.document = "document"
external window : Dom.window = "window"

external get_element_by_id : Dom.document -> string -> Dom.element Js.nullable
  = "getElementById"
[@@mel.send]

external query_selector : Dom.document -> string -> Dom.element Js.nullable
  = "querySelector"
[@@mel.send]

external focus_el : Dom.element -> < preventScroll : bool > Js.t -> unit
  = "focus"
[@@mel.send]

external blur_el : Dom.element -> unit = "blur" [@@mel.send]

external scroll_by :
  Dom.element -> < top : float ; behavior : string > Js.t -> unit
  = "scrollBy"
[@@mel.send]

external scroll_to :
  Dom.element -> < top : float ; behavior : string > Js.t -> unit
  = "scrollTo"
[@@mel.send]

external client_height : Dom.element -> float = "clientHeight" [@@mel.get]
external scroll_height : Dom.element -> float = "scrollHeight" [@@mel.get]

external active_element : Dom.document -> Dom.element Js.nullable
  = "activeElement"
[@@mel.get]

external tag_name : Dom.element -> string = "tagName" [@@mel.get]
external element_id : Dom.element -> string = "id" [@@mel.get]

type class_list

external class_list : Dom.element -> class_list = "classList" [@@mel.get]

external class_list_contains : class_list -> string -> bool = "contains"
[@@mel.send]

external add_event_listener :
  Dom.document -> string -> (Dom.event Js.t -> unit) -> bool -> unit
  = "addEventListener"
[@@mel.send]

external prevent_default : 'a -> unit = "preventDefault" [@@mel.send]
external event_key : 'a -> string = "key" [@@mel.get]
external event_ctrl : 'a -> bool = "ctrlKey" [@@mel.get]
external event_meta : 'a -> bool = "metaKey" [@@mel.get]

type media_query_list = { matches : bool }

external match_media : Dom.window -> string -> media_query_list = "matchMedia"
[@@mel.send]

external set_timeout : (unit -> unit) -> int -> unit = "setTimeout"
[@@mel.scope "globalThis"]

external console_error : string -> unit = "error" [@@mel.scope "console"]

let rec attempt_focus id n =
  match Js.Nullable.toOption (get_element_by_id document id) with
  | Some el ->
      focus_el el [%mel.obj { preventScroll = true }];
      if n > 0 then
        set_timeout
          (fun () ->
            match Js.Nullable.toOption (active_element document) with
            | Some cur -> (
                match Js.Nullable.toOption (get_element_by_id document id) with
                | Some want when cur != want -> attempt_focus id (n - 1)
                | _ -> ())
            | None -> attempt_focus id (n - 1))
          16
  | None -> if n > 0 then set_timeout (fun () -> attempt_focus id (n - 1)) 16

let defer_focus id = set_timeout (fun () -> attempt_focus id 12) 0

let do_blur id =
  match Js.Nullable.toOption (get_element_by_id document id) with
  | Some el -> blur_el el
  | None -> (
      match Js.Nullable.toOption (active_element document) with
      | Some el when id = "" || element_id el = id -> blur_el el
      | _ -> ())

let do_scroll (msg : scroll_msg) =
  match Js.Nullable.toOption (get_element_by_id document "buffer-body") with
  | None -> ()
  | Some el ->
      if msg.action = "center" then
        let mid = max 0. ((scroll_height el -. client_height el) /. 2.) in
        scroll_to el [%mel.obj { top = mid; behavior = "auto" }]
      else
        let page = max 120. (floor (client_height el *. 0.9)) in
        let delta = if msg.dir >= 0 then page else -.page in
        scroll_by el [%mel.obj { top = delta; behavior = "auto" }]

let palette_is_open () =
  match Js.Nullable.toOption (query_selector document "#palette.open") with
  | Some _ -> true
  | None -> false

let is_shell_editable el =
  let tag = String.lowercase_ascii (tag_name el) in
  let id = element_id el in
  if id = "palette-input" then palette_is_open ()
  else if tag = "input" || tag = "textarea" then true
  else class_list_contains (class_list el) "terminal-input"

let shell_key key ctrl =
  if
    ctrl
    && (key = "f" || key = "F" || key = "b" || key = "B" || key = "["
      || key = "c")
  then true
  else
    match key with
    | "/" | ":" | "?" | "j" | "k" | "g" | "G" | "z" | "l" | "Enter"
    | "ArrowDown" | "ArrowUp" | "ArrowRight" | "Escape" | "Tab" ->
        true
    | _ -> false

let should_prevent ev =
  let key = event_key ev in
  let ctrl = event_ctrl ev in
  let meta = event_meta ev in
  if meta then false
  else
    match Js.Nullable.toOption (active_element document) with
    | Some el when element_id el = "palette-input" && not (palette_is_open ())
      ->
        blur_el el;
        shell_key key ctrl
    | Some el when is_shell_editable el ->
        if key = "Escape" || (ctrl && (key = "[" || key = "c")) then true
        else if element_id el = "palette-input" && palette_is_open () then
          key = "Enter" || key = "Tab" || key = "ArrowDown" || key = "ArrowUp"
          || key = "j" || key = "k"
        else false
    | _ -> shell_key key ctrl

let boot () =
  match Js.Nullable.toOption (get_element_by_id document "app") with
  | None -> console_error "missing #app"
  | Some node ->
      let is_mobile = (match_media window "(max-width: 860px)").matches in
      let app = elm.main.init { node; flags = { isMobile = is_mobile } } in
      app.ports.focus.subscribe (fun id -> defer_focus id);
      app.ports.blur.subscribe (fun id -> do_blur id);
      app.ports.scrollBuffer.subscribe (fun msg -> do_scroll msg);
      add_event_listener document "keydown"
        (fun ev -> if should_prevent ev then prevent_default ev)
        true

let () = boot ()
