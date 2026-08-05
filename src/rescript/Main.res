// ReScript entry — boots Elm and wires ports (focus, blur, scroll, key preventDefault).

type scrollMsg = {
  action: string,
  dir: int,
}

type focusPort = {subscribe: (string => unit) => unit}
type blurPort = {subscribe: (string => unit) => unit}
type scrollPort = {subscribe: (scrollMsg => unit) => unit}
type ports = {
  focus: focusPort,
  blur: blurPort,
  scrollBuffer: scrollPort,
}
type elmApp = {ports: ports}

type flags = {isMobile: bool}
type initArgs = {
  node: Dom.element,
  flags: flags,
}
type mainNs = {init: initArgs => elmApp}
type elmRoot = {@as("Main") main: mainNs}

@module("../elm/Main.elm")
external elm: elmRoot = "Elm"

@val external document: Dom.document = "document"
@val external window: Dom.window = "window"

@send
external getElementById: (Dom.document, string) => Js.Nullable.t<Dom.element> = "getElementById"
@send external querySelector: (Dom.document, string) => Js.Nullable.t<Dom.element> = "querySelector"
@send external focusEl: (Dom.element, {"preventScroll": bool}) => unit = "focus"
@send external blurEl: Dom.element => unit = "blur"
@send
external scrollBy: (Dom.element, {"top": float, "behavior": string}) => unit = "scrollBy"
@send
external scrollTo: (Dom.element, {"top": float, "behavior": string}) => unit = "scrollTo"
@get external clientHeight: Dom.element => float = "clientHeight"
@get external scrollHeight: Dom.element => float = "scrollHeight"
@get external activeElement: Dom.document => Js.Nullable.t<Dom.element> = "activeElement"
@get external tagName: Dom.element => string = "tagName"
@get external elementId: Dom.element => string = "id"
@get external classList: Dom.element => {"contains": string => bool} = "classList"
@send
external addEventListener: (Dom.document, string, Dom.event_like<'a> => unit, bool) => unit =
  "addEventListener"
@send external preventDefault: Dom.event_like<'a> => unit = "preventDefault"
@get external eventKey: Dom.event_like<'a> => string = "key"
@get external eventCtrl: Dom.event_like<'a> => bool = "ctrlKey"
@get external eventMeta: Dom.event_like<'a> => bool = "metaKey"

type mediaQueryList = {matches: bool}
@send external matchMedia: (Dom.window, string) => mediaQueryList = "matchMedia"

let rec attemptFocus = (id: string, n: int) => {
  switch getElementById(document, id)->Js.Nullable.toOption {
  | Some(el) =>
    // Disabled inputs cannot take focus — skip until enabled (palette open).
    focusEl(el, {"preventScroll": true})
    if n > 0 {
      let _ = Js.Global.setTimeout(() => {
        switch activeElement(document)->Js.Nullable.toOption {
        | Some(cur) =>
          switch getElementById(document, id)->Js.Nullable.toOption {
          | Some(want) if cur !== want => attemptFocus(id, n - 1)
          | _ => ()
          }
        | None => attemptFocus(id, n - 1)
        }
      }, 16)
    }
  | None =>
    if n > 0 {
      let _ = Js.Global.setTimeout(() => attemptFocus(id, n - 1), 16)
    }
  }
}

let deferFocus = (id: string) => {
  let _ = Js.Global.setTimeout(() => attemptFocus(id, 12), 0)
}

let doBlur = (id: string) => {
  switch getElementById(document, id)->Js.Nullable.toOption {
  | Some(el) => blurEl(el)
  | None =>
    switch activeElement(document)->Js.Nullable.toOption {
    | Some(el) if id == "" || elementId(el) == id => blurEl(el)
    | _ => ()
    }
  }
}

let doScroll = (msg: scrollMsg) => {
  switch getElementById(document, "buffer-body")->Js.Nullable.toOption {
  | None => ()
  | Some(el) =>
    if msg.action == "center" {
      let mid = Js.Math.max_float(0., (scrollHeight(el) -. clientHeight(el)) /. 2.)
      scrollTo(el, {"top": mid, "behavior": "auto"})
    } else {
      let page = Js.Math.max_float(120., Js.Math.floor_float(clientHeight(el) *. 0.9))
      let delta = if msg.dir >= 0 {
        page
      } else {
        -.page
      }
      scrollBy(el, {"top": delta, "behavior": "auto"})
    }
  }
}

let paletteIsOpen = () => {
  switch querySelector(document, "#palette.open")->Js.Nullable.toOption {
  | Some(_) => true
  | None => false
  }
}

let isShellEditable = (el: Dom.element) => {
  let tag = tagName(el)->Js.String2.toLowerCase
  let id = elementId(el)
  // Palette input only counts as editable while the palette is open.
  if id == "palette-input" {
    paletteIsOpen()
  } else if tag == "input" || tag == "textarea" {
    true
  } else {
    classList(el)["contains"]("terminal-input")
  }
}

let shellKey = (key: string, ctrl: bool) => {
  if ctrl && (key == "f" || key == "F" || key == "b" || key == "B" || key == "[" || key == "c") {
    true
  } else {
    switch key {
    | "/"
    | ":"
    | "?"
    | "j"
    | "k"
    | "g"
    | "G"
    | "z"
    | "l"
    | "Enter"
    | "ArrowDown"
    | "ArrowUp"
    | "ArrowRight"
    | "Escape"
    | "Tab" => true
    | _ => false
    }
  }
}

let shouldPrevent = (ev: Dom.event_like<'a>) => {
  let key = eventKey(ev)
  let ctrl = eventCtrl(ev)
  let meta = eventMeta(ev)
  if meta {
    false
  } else {
    // If focus is stuck on a closed palette input, kick it out.
    switch activeElement(document)->Js.Nullable.toOption {
    | Some(el)
      if elementId(el) == "palette-input" && !paletteIsOpen() => {
        blurEl(el)
        shellKey(key, ctrl)
      }
    | Some(el) if isShellEditable(el) =>
      // While typing in palette/terminal, still let Esc be handled cleanly.
      if key == "Escape" || (ctrl && (key == "[" || key == "c")) {
        true
      } else if elementId(el) == "palette-input" && paletteIsOpen() {
        // Palette chrome keys
        key == "Enter" ||
        key == "Tab" ||
        key == "ArrowDown" ||
        key == "ArrowUp" ||
        key == "j" ||
        key == "k"
      } else {
        false
      }
    | _ => shellKey(key, ctrl)
    }
  }
}

let boot = () => {
  switch getElementById(document, "app")->Js.Nullable.toOption {
  | None => Js.Console.error("missing #app")
  | Some(node) => {
      let isMobile = matchMedia(window, "(max-width: 860px)").matches
      let app = elm.main.init({
        node,
        flags: {isMobile: isMobile},
      })
      app.ports.focus.subscribe(id => deferFocus(id))
      app.ports.blur.subscribe(id => doBlur(id))
      app.ports.scrollBuffer.subscribe(msg => doScroll(msg))
      addEventListener(document, "keydown", ev =>
        if shouldPrevent(ev) {
          preventDefault(ev)
        }
      , true)
    }
  }
}

boot()
