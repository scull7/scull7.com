(* Isolated clock and id actions. Calculations stay out of this module. *)

type buffer
type date_obj

external date_now : unit -> float = "now" [@@mel.scope "Date"]
external new_date : float -> date_obj = "Date" [@@mel.new]
external to_iso : date_obj -> string = "toISOString" [@@mel.send]
external random_bytes : int -> buffer = "randomBytes" [@@mel.module "crypto"]
external buffer_to_string : buffer -> string -> string = "toString"
[@@mel.send]

let now_ms () = date_now ()
let iso_of_ms ms = to_iso (new_date ms)
let random_id () = buffer_to_string (random_bytes 16) "hex"
