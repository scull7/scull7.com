(* Tentative Google Calendar holds. Credentials fail closed when missing. *)

type hold_request = {
  calendar_id : string;
  summary : string;
  description : string;
  start_iso : string;
  end_iso : string;
}

type created = {
  event_id : string;
  calendar_id : string;
  html_link : string;
}

type t = {
  create_tentative : hold_request -> (created, string) result Js.Promise.t;
  delete_event :
    calendar_id:string ->
    event_id:string ->
    (unit, string) result Js.Promise.t;
}

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let capture () =
  let created = ref [] in
  ( {
      create_tentative =
        (fun req ->
          let event_id = "evt_" ^ Interview_crypto.random_id () in
          let rec_ =
            {
              event_id;
              calendar_id = req.calendar_id;
              html_link = "https://calendar.google.com/calendar/event?eid=" ^ event_id;
            }
          in
          created := (req, rec_) :: !created;
          return (Ok rec_));
      delete_event =
        (fun ~calendar_id:_ ~event_id ->
          created :=
            List.filter
              (fun (_, rec_) -> rec_.event_id <> event_id)
              !created;
          return (Ok ()));
    },
    created )

let form_encode pairs =
  pairs
  |> List.map (fun (k, v) ->
         Interview_crypto.encode_uri k ^ "=" ^ Interview_crypto.encode_uri v)
  |> String.concat "&"

let parse_access_token body =
  match Interview_json.parse_object body with
  | None -> None
  | Some dict -> Interview_json.opt_string_field dict "access_token"

let refresh_oauth (cfg : Interview_config.t) =
  match
    ( cfg.google_oauth_client_id,
      cfg.google_oauth_client_secret,
      cfg.google_oauth_refresh_token )
  with
  | Some id, Some secret, Some refresh ->
      let headers = Js.Dict.empty () in
      Js.Dict.set headers "Content-Type" "application/x-www-form-urlencoded";
      let body =
        form_encode
          [
            ("client_id", id);
            ("client_secret", secret);
            ("refresh_token", refresh);
            ("grant_type", "refresh_token");
          ]
      in
      Interview_http_fetch.post "https://oauth2.googleapis.com/token" ~headers
        ~body
      >>= fun res ->
      Interview_http_fetch.response_text res >>= fun text ->
      if not (Interview_http_fetch.response_ok res) then
        return (Error ("google_oauth " ^ text))
      else (
        match parse_access_token text with
        | Some tok -> return (Ok tok)
        | None -> return (Error "google_oauth: no access_token"))
  | _ -> return (Error "missing_env:GOOGLE_OAUTH_REFRESH_TOKEN")

let unescape_pem raw =
  raw
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\\\n/g"] ~replacement:"\n"
  |> String.trim

let service_account_jwt (cfg : Interview_config.t) =
  let email, pem =
    match cfg.google_service_account_json with
    | Some raw -> (
        match Interview_json.parse_object raw with
        | None -> (None, None)
        | Some dict ->
            ( Interview_json.opt_string_field dict "client_email",
              Interview_json.opt_string_field dict "private_key" ))
    | None -> (cfg.google_client_email, cfg.google_private_key)
  in
  match (email, pem) with
  | Some email, Some pem ->
      let now = int_of_float (Interview_crypto.now_ms () /. 1000.) in
      let header =
        Interview_json.json_stringify
          (Interview_json.obj
             [
               ("alg", Interview_json.str "RS256");
               ("typ", Interview_json.str "JWT");
             ])
      in
      let claim =
        Interview_json.json_stringify
          (Interview_json.obj
             [
               ("iss", Interview_json.str email);
               ( "scope",
                 Interview_json.str
                   "https://www.googleapis.com/auth/calendar.events" );
               ("aud", Interview_json.str "https://oauth2.googleapis.com/token");
               ("iat", Interview_json.num (float_of_int now));
               ("exp", Interview_json.num (float_of_int (now + 3600)));
             ])
      in
      let unsigned =
        Interview_crypto.b64url_of_string header
        ^ "."
        ^ Interview_crypto.b64url_of_string claim
      in
      let jwt =
        unsigned ^ "." ^ Interview_crypto.rsa_sign_b64url (unescape_pem pem) unsigned
      in
      let headers = Js.Dict.empty () in
      Js.Dict.set headers "Content-Type" "application/x-www-form-urlencoded";
      let body =
        form_encode
          [
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
            ("assertion", jwt);
          ]
      in
      Interview_http_fetch.post "https://oauth2.googleapis.com/token" ~headers
        ~body
      >>= fun res ->
      Interview_http_fetch.response_text res >>= fun text ->
      if not (Interview_http_fetch.response_ok res) then
        return (Error ("google_jwt " ^ text))
      else (
        match parse_access_token text with
        | Some tok -> return (Ok tok)
        | None -> return (Error "google_jwt: no access_token"))
  | _ -> return (Error "missing_env:GOOGLE_SERVICE_ACCOUNT_JSON")

let access_token cfg =
  if Interview_config.has_google_oauth cfg then refresh_oauth cfg
  else if Interview_config.has_google_service_account cfg then
    service_account_jwt cfg
  else
    return
      (Error
         "missing_env:GOOGLE_OAUTH_REFRESH_TOKEN (or GOOGLE_SERVICE_ACCOUNT_JSON)")

let delete_event_http token calendar_id event_id =
  let headers = Js.Dict.empty () in
  Js.Dict.set headers "Authorization" ("Bearer " ^ token);
  let cal = Interview_crypto.encode_uri calendar_id in
  let ev = Interview_crypto.encode_uri event_id in
  let url =
    "https://www.googleapis.com/calendar/v3/calendars/" ^ cal ^ "/events/" ^ ev
  in
  Interview_http_fetch.delete url ~headers >>= fun res ->
  Interview_http_fetch.response_text res >>= fun text ->
  if Interview_http_fetch.response_ok res then return (Ok ())
  else
    return
      (Error
         ("gcal delete "
         ^ string_of_int (Interview_http_fetch.response_status res)
         ^ ": " ^ text))

let create_event token (req : hold_request) =
  let headers = Js.Dict.empty () in
  Js.Dict.set headers "Authorization" ("Bearer " ^ token);
  Js.Dict.set headers "Content-Type" "application/json";
  let cal = Interview_crypto.encode_uri req.calendar_id in
  let url =
    "https://www.googleapis.com/calendar/v3/calendars/" ^ cal ^ "/events"
  in
  let body =
    Interview_json.json_stringify
      (Interview_json.obj
         [
           ("summary", Interview_json.str req.summary);
           ("description", Interview_json.str req.description);
           ("status", Interview_json.str "tentative");
           ( "start",
             Interview_json.obj
               [ ("dateTime", Interview_json.str req.start_iso) ] );
           ( "end",
             Interview_json.obj [ ("dateTime", Interview_json.str req.end_iso) ]
           );
         ])
  in
  Interview_http_fetch.post url ~headers ~body >>= fun res ->
  Interview_http_fetch.response_text res >>= fun text ->
  if not (Interview_http_fetch.response_ok res) then
    return (Error ("gcal " ^ text))
  else
    match Interview_json.parse_object text with
    | None -> return (Error "gcal: invalid create response")
    | Some dict ->
        return
          (Ok
             {
               event_id =
                 (match Interview_json.opt_string_field dict "id" with
                 | Some id -> id
                 | None -> "");
               calendar_id = req.calendar_id;
               html_link =
                 (match Interview_json.opt_string_field dict "htmlLink" with
                 | Some l -> l
                 | None -> "");
             })

let google cfg =
  {
    create_tentative =
      (fun req ->
        access_token cfg >>= function
        | Error e -> return (Error e)
        | Ok token -> create_event token req);
    delete_event =
      (fun ~calendar_id ~event_id ->
        access_token cfg >>= function
        | Error e -> return (Error e)
        | Ok token -> delete_event_http token calendar_id event_id);
  }

let of_config (cfg : Interview_config.t) =
  if
    Interview_config.has_google_oauth cfg
    || Interview_config.has_google_service_account cfg
  then google cfg
  else
    {
      create_tentative =
        (fun _ ->
          return
            (Error
               "missing_env:GOOGLE_OAUTH_REFRESH_TOKEN (or \
                GOOGLE_SERVICE_ACCOUNT_JSON)"));
      delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
    }
