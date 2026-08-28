(* Named session + cited ask + required-set progress + human magic-link
   verify + book-token create_hold. Cap/ban/refuse are calculations;
   calendar port, Resend HTTP, and webhook POST are isolated actions. *)

type error =
  | Missing_env of string
  | Invalid of string
  | Slot_unavailable of string
  | Free_email of string
  | Banned of string
  | Not_found
  | Token_invalid of string
  | Required_incomplete of string list
  | Hold_cap of int

type start_input = {
  company : string;
  role : string;
  recruiter_name : string;
  work_email : string;
  callback_url : string option;
}

type ask_output = {
  session_id : string;
  company : string;
  role : string;
  recruiter_name : string;
  work_email : string;
  callback_url : string option;
  answer : string;
  cited : bool;
  citation : Interview_corpus.citation option;
  refused : bool;
  required_progress : string list;
  required_remaining : string list;
}

type verify_request_output = { session_id : string }

type verify_output = {
  session_id : string;
  book_token : string;
  expires_at : string;
}

type hold_output = {
  hold_id : string;
  session_id : string;
  start : string;
  end_ : string;
  calendar_id : string;
  calendar_event_id : string;
  html_link : string;
}

type deps = {
  now_ms : unit -> float;
  random_id : unit -> string;
  cfg : Interview_config.t;
  store : Interview_store.t;
  corpus : Interview_corpus.t;
  mail : Interview_mail.t;
  calendar : Interview_calendar.t;
  webhook : Interview_webhook.t;
}

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x
let ok x = return (Ok x)
let err e = return (Error e)

external js_message : 'a -> string Js.undefined = "message" [@@mel.get]
external js_payload : 'a -> string Js.undefined = "_1" [@@mel.get]
external js_cause : 'a -> 'a Js.undefined = "cause" [@@mel.get]

let useful = function
  | Some s when String.trim s <> "" && s <> "Failure" && s <> "Error" ->
      Some (String.trim s)
  | _ -> None

let rec peek_exn err depth =
  if depth > 3 then None
  else
    match useful (Js.Undefined.toOption (js_payload err)) with
    | Some s -> Some s
    | None -> (
        match useful (Js.Undefined.toOption (js_message err)) with
        | Some s -> Some s
        | None -> (
            match Js.Undefined.toOption (js_cause err) with
            | Some c -> peek_exn c (depth + 1)
            | None -> None))

let exn_message err =
  match peek_exn err 0 with Some s -> s | None -> "store failed"

let missing_env_name msg =
  let prefix = "missing_env:" in
  if String.starts_with ~prefix msg then
    Some (String.sub msg (String.length prefix) (String.length msg - String.length prefix))
  else if Js.String.includes ~search:"TURSO_DATABASE_URL" msg then
    Some "TURSO_DATABASE_URL"
  else if Js.String.includes ~search:"TURSO_AUTH_TOKEN" msg then
    Some "TURSO_AUTH_TOKEN"
  else None

let catch_store p =
  p
  |> Js.Promise.catch (fun e ->
         let msg = exn_message e in
         match missing_env_name msg with
         | Some name -> err (Missing_env name)
         | None -> err (Invalid msg))

let start (deps : deps) (input : start_input) =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None ->
      let company = String.trim input.company in
      let role = String.trim input.role in
      let recruiter = String.trim input.recruiter_name in
      let email = String.trim input.work_email |> String.lowercase_ascii in
      if
        company = "" || role = "" || recruiter = ""
        || String.trim input.work_email = ""
      then err (Invalid "company, role, recruiter_name, and work_email are required")
      else if not (Interview_config.is_valid_email email) then
        err (Invalid "work_email must be a valid email")
      else if Interview_config.is_free_email deps.cfg email then
        err (Free_email (Interview_config.email_domain email))
      else
        let domain = Interview_config.email_domain email in
        let now = Interview_clock.iso_of_ms (deps.now_ms ()) in
        catch_store
          (deps.store.is_banned "address" email >>= fun addr_ban ->
           deps.store.is_banned "domain" domain >>= fun domain_ban ->
           if addr_ban then err (Banned email)
           else if domain_ban then err (Banned domain)
           else
             let session : Interview_store.session =
               {
                 id = "ses_" ^ deps.random_id ();
                 company;
                 role;
                 recruiter_name = recruiter;
                 work_email = email;
                 work_domain = domain;
                 callback_url =
                   (match input.callback_url with
                   | Some u when String.trim u <> "" -> Some (String.trim u)
                   | _ -> None);
                 hiring_timeline = None;
                 completed = [];
                 verified = false;
                 created_at = now;
               }
             in
             deps.store.put_session session >>= fun () -> ok session)

let ask_fields (session : Interview_store.session) ~answer ~cited ~citation
    ~refused (snap : Interview_required.snapshot) : ask_output =
  {
    session_id = session.id;
    company = session.company;
    role = session.role;
    recruiter_name = session.recruiter_name;
    work_email = session.work_email;
    callback_url = session.callback_url;
    answer;
    cited;
    citation;
    refused;
    required_progress = snap.required_progress;
    required_remaining = snap.required_remaining;
  }

let persist_progress (session : Interview_store.session)
    (snap : Interview_required.snapshot) =
  {
    session with
    completed = snap.progress.completed;
    hiring_timeline = snap.progress.hiring_timeline;
  }

let fire_completed deps (session : Interview_store.session)
    (snap : Interview_required.snapshot) =
  match session.callback_url with
  | None -> return ()
  | Some url ->
      let body =
        Interview_json.json_stringify
          (Interview_webhook.interview_completed_body ~session
             ~required_progress:snap.required_progress
             ~required_remaining:snap.required_remaining)
      in
      deps.webhook.post url body
      >>= (function Ok () | Error _ -> return ())
      |> Js.Promise.catch (fun _ -> return ())

let ask (deps : deps) ~session_id ~question =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None ->
      let q = String.trim question in
      if q = "" then err (Invalid "question is required")
      else
        catch_store
          (deps.store.get_session session_id >>= function
          | None -> err Not_found
          | Some session ->
              let required = Interview_config.required_ids deps.cfg in
              let before =
                Interview_required.snapshot required
                  {
                    completed = session.completed;
                    hiring_timeline = session.hiring_timeline;
                  }
              in
              let classified =
                Interview_required.classify ~progress:before.progress
                  ~question:q
              in
              let hit = Interview_corpus.ask deps.corpus q in
              let answer, cited, citation, refused, after =
                match classified with
                | Interview_required.Record_timeline words ->
                    let snap =
                      Interview_required.apply ~required
                        ~progress:before.progress classified
                    in
                    ( Interview_required.timeline_record_answer words,
                      false,
                      None,
                      false,
                      snap )
                | Interview_required.Echo_timeline words ->
                    ( Interview_required.timeline_echo_answer words,
                      false,
                      None,
                      false,
                      Interview_required.apply ~required
                        ~progress:before.progress classified )
                | Interview_required.Refuse_timeline ->
                    ( Interview_corpus.refuse_text,
                      false,
                      None,
                      true,
                      before )
                | Interview_required.Ask_corpus -> (
                    match hit.kind with
                    | Interview_corpus.Refuse ->
                        (hit.answer, false, None, true, before)
                    | Interview_corpus.Cited c ->
                        let snap =
                          Interview_required.apply_cited ~required
                            ~progress:before.progress ~question:q
                        in
                        (hit.answer, true, Some c, false, snap))
              in
              let session = persist_progress session after in
              deps.store.put_session session >>= fun () ->
              (if Interview_required.just_completed ~before ~after then
                 fire_completed deps session after
               else return ())
              >>= fun () ->
              ok
                (ask_fields session ~answer ~cited ~citation ~refused after))

let escape_html s =
  s
  |> Js.String.replaceByRe ~regexp:[%mel.re "/&/g"] ~replacement:"&amp;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/</g"] ~replacement:"&lt;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/>/g"] ~replacement:"&gt;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\"/g"] ~replacement:"&quot;"

let request_verification (deps : deps) ~session_id =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None -> (
      match Interview_config.missing_magic_secret deps.cfg with
      | Some name -> err (Missing_env name)
      | None -> (
          match Interview_config.missing_mail deps.cfg with
          | Some name -> err (Missing_env name)
          | None ->
              catch_store
                (deps.store.get_session session_id >>= function
                | None -> err Not_found
                | Some session -> (
                    match deps.cfg.magic_link_secret with
                    | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
                    | Some secret ->
                        let now = deps.now_ms () in
                        let raw = deps.random_id () in
                        let expires_at =
                          Interview_token.expires_at_iso ~now_ms:now
                            ~ttl_ms:deps.cfg.magic_link_ttl_ms
                        in
                        let tok : Interview_store.token =
                          {
                            token = raw;
                            kind = "magic";
                            session_id = session.id;
                            expires_at;
                            consumed = false;
                            created_at = Interview_clock.iso_of_ms now;
                          }
                        in
                        let signed = Interview_token.sign_token secret raw in
                        let link =
                          Interview_token.magic_link ~site_url:deps.cfg.site_url
                            ~signed
                        in
                        let subject =
                          "Verify your work email for interview-me"
                        in
                        let text =
                          "Click to verify your work email for the \
                           interview-me session with Nathan Sculli:\n\n" ^ link
                          ^ "\n\nThe agent never needs your inbox. After you \
                             click, you will see a short-lived book token to \
                             give the agent.\n\nContact: \
                             nathan@vegasbuckeye.com"
                        in
                        let html =
                          "<p>Click to verify your work email for the \
                           interview-me session with Nathan Sculli.</p><p><a \
                           href=\"" ^ escape_html link
                          ^ "\">Verify work email</a></p><p>The agent never \
                             needs your inbox. After you click, you will see \
                             a short-lived book token to give the agent.</p>\
                             <p>Contact: nathan@vegasbuckeye.com</p>"
                        in
                        deps.mail.send
                          {
                            to_ = session.work_email;
                            from_ = deps.cfg.mail_from;
                            subject;
                            text;
                            html;
                          }
                        >>= function
                        | Error msg ->
                            if String.starts_with ~prefix:"missing_env:" msg then
                              err
                                (Missing_env
                                   (String.sub msg 12 (String.length msg - 12)))
                            else err (Invalid msg)
                        | Ok _ ->
                            deps.store.put_token tok >>= fun () ->
                            ok { session_id = session.id }))))

let verify (deps : deps) ~signed =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None -> (
      let signed = String.trim signed in
      if signed = "" then err (Token_invalid "empty token")
      else
        match deps.cfg.magic_link_secret with
        | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
        | Some secret -> (
            match Interview_token.unsign_token secret signed with
            | None -> err (Token_invalid "bad signature")
            | Some raw ->
                catch_store
                  (deps.store.get_token raw >>= function
                  | None -> err (Token_invalid "unknown token")
                  | Some tok ->
                      let now = deps.now_ms () in
                      if tok.kind <> "magic" then
                        err (Token_invalid "wrong kind")
                      else if tok.consumed then
                        err (Token_invalid "already used")
                      else if Interview_token.is_expired ~now_ms:now tok.expires_at
                      then err (Token_invalid "expired")
                      else
                        deps.store.get_session tok.session_id >>= function
                        | None -> err Not_found
                        | Some session ->
                            deps.store.consume_token raw >>= fun () ->
                            let book_raw = deps.random_id () in
                            let expires_at =
                              Interview_token.expires_at_iso ~now_ms:now
                                ~ttl_ms:deps.cfg.book_token_ttl_ms
                            in
                            let book : Interview_store.token =
                              {
                                token = book_raw;
                                kind = "book";
                                session_id = session.id;
                                expires_at;
                                consumed = false;
                                created_at = Interview_clock.iso_of_ms now;
                              }
                            in
                            deps.store.put_token book >>= fun () ->
                            deps.store.put_session
                              { session with verified = true }
                            >>= fun () ->
                            ok
                              {
                                session_id = session.id;
                                book_token =
                                  Interview_token.sign_token secret book_raw;
                                expires_at;
                              })))

let lookup_book (deps : deps) signed =
  let signed = String.trim signed in
  if signed = "" then err (Token_invalid "empty token")
  else
    match deps.cfg.magic_link_secret with
    | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
    | Some secret -> (
        match Interview_token.unsign_token secret signed with
        | None -> err (Token_invalid "bad signature")
        | Some raw ->
            catch_store
              (deps.store.get_token raw >>= function
              | None -> err (Token_invalid "unknown token")
              | Some tok ->
                  let now = deps.now_ms () in
                  if tok.kind <> "book" then
                    err (Token_invalid "not a book token")
                  else if tok.consumed then
                    err (Token_invalid "already used")
                  else if Interview_token.is_expired ~now_ms:now tok.expires_at
                  then err (Token_invalid "expired")
                  else
                    deps.store.get_session tok.session_id >>= function
                    | None -> err (Token_invalid "unknown session")
                    | Some session -> ok (tok, session)))

let hold_notification (deps : deps) (session : Interview_store.session)
    (hold : Interview_store.hold) ban_address_url ban_domain_url =
  let subject =
    "Interview-me hold: " ^ session.company ^ " / " ^ session.role
  in
  let text =
    String.concat "\n"
      [
        "A recruiter agent created a tentative calendar hold.";
        "";
        "Company: " ^ session.company;
        "Role: " ^ session.role;
        "Recruiter: " ^ session.recruiter_name;
        "Work email: " ^ session.work_email;
        "Start: " ^ hold.start_at;
        "End: " ^ hold.end_at;
        "Calendar: " ^ hold.calendar_id;
        "";
        "Ban this address: " ^ ban_address_url;
        "Ban this domain: " ^ ban_domain_url;
        "";
        "Contact: nathan@vegasbuckeye.com";
      ]
  in
  let html =
    "<p>A recruiter agent created a tentative calendar hold.</p><ul><li>Company: "
    ^ escape_html session.company ^ "</li><li>Role: "
    ^ escape_html session.role ^ "</li><li>Recruiter: "
    ^ escape_html session.recruiter_name ^ "</li><li>Work email: "
    ^ escape_html session.work_email ^ "</li><li>Start: "
    ^ escape_html hold.start_at ^ "</li><li>End: " ^ escape_html hold.end_at
    ^ "</li></ul><p><a href=\"" ^ escape_html ban_address_url
    ^ "\">Ban this address</a> · <a href=\"" ^ escape_html ban_domain_url
    ^ "\">Ban this domain</a></p><p>Contact: nathan@vegasbuckeye.com</p>"
  in
  deps.mail.send
    {
      to_ = deps.cfg.mail_to;
      from_ = deps.cfg.mail_from;
      subject;
      text;
      html;
    }

let fire_booking deps (session : Interview_store.session) ~hold_id ~start
    ~end_ =
  match session.callback_url with
  | None -> return ()
  | Some url ->
      let body =
        Interview_json.json_stringify
          (Interview_webhook.booking_requested_body ~session ~hold_id ~start
             ~end_)
      in
      deps.webhook.post url body
      >>= (function Ok () | Error _ -> return ())
      |> Js.Promise.catch (fun _ -> return ())

let strip_prefix ~prefix s =
  if String.starts_with ~prefix s then
    Some
      (String.sub s (String.length prefix) (String.length s - String.length prefix))
  else None

(* Port errors arrive as "<tag>:<detail>" so a backend can name a refusal
   without the service knowing which backend spoke. *)
let env_error msg =
  let tagged =
    [
      ("missing_env:", fun detail -> Missing_env detail);
      ("slot_unavailable:", fun detail -> Slot_unavailable detail);
      ("invalid:", fun detail -> Invalid detail);
    ]
  in
  let rec first = function
    | [] -> if msg = "slot_unavailable" then Slot_unavailable "" else Invalid msg
    | (prefix, make) :: rest -> (
        match strip_prefix ~prefix msg with
        | Some detail -> make detail
        | None -> first rest)
  in
  first tagged

(* A hold cancelled in the booking backend never tells us, so the cap asks
   before it counts. An existence probe that errors counts as still-live: a
   flaky backend must not hand out extra slots. *)
let reconcile_active_holds (deps : deps) domain now_iso =
  deps.store.active_holds domain now_iso >>= fun holds ->
  let rec walk live = function
    | [] -> return live
    | (h : Interview_store.hold) :: rest ->
        deps.calendar.event_exists ~calendar_id:h.calendar_id
          ~event_id:h.calendar_event_id
        >>= (function
              | Ok false -> deps.store.cancel_hold h.id >>= fun () -> return live
              | Ok true | Error _ -> return (live + 1))
        >>= fun live -> walk live rest
  in
  walk 0 holds

let create_hold (deps : deps) ~start ~end_ ~book_token =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None ->
      let start_iso = String.trim start in
      if start_iso = "" then err (Invalid "start is required")
      else
        lookup_book deps book_token >>= function
        | Error e -> return (Error e)
        | Ok (book, session) ->
            let required = Interview_config.required_ids deps.cfg in
            let snap =
              Interview_required.snapshot required
                {
                  completed = session.completed;
                  hiring_timeline = session.hiring_timeline;
                }
            in
            if snap.required_remaining <> [] then
              err (Required_incomplete snap.required_remaining)
            else (
              match
                ( Interview_config.missing_calendar deps.cfg,
                  Interview_config.missing_mail deps.cfg )
              with
              | Some name, _ | None, Some name -> err (Missing_env name)
              | None, None ->
                  let now = deps.now_ms () in
                  let now_iso = Interview_clock.iso_of_ms now in
                  (* One concurrent caller wins the token; the loser refuses
                     before touching the calendar. Every refusal below releases
                     the claim so a refused hold leaves the token usable. *)
                  let refuse e =
                    deps.store.release_token book.token >>= fun () -> err e
                  in
                  catch_store
                    (deps.store.claim_token book.token >>= fun claimed ->
                     if not claimed then err (Token_invalid "already used")
                     else
                     reconcile_active_holds deps session.work_domain now_iso
                     >>= fun n ->
                     if
                       Interview_hold.at_or_over_cap ~active:n
                         ~cap:deps.cfg.hold_cap
                     then refuse (Hold_cap deps.cfg.hold_cap)
                     else
                       let end_iso =
                         Interview_hold.resolve_end ~start_iso ~end_
                           ~default_seconds:deps.cfg.hold_default_seconds
                       in
                       let req : Interview_calendar.request =
                         {
                           calendar_id = deps.cfg.calendar_id;
                           summary =
                             "Interview hold: " ^ session.company ^ " / "
                             ^ session.role;
                           description =
                             "Tentative hold from interview-me. Recruiter: "
                             ^ session.recruiter_name ^ " <"
                             ^ session.work_email ^ ">";
                           start_iso;
                           end_iso;
                           guest_name = session.recruiter_name;
                           guest_email = session.work_email;
                         }
                       in
                       deps.calendar.create_tentative req >>= function
                       | Error msg -> refuse (env_error msg)
                       | Ok created -> (
                           match deps.cfg.magic_link_secret with
                           | None ->
                               deps.calendar.delete_event
                                 ~calendar_id:created.calendar_id
                                 ~event_id:created.event_id
                               >>= fun _ ->
                               refuse (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
                           | Some secret ->
                               let ban_addr_raw = deps.random_id () in
                               let ban_dom_raw = deps.random_id () in
                               let exp =
                                 Interview_token.expires_at_iso ~now_ms:now
                                   ~ttl_ms:(30. *. 86_400_000.)
                               in
                               let ban_address_url =
                                 Interview_token.ban_link
                                   ~site_url:deps.cfg.site_url ~kind:"address"
                                   ~signed:
                                     (Interview_token.sign_token secret
                                        ban_addr_raw)
                               in
                               let ban_domain_url =
                                 Interview_token.ban_link
                                   ~site_url:deps.cfg.site_url ~kind:"domain"
                                   ~signed:
                                     (Interview_token.sign_token secret
                                        ban_dom_raw)
                               in
                               let hold : Interview_store.hold =
                                 {
                                   id = "hld_" ^ deps.random_id ();
                                   session_id = session.id;
                                   work_domain = session.work_domain;
                                   start_at = start_iso;
                                   end_at = end_iso;
                                   status = "tentative";
                                   calendar_id = created.calendar_id;
                                   calendar_event_id = created.event_id;
                                   created_at = now_iso;
                                 }
                               in
                               hold_notification deps session hold
                                 ban_address_url ban_domain_url
                               >>= function
                               | Error msg ->
                                   deps.calendar.delete_event
                                     ~calendar_id:created.calendar_id
                                     ~event_id:created.event_id
                                   >>= fun _ -> refuse (env_error msg)
                               | Ok _ ->
                                   deps.store.put_hold hold >>= fun () ->
                                   deps.store.put_token
                                     {
                                       token = ban_addr_raw;
                                       kind = "ban_address";
                                       session_id = session.id;
                                       expires_at = exp;
                                       consumed = false;
                                       created_at = now_iso;
                                     }
                                   >>= fun () ->
                                   deps.store.put_token
                                     {
                                       token = ban_dom_raw;
                                       kind = "ban_domain";
                                       session_id = session.id;
                                       expires_at = exp;
                                       consumed = false;
                                       created_at = now_iso;
                                     }
                                   >>= fun () ->
                                   fire_booking deps session ~hold_id:hold.id
                                     ~start:start_iso ~end_:end_iso
                                   >>= fun () ->
                                   ok
                                     {
                                       hold_id = hold.id;
                                       session_id = session.id;
                                       start = start_iso;
                                       end_ = end_iso;
                                       calendar_id = created.calendar_id;
                                       calendar_event_id = created.event_id;
                                       html_link = created.html_link;
                                     })))

let ban (deps : deps) ~kind ~signed =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None -> (
      match deps.cfg.magic_link_secret with
      | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
      | Some secret -> (
          let signed = String.trim signed in
          if signed = "" then err (Token_invalid "empty token")
          else
            match Interview_token.unsign_token secret signed with
            | None -> err (Token_invalid "bad signature")
            | Some raw ->
                catch_store
                  (deps.store.get_token raw >>= function
                  | None -> err (Token_invalid "unknown token")
                  | Some tok ->
                      let now = deps.now_ms () in
                      if tok.consumed then err (Token_invalid "already used")
                      else if
                        Interview_token.is_expired ~now_ms:now tok.expires_at
                      then err (Token_invalid "expired")
                      else
                        deps.store.get_session tok.session_id >>= function
                        | None -> err (Token_invalid "unknown session")
                        | Some session ->
                            let kind =
                              let k = String.lowercase_ascii (String.trim kind) in
                              if k = "domain" then "domain" else "address"
                            in
                            let value, expect =
                              if kind = "domain" then
                                (session.work_domain, "ban_domain")
                              else (session.work_email, "ban_address")
                            in
                            if tok.kind <> expect then
                              err (Token_invalid "wrong ban kind")
                            else
                              deps.store.consume_token raw >>= fun () ->
                              deps.store.put_ban
                                {
                                  kind;
                                  value = String.lowercase_ascii value;
                                  created_at = Interview_clock.iso_of_ms now;
                                }
                              >>= fun () -> ok (kind, value))))

let get_resume (deps : deps) = deps.corpus.resume_json

let search_experience (deps : deps) query =
  Interview_corpus.search deps.corpus query

let error_code = function
  | Missing_env _ -> 503
  | Invalid _ -> 400
  | Slot_unavailable _ -> 409
  | Free_email _ -> 400
  | Banned _ -> 403
  | Not_found -> 404
  | Token_invalid _ -> 401
  | Required_incomplete _ -> 409
  | Hold_cap _ -> 409

let error_name = function
  | Missing_env _ -> "missing_env"
  | Invalid _ -> "invalid"
  | Slot_unavailable _ -> "slot_unavailable"
  | Free_email _ -> "free_email"
  | Banned _ -> "banned"
  | Not_found -> "not_found"
  | Token_invalid _ -> "token_invalid"
  | Required_incomplete _ -> "required_incomplete"
  | Hold_cap _ -> "hold_cap"

let error_json = function
  | Missing_env name ->
      Interview_json.obj
        [
          ("error", Interview_json.str "missing_env");
          ("name", Interview_json.str name);
        ]
  | Invalid msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "invalid");
          ("message", Interview_json.str msg);
        ]
  | Slot_unavailable msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "slot_unavailable");
          ("message", Interview_json.str msg);
        ]
  | Free_email domain ->
      Interview_json.obj
        [
          ("error", Interview_json.str "free_email");
          ("domain", Interview_json.str domain);
        ]
  | Banned value ->
      Interview_json.obj
        [
          ("error", Interview_json.str "banned");
          ("value", Interview_json.str value);
        ]
  | Not_found -> Interview_json.obj [ ("error", Interview_json.str "not_found") ]
  | Token_invalid msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "token_invalid");
          ("message", Interview_json.str msg);
        ]
  | Required_incomplete missing ->
      Interview_json.obj
        [
          ("error", Interview_json.str "required_incomplete");
          ( "missing",
            Interview_json.arr (List.map Interview_json.str missing) );
        ]
  | Hold_cap n ->
      Interview_json.obj
        [
          ("error", Interview_json.str "hold_cap");
          ("cap", Interview_json.num (float_of_int n));
        ]
