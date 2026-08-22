(* Interview-me configuration. Defaults are locked; every list/cap/id is
   overridable via env. Required secrets fail closed (None) so callers can
   refuse the operation instead of guessing. *)

type required_item = {
  id : string;
  kind : string;
  pattern : string;
  label : string;
}

type t = {
  site_url : string;
  hold_cap : int;
  hold_default_seconds : int;
  calendar_id : string;
  free_email_blocklist : string list;
  email_allowlist : string list;
  required : required_item list;
  mail_from : string;
  mail_to : string;
  magic_link_secret : string option;
  book_token_ttl_ms : float;
  magic_link_ttl_ms : float;
  turso_url : string option;
  turso_token : string option;
  resend_api_key : string option;
  google_oauth_client_id : string option;
  google_oauth_client_secret : string option;
  google_oauth_refresh_token : string option;
  google_service_account_json : string option;
  google_client_email : string option;
  google_private_key : string option;
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

let default_blocklist =
  [ "gmail"; "yahoo"; "hotmail"; "outlook.com"; "icloud" ]

let default_required : required_item list =
  [
    {
      id = "current_work";
      kind = "cited";
      pattern = "tensorwave|relay";
      label = "Cited answer on current work (TensorWave / Relay)";
    };
    {
      id = "leadership";
      kind = "cited";
      pattern = "leadership|leader|scale|org|managed|engineers|director|vp";
      label = "Cited answer on leadership scale";
    };
    {
      id = "systems";
      kind = "cited";
      pattern = "rust|distributed|systems|relay|control plane";
      label = "Cited answer on systems depth (Rust / distributed systems)";
    };
    {
      id = "wants_next";
      kind = "cited";
      pattern = "want next|wants next|looking for|seeking|next role|open to";
      label = "Cited answer on what Nathan wants next";
    };
    {
      id = "hiring_timeline";
      kind = "recruiter";
      pattern =
        "hiring timeline|timeline|need someone|start date|start by|we need|our timeline";
      label = "Hiring timeline, stated by the recruiter";
    };
  ]

let split_csv raw =
  raw |> String.split_on_char ',' |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let find_default id =
  List.find_opt (fun (item : required_item) -> item.id = id) default_required

let required_of_json text =
  try
    Interview_json.as_array (Interview_json.json_parse text)
    |> Array.to_list
    |> List.filter_map (fun json ->
           match Interview_json.as_object json with
           | None -> None
           | Some dict ->
               let id = Interview_json.string_field dict "id" |> String.trim in
               if id = "" then None
               else
                 let fallback = find_default id in
                 Some
                   {
                     id;
                     kind =
                       (match Interview_json.opt_string_field dict "kind" with
                       | Some k -> k
                       | None -> (
                           match fallback with
                           | Some item -> item.kind
                           | None -> "cited"));
                     pattern =
                       (match
                          Interview_json.opt_string_field dict "pattern"
                        with
                       | Some p -> p
                       | None -> (
                           match
                             Interview_json.opt_string_field dict "match"
                           with
                           | Some p -> p
                           | None -> (
                               match fallback with
                               | Some item -> item.pattern
                               | None -> id)));
                     label =
                       (match Interview_json.opt_string_field dict "label" with
                       | Some l -> l
                       | None -> (
                           match fallback with
                           | Some item -> item.label
                           | None -> id));
                   })
  with _ -> []

let parse_required = function
  | None -> default_required
  | Some raw ->
      let trimmed = String.trim raw in
      if trimmed = "" then default_required
      else if String.starts_with ~prefix:"[" trimmed then
        match required_of_json trimmed with
        | [] -> default_required
        | items -> items
      else
        let ids = split_csv trimmed in
        let items = List.filter_map find_default ids in
        if items = [] then default_required else items

let parse_int fallback raw =
  match raw with
  | None -> fallback
  | Some s -> ( try int_of_string (String.trim s) with _ -> fallback)

let parse_float fallback raw =
  match raw with
  | None -> fallback
  | Some s -> ( try float_of_string (String.trim s) with _ -> fallback)

let of_source ?(source = process_source) () =
  let hold_cap = max 1 (parse_int 3 (source "INTERVIEW_HOLD_CAP")) in
  {
    site_url =
      (match source "INTERVIEW_SITE_URL" with
      | Some u -> String.trim u |> fun s ->
          if String.ends_with ~suffix:"/" s then
            String.sub s 0 (String.length s - 1)
          else s
      | None -> "https://scull7.com");
    hold_cap;
    hold_default_seconds =
      max 60 (parse_int 3600 (source "INTERVIEW_HOLD_DEFAULT_SECONDS"));
    calendar_id =
      (match source "INTERVIEW_CALENDAR_ID" with
      | Some id -> id
      | None -> "scull7.com");
    free_email_blocklist =
      (match source "INTERVIEW_FREE_EMAIL_BLOCKLIST" with
      | Some raw -> split_csv raw
      | None -> default_blocklist);
    email_allowlist =
      (match source "INTERVIEW_EMAIL_ALLOWLIST" with
      | Some raw ->
          split_csv raw |> List.map String.lowercase_ascii
      | None -> []);
    required = parse_required (source "INTERVIEW_REQUIRED_QUESTIONS");
    mail_from =
      (match source "INTERVIEW_MAIL_FROM" with
      | Some v -> v
      | None -> "nathan@vegasbuckeye.com");
    mail_to =
      (match source "INTERVIEW_MAIL_TO" with
      | Some v -> v
      | None -> "nathan@vegasbuckeye.com");
    magic_link_secret = source "INTERVIEW_MAGIC_LINK_SECRET";
    book_token_ttl_ms =
      parse_float 1800000. (source "INTERVIEW_BOOK_TOKEN_TTL_MS");
    magic_link_ttl_ms =
      parse_float 86400000. (source "INTERVIEW_MAGIC_LINK_TTL_MS");
    turso_url = source "TURSO_DATABASE_URL";
    turso_token = source "TURSO_AUTH_TOKEN";
    resend_api_key =
      (match source "RESEND_API_KEY" with
      | Some v -> Some v
      | None -> source "INTERVIEW_RESEND_API_KEY");
    google_oauth_client_id =
      (match source "GOOGLE_OAUTH_CLIENT_ID" with
      | Some v -> Some v
      | None -> source "GOOGLE_CLIENT_ID");
    google_oauth_client_secret =
      (match source "GOOGLE_OAUTH_CLIENT_SECRET" with
      | Some v -> Some v
      | None -> source "GOOGLE_CLIENT_SECRET");
    google_oauth_refresh_token =
      (match source "GOOGLE_OAUTH_REFRESH_TOKEN" with
      | Some v -> Some v
      | None -> source "GOOGLE_REFRESH_TOKEN");
    google_service_account_json = source "GOOGLE_SERVICE_ACCOUNT_JSON";
    google_client_email = source "GOOGLE_CLIENT_EMAIL";
    google_private_key = source "GOOGLE_PRIVATE_KEY";
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

let has_google_oauth cfg =
  match
    ( cfg.google_oauth_client_id,
      cfg.google_oauth_client_secret,
      cfg.google_oauth_refresh_token )
  with
  | Some _, Some _, Some _ -> true
  | _ -> false

let has_google_service_account cfg =
  match cfg.google_service_account_json with
  | Some _ -> true
  | None -> (
      match (cfg.google_client_email, cfg.google_private_key) with
      | Some _, Some _ -> true
      | _ -> false)

let missing_calendar cfg =
  if has_google_oauth cfg || has_google_service_account cfg then None
  else Some "GOOGLE_OAUTH_REFRESH_TOKEN"

let missing_mail cfg =
  if Option.is_some cfg.resend_api_key || has_google_oauth cfg then None
  else Some "RESEND_API_KEY"

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

let is_allowlisted cfg domain =
  List.exists
    (fun allowed ->
      let a = normalize_block allowed in
      domain = a || String.ends_with ~suffix:("." ^ a) domain)
    cfg.email_allowlist

let is_free_email cfg email =
  let domain = email_domain email in
  if domain = "" || is_allowlisted cfg domain then false
  else
    List.exists
      (fun blocked ->
        let b = normalize_block blocked in
        domain = b || String.ends_with ~suffix:("." ^ b) domain)
      cfg.free_email_blocklist
