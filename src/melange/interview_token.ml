(* Token and TTL calculations. HMAC sign/unsign, expiry, and magic-link
   URL assembly stay here so clock/mail actions do not invent policy. *)

type hmac
type buffer

external create_hmac : string -> string -> hmac = "createHmac"
[@@mel.module "crypto"]

external hmac_update : hmac -> string -> hmac = "update" [@@mel.send]
external hmac_digest : hmac -> string -> string = "digest" [@@mel.send]
external date_parse : string -> float = "parse" [@@mel.scope "Date"]
external encode_uri : string -> string = "encodeURIComponent"

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
