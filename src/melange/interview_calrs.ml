(* Production booking backend: calrs (https://cal.rs) on nate-cal-1, reached
   through its public booking form. calrs ships no REST API, so this module
   speaks the same HTTP the browser does.

   Three properties of that surface drive the code below:
   - CSRF is a double-submit check. calrs only compares the `_csrf` field to
     the `__Host-calrs_csrf` cookie it received, with no server-side session,
     so one generated value in both places is what a non-browser client sends.
   - calrs answers 200 even when it refuses. Success is therefore defined only
     by a cancel token in the body, never by the status code.
   - The template HTML-escapes interpolated URLs, so `/booking/ics/<token>`
     arrives as `&#x2f;booking&#x2f;ics&#x2f;<token>`. Missing that would read
     every real booking as a failure and strand it on Nathan's calendar.

   Everything except `post` is a calculation. *)

type http_post =
  string ->
  headers:string Js.Dict.t ->
  body:string ->
  Interview_http_fetch.response Js.Promise.t

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

(* --- calculations --- *)

let is_utc_iso raw =
  String.length raw >= 17
  && raw.[10] = 'T'
  && raw.[13] = ':'
  && String.ends_with ~suffix:"Z" raw

let date_of_iso raw = if is_utc_iso raw then Some (String.sub raw 0 10) else None
let time_of_iso raw = if is_utc_iso raw then Some (String.sub raw 11 5) else None

let form_encode fields =
  fields
  |> List.map (fun (k, v) ->
         Interview_token.encode_uri k ^ "=" ^ Interview_token.encode_uri v)
  |> String.concat "&"

(* The booking page renders interpolated URLs escaped; put the slashes back
   before looking for a link. *)
let unescape_slashes body =
  body
  |> Js.String.replaceByRe ~regexp:[%mel.re "/&#x2f;|&#x2F;|&#47;/g"]
       ~replacement:"/"

let is_token_char c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9')
  || c = '-' || c = '_'

let cancel_token_of_html body =
  let body = unescape_slashes body in
  let needle = "/booking/ics/" in
  let n = String.length needle in
  let len = String.length body in
  let rec read_token i =
    if i < len && is_token_char body.[i] then read_token (i + 1) else i
  in
  let rec search i =
    if i + n > len then None
    else if String.sub body i n = needle then
      let start = i + n in
      let stop = read_token start in
      if stop > start then Some (String.sub body start (stop - start))
      else search (i + 1)
    else search (i + 1)
  in
  search 0

(* Never returns a success. A body that reached here did not carry a cancel
   token, so the booking is either refused or unusable to us. *)
let classify_failure body =
  let b = String.lowercase_ascii body in
  let contains s = Js.String.includes ~search:s b in
  if contains "pending confirmation" || contains "booking pending" then
    "invalid:calrs accepted the booking as pending, which leaves no cancel \
     handle. Turn requires-confirmation off for INTERVIEW_CAL_EVENT_SLUG; the \
     pending booking must be removed from the calrs dashboard by hand"
  else if
    contains "no longer available"
    || contains "beyond the booking window"
    || contains "not available right now"
  then
    let reason =
      if contains "no longer available" then "no longer available"
      else if contains "beyond the booking window" then
        "beyond the booking window"
      else "host not available right now"
    in
    "slot_unavailable:" ^ reason
  else if contains "event type not found" || contains "requires an invite link"
  then
    "invalid:calrs event type is not bookable (check INTERVIEW_CAL_USERNAME / \
     INTERVIEW_CAL_EVENT_SLUG)"
  else if
    contains "invalid date." || contains "invalid time."
    || contains "invalid booking details"
  then "invalid:calrs rejected the requested time"
  else if contains "too many booking attempts" then
    "invalid:calrs rate limited this booking"
  else if contains "csrf token mismatch" then
    "invalid:calrs rejected the CSRF token"
  else "invalid:calrs did not confirm the booking"

let book_path ~username ~slug = "/u/" ^ username ^ "/" ^ slug ^ "/book"
let cancel_path ~event_id = "/booking/cancel/" ^ event_id

let book_body ~csrf ~date ~time (req : Interview_calendar.request) =
  form_encode
    [
      ("_csrf", csrf);
      ("date", date);
      ("time", time);
      ("tz", "UTC");
      ("name", req.guest_name);
      ("email", req.guest_email);
      ("notes", req.description);
    ]

let cancel_body ~csrf =
  form_encode
    [ ("_csrf", csrf); ("reason", "Interview hold released by scull7.com") ]

(* --- action --- *)

let csrf_headers csrf =
  let headers = Js.Dict.empty () in
  Js.Dict.set headers "Content-Type" "application/x-www-form-urlencoded";
  Js.Dict.set headers "Cookie" ("__Host-calrs_csrf=" ^ csrf);
  headers

let port ?(post = Interview_http_fetch.post) ~base ~username ~slug () :
    Interview_calendar.t =
  {
    create_tentative =
      (fun (req : Interview_calendar.request) ->
        match (date_of_iso req.start_iso, time_of_iso req.start_iso) with
        | None, _ | _, None ->
            return (Error "invalid:start must be UTC ISO-8601 ending in Z")
        | Some date, Some time ->
            let csrf = Interview_clock.random_id () in
            post
              (base ^ book_path ~username ~slug)
              ~headers:(csrf_headers csrf)
              ~body:(book_body ~csrf ~date ~time req)
            >>= fun resp ->
            Interview_http_fetch.response_text resp >>= fun text ->
            return
              (match
                 (Interview_http_fetch.response_ok resp, cancel_token_of_html text)
               with
              | true, Some token ->
                  Ok
                    {
                      Interview_calendar.calendar_id = req.calendar_id;
                      event_id = token;
                      html_link = base ^ "/booking/ics/" ^ token;
                      start_iso = req.start_iso;
                      end_iso = req.end_iso;
                    }
              | _ -> Error (classify_failure text)));
    delete_event =
      (fun ~calendar_id:_ ~event_id ->
        let csrf = Interview_clock.random_id () in
        post
          (base ^ cancel_path ~event_id)
          ~headers:(csrf_headers csrf) ~body:(cancel_body ~csrf)
        >>= fun resp ->
        if Interview_http_fetch.response_ok resp then return (Ok ())
        else return (Error "invalid:calrs could not cancel the booking"));
  }

(* Composition root for the calendar port: the real backend when every
   booking env is present, fail-closed missing_env otherwise. *)
let of_config ?post (cfg : Interview_config.t) : Interview_calendar.t =
  match
    (Interview_config.missing_calendar cfg, cfg.cal_api_url, cfg.cal_username,
     cfg.cal_event_slug)
  with
  | Some name, _, _, _ ->
      {
        create_tentative = (fun _ -> return (Error ("missing_env:" ^ name)));
        delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
      }
  | None, Some base, Some username, Some slug ->
      port ?post ~base ~username ~slug ()
  | None, _, _, _ ->
      {
        create_tentative =
          (fun _ -> return (Error "missing_env:INTERVIEW_CAL_API_URL"));
        delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
      }
