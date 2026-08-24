(* Token and TTL calculations. HMAC sign/unsign, expiry, and magic-link
   URL assembly stay here so clock/mail actions do not invent policy. *)

type hmac
type buffer
type sign

external create_hmac : string -> string -> hmac = "createHmac"
[@@mel.module "crypto"]

external hmac_update : hmac -> string -> hmac = "update" [@@mel.send]
external hmac_digest : hmac -> string -> string = "digest" [@@mel.send]
external date_parse : string -> float = "parse" [@@mel.scope "Date"]
external encode_uri : string -> string = "encodeURIComponent"
external buffer_from : string -> string -> buffer = "from"
[@@mel.scope "Buffer"]
external buffer_to_string : buffer -> string -> string = "toString"
[@@mel.send]
external create_sign : string -> sign = "createSign" [@@mel.module "crypto"]
external sign_update : sign -> string -> sign = "update" [@@mel.send]
external sign_end : sign -> string -> string -> string = "sign" [@@mel.send]

let default_magic_link_ttl_ms = 86_400_000.
let default_book_token_ttl_ms = 1_800_000.

let hmac_hex secret message =
  let h = create_hmac "sha256" secret in
  hmac_digest (hmac_update h message) "hex"

let sign_token secret token = token ^ "." ^ hmac_hex secret token

let unsign_token secret signed =
  let trimmed = String.trim signed in
  match String.rindex_opt trimmed '.' with
  | None -> None
  | Some i ->
      let token = String.sub trimmed 0 i in
      let sig_ = String.sub trimmed (i + 1) (String.length trimmed - i - 1) in
      let expect = hmac_hex secret token in
      if sig_ = expect && token <> "" then Some token else None

let ms_of_iso raw =
  let n = date_parse raw in
  if n <> n then 0. else n

let expires_at_iso ~now_ms ~ttl_ms = Interview_clock.iso_of_ms (now_ms +. ttl_ms)

let is_expired ~now_ms iso = ms_of_iso iso <= now_ms

let magic_link ~site_url ~signed =
  site_url ^ "/interview/verify?token=" ^ encode_uri signed

let ban_link ~site_url ~kind ~signed =
  site_url ^ "/interview/ban?kind=" ^ encode_uri kind ^ "&token="
  ^ encode_uri signed

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
