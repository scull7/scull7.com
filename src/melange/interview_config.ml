(* Interview-me T-16 through T-19 configuration. Free-email lists, Turso
   env, magic-link TTL, mail sender, required set, calendar, hold cap,
   and hold length are overridable without a code change.
   INTERVIEW_STORE is ignored. *)

type t = {
  site_url : string;
  free_email_blocklist : string list;
  email_allowlist : string list;
  turso_url : string option;
  turso_token : string option;
  mail_from : string;
  mail_to : string;
  magic_link_secret : string option;
  magic_link_ttl_ms : float;
  book_token_ttl_ms : float;
  resend_api_key : string option;
  required_questions_raw : string option;
  calendar_id : string;
  hold_cap : int;
  hold_default_seconds : int;
  cal_api_url : string option;
  cal_username : string option;
  cal_event_slug : string option;
}

type source = string -> string option

external process_env : string Js.Dict.t = "env" [@@mel.module "process"]

external netlify_env_get : string -> string Js.undefined = "get"
[@@mel.scope ("Netlify", "env")]

let netlify_source name =
  try
    match Js.Undefined.toOption (netlify_env_get name) with
    | Some v when String.trim v <> "" -> Some (String.trim v)
    | _ -> None
  with _ -> None

let process_source name =
  match Js.Dict.get process_env name with
  | Some v when String.trim v <> "" -> Some (String.trim v)
  | _ -> netlify_source name

let strip_wrap t =
  let n = String.length t in
  if
    n >= 2
    && ((t.[0] = '"' && t.[n - 1] = '"') || (t.[0] = '\'' && t.[n - 1] = '\''))
  then String.sub t 1 (n - 2)
  else t

let sanitize_secret raw =
  let t = strip_wrap (String.trim raw) in
  let t =
    if String.length t >= 7 && String.lowercase_ascii (String.sub t 0 7) = "bearer "
    then String.trim (String.sub t 7 (String.length t - 7))
    else t
  in
  t
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\s+/g"] ~replacement:""
  |> strip_wrap

let default_blocklist =
  [ "gmail"; "yahoo"; "hotmail"; "outlook.com"; "icloud" ]

let split_csv raw =
  raw |> String.split_on_char ',' |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let parse_float fallback raw =
  match raw with
  | None -> fallback
  | Some s -> ( try float_of_string (String.trim s) with _ -> fallback)

let of_source ?(source = process_source) () =
  {
    site_url =
      (match source "INTERVIEW_SITE_URL" with
      | Some u ->
          let s = String.trim u in
          if String.ends_with ~suffix:"/" s then
            String.sub s 0 (String.length s - 1)
          else s
      | None -> "https://scull7.com");
    free_email_blocklist =
      (match source "INTERVIEW_FREE_EMAIL_BLOCKLIST" with
      | Some raw -> split_csv raw
      | None -> default_blocklist);
    email_allowlist =
      (match source "INTERVIEW_EMAIL_ALLOWLIST" with
      | Some raw ->
          split_csv raw |> List.map String.lowercase_ascii
      | None -> []);
    turso_url = source "TURSO_DATABASE_URL";
    turso_token =
      (match source "TURSO_AUTH_TOKEN" with
      | Some v -> Some (sanitize_secret v)
      | None -> None);
    mail_from =
      (match source "INTERVIEW_MAIL_FROM" with
      | Some v -> String.trim v
      | None -> "nathan@vegasbuckeye.com");
    mail_to =
      (match source "INTERVIEW_MAIL_TO" with
      | Some v -> String.trim v
      | None -> "nathan@vegasbuckeye.com");
    magic_link_secret =
      (match source "INTERVIEW_MAGIC_LINK_SECRET" with
      | Some v -> Some (sanitize_secret v)
      | None -> None);
    magic_link_ttl_ms =
      parse_float 86_400_000. (source "INTERVIEW_MAGIC_LINK_TTL_MS");
    book_token_ttl_ms =
      parse_float 1_800_000. (source "INTERVIEW_BOOK_TOKEN_TTL_MS");
    resend_api_key =
      (match source "RESEND_API_KEY" with
      | Some v -> Some (sanitize_secret v)
      | None -> (
          match source "INTERVIEW_RESEND_API_KEY" with
          | Some v -> Some (sanitize_secret v)
          | None -> None));
    required_questions_raw = source "INTERVIEW_REQUIRED_QUESTIONS";
    calendar_id =
      (match source "INTERVIEW_CALENDAR_ID" with
      | Some id -> String.trim id
      | None -> "scull7.com");
    hold_cap = Interview_hold.parse_cap (source "INTERVIEW_HOLD_CAP");
    hold_default_seconds =
      Interview_hold.parse_seconds (source "INTERVIEW_HOLD_DEFAULT_SECONDS");
    cal_api_url =
      (match source "INTERVIEW_CAL_API_URL" with
      | Some v ->
          let s = String.trim v in
          Some
            (if String.ends_with ~suffix:"/" s then
               String.sub s 0 (String.length s - 1)
             else s)
      | None -> None);
    cal_username = source "INTERVIEW_CAL_USERNAME";
    cal_event_slug = source "INTERVIEW_CAL_EVENT_SLUG";
  }

let load () = of_source ()

let missing_store cfg =
  match (cfg.turso_url, cfg.turso_token) with
  | Some _, Some _ -> None
  | None, _ -> Some "TURSO_DATABASE_URL"
  | _, None -> Some "TURSO_AUTH_TOKEN"

let missing_magic_secret cfg =
  match cfg.magic_link_secret with
  | Some _ -> None
  | None -> Some "INTERVIEW_MAGIC_LINK_SECRET"

let missing_mail cfg =
  match cfg.resend_api_key with
  | Some _ -> None
  | None -> Some "RESEND_API_KEY"

let missing_calendar cfg =
  if cfg.cal_api_url = None then Some "INTERVIEW_CAL_API_URL"
  else if cfg.cal_username = None then Some "INTERVIEW_CAL_USERNAME"
  else if cfg.cal_event_slug = None then Some "INTERVIEW_CAL_EVENT_SLUG"
  else None

let required_ids cfg = Interview_required.parse cfg.required_questions_raw

let normalize_block item =
  let s = String.lowercase_ascii (String.trim item) in
  if s = "" then ""
  else if String.contains s '.' then s
  else s ^ ".com"

let email_domain email =
  let trimmed = String.lowercase_ascii (String.trim email) in
  match String.index_opt trimmed '@' with
  | None -> ""
  | Some i ->
      String.sub trimmed (i + 1) (String.length trimmed - i - 1) |> String.trim

let is_valid_email email =
  let trimmed = String.trim email in
  match String.index_opt trimmed '@' with
  | None -> false
  | Some i ->
      i > 0
      && i < String.length trimmed - 1
      && String.contains (email_domain trimmed) '.'

let is_allowlisted cfg email =
  let email_l = String.lowercase_ascii (String.trim email) in
  let domain = email_domain email_l in
  List.exists
    (fun allowed ->
      let a = String.lowercase_ascii (String.trim allowed) in
      if a = "" then false
      else if String.contains a '@' then a = email_l
      else
        let d = normalize_block a in
        domain = d || String.ends_with ~suffix:("." ^ d) domain)
    cfg.email_allowlist

let is_free_email cfg email =
  let domain = email_domain email in
  if domain = "" || is_allowlisted cfg email then false
  else
    List.exists
      (fun blocked ->
        let b = normalize_block blocked in
        domain = b || String.ends_with ~suffix:("." ^ b) domain)
      cfg.free_email_blocklist
