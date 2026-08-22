(* Shared fetch init so Melange emits `method` rather than `method_`. *)

type response

external fetch :
  string ->
  < method_ : string
  ; headers : string Js.Dict.t
  ; body : string >
  Js.t ->
  response Js.Promise.t = "fetch"

external fetch_init :
  method_:(string[@mel.as "method"]) ->
  headers:string Js.Dict.t ->
  body:string ->
  < method_ : string ; headers : string Js.Dict.t ; body : string > Js.t = ""
[@@mel.obj]

external response_ok : response -> bool = "ok" [@@mel.get]
external response_status : response -> int = "status" [@@mel.get]
external response_text : response -> string Js.Promise.t = "text" [@@mel.send]

let post url ~headers ~body =
  fetch url (fetch_init ~method_:"POST" ~headers ~body)

let get url ~headers =
  fetch url (fetch_init ~method_:"GET" ~headers ~body:"")

let delete url ~headers =
  fetch url (fetch_init ~method_:"DELETE" ~headers ~body:"")
