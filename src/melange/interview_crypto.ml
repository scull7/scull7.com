(* Random ids, HMAC magic-link signatures, ISO clocks. *)

type hmac
type buffer
type sign

external create_hmac : string -> string -> hmac = "createHmac"
[@@mel.module "crypto"]

external hmac_update : hmac -> string -> hmac = "update" [@@mel.send]
external hmac_digest : hmac -> string -> string = "digest" [@@mel.send]
external random_bytes : int -> buffer = "randomBytes" [@@mel.module "crypto"]

external buffer_to_string : buffer -> string -> string = "toString"
[@@mel.send]

external buffer_from : string -> string -> buffer = "from"
[@@mel.scope "Buffer"]

external date_now : unit -> float = "now" [@@mel.scope "Date"]
external date_parse : string -> float = "parse" [@@mel.scope "Date"]

type date_obj

external new_date : float -> date_obj = "Date" [@@mel.new]
external to_iso : date_obj -> string = "toISOString" [@@mel.send]
external encode_uri : string -> string = "encodeURIComponent"
external create_sign : string -> sign = "createSign" [@@mel.module "crypto"]
external sign_update : sign -> string -> sign = "update" [@@mel.send]
external sign_end : sign -> string -> string -> string = "sign" [@@mel.send]

let now_ms () = date_now ()
let iso_of_ms ms = to_iso (new_date ms)

let ms_of_iso raw =
  let n = date_parse raw in
  if n <> n then 0. else n

let random_id () = buffer_to_string (random_bytes 16) "hex"

let hmac_hex secret message =
  let h = create_hmac "sha256" secret in
  hmac_digest (hmac_update h message) "hex"

let sign_token secret token = token ^ "." ^ hmac_hex secret token

let unsign_token secret signed =
  match String.rindex_opt signed '.' with
  | None -> None
  | Some i ->
      let token = String.sub signed 0 i in
      let sig_ = String.sub signed (i + 1) (String.length signed - i - 1) in
      let expect = hmac_hex secret token in
      if sig_ = expect && token <> "" then Some token else None

let add_ms iso delta = iso_of_ms (ms_of_iso iso +. delta)
let is_expired ~now iso = ms_of_iso iso <= now

let b64url_of_string s =
  buffer_to_string (buffer_from s "utf8") "base64"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\+/g"] ~replacement:"-"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\//g"] ~replacement:"_"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/=+$/g"] ~replacement:""

let rsa_sign_b64url pem data =
  let s = create_sign "RSA-SHA256" in
  ignore (sign_update s data);
  sign_end s pem "base64"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\+/g"] ~replacement:"-"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\//g"] ~replacement:"_"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/=+$/g"] ~replacement:""
