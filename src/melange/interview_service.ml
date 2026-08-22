(* Interview-me product loop: session, cited ask, verify, hold gates. *)

type error =
  | Missing_env of string
  | Invalid of string
  | Free_email of string
  | Banned of string
  | Not_found
  | Unverified
  | Token_invalid of string
  | Required_incomplete of string list
  | Hold_cap of int
  | Calendar of string
  | Mail of string
  | Store of string

type start_input = {
  company : string;
  role : string;
  recruiter_name : string;
  work_email : string;
  callback_url : string option;
}

type ask_output = {
  session_id : string;
  answer : string;
  cited : bool;
  citation : Interview_corpus.citation option;
  refused : bool;
  completed_item : string option;
  required_progress : string list;
  required_remaining : string list;
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

type webhook = { post : string -> string -> unit Js.Promise.t }

type deps = {
  now_ms : unit -> float;
  random_id : unit -> string;
  cfg : Interview_config.t;
  store : Interview_store.t;
  corpus : Interview_corpus.t;
  mail : Interview_mail.t;
  calendar : Interview_calendar.t;
  webhook : webhook;
}

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x
let ok x = return (Ok x)
let err e = return (Error e)

external js_message : 'a -> string Js.undefined = "message" [@@mel.get]

let exn_message err =
  match Js.Undefined.toOption (js_message err) with
  | Some m when String.trim m <> "" -> m
  | _ -> "store failed"

let catch_store p = p |> Js.Promise.catch (fun e -> err (Store (exn_message e)))

let escape_html s =
  s
  |> Js.String.replaceByRe ~regexp:[%mel.re "/&/g"] ~replacement:"&amp;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/</g"] ~replacement:"&lt;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/>/g"] ~replacement:"&gt;"
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\"/g"] ~replacement:"&quot;"

let required_ids (cfg : Interview_config.t) =
  List.map (fun (i : Interview_config.required_item) -> i.id) cfg.required

let remaining (cfg : Interview_config.t) completed =
  List.filter (fun id -> not (List.exists (fun c -> c = id) completed)) (required_ids cfg)

let mark_completed (session : Interview_store.session) item_id =
  match item_id with
  | None -> session
  | Some id ->
      if List.exists (fun c -> c = id) session.Interview_store.completed then
        session
      else
        {
          session with
          completed = session.Interview_store.completed @ [ id ];
        }

let fire_webhook deps event payload =
  match Interview_json.as_object payload with
  | None -> return ()
  | Some dict -> (
      match Interview_json.opt_string_field dict "callback_url" with
      | None -> return ()
      | Some url ->
          deps.webhook.post url
            (Interview_json.json_stringify
               (Interview_json.obj
                  [
                    ("event", Interview_json.str event);
                    ("payload", payload);
                  ]))
          |> Js.Promise.then_ (fun () -> return ())
          |> Js.Promise.catch (fun _ -> return ()))

let session_payload (s : Interview_store.session) extra =
  Interview_json.obj
    ([
       ("session_id", Interview_json.str s.id);
       ("company", Interview_json.str s.company);
       ("role", Interview_json.str s.role);
       ("recruiter_name", Interview_json.str s.recruiter_name);
       ("work_email", Interview_json.str s.work_email);
     ]
    @ (match s.callback_url with
      | Some u -> [ ("callback_url", Interview_json.str u) ]
      | None -> [])
    @ extra)

let capturing_webhook () =
  let sent = ref [] in
  ( {
      post =
        (fun url body ->
          sent := (url, body) :: !sent;
          return ());
    },
    sent )

let http_webhook () =
  {
    post =
      (fun url body ->
        let headers = Js.Dict.empty () in
        Js.Dict.set headers "Content-Type" "application/json";
        Interview_http_fetch.post url ~headers ~body >>= fun _ -> return ());
  }

let start (deps : deps) (input : start_input) =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None ->
      let company = String.trim input.company in
      let role = String.trim input.role in
      let recruiter = String.trim input.recruiter_name in
      let email = String.trim input.work_email |> String.lowercase_ascii in
      if company = "" || role = "" || recruiter = "" then
        err (Invalid "company, role, and recruiter_name are required")
      else if not (Interview_config.is_valid_email email) then
        err (Invalid "work_email must be a valid email")
      else if Interview_config.is_free_email deps.cfg email then
        err (Free_email (Interview_config.email_domain email))
      else
        let domain = Interview_config.email_domain email in
        catch_store
          (deps.store.is_banned "address" email >>= fun addr_ban ->
           deps.store.is_banned "domain" domain >>= fun domain_ban ->
           if addr_ban then err (Banned email)
           else if domain_ban then err (Banned domain)
           else
             let now = Interview_crypto.iso_of_ms (deps.now_ms ()) in
             let session : Interview_store.session =
               {
                 id = "ses_" ^ deps.random_id ();
                 company;
                 role;
                 recruiter_name = recruiter;
                 work_email = email;
                 work_domain = domain;
                 callback_url = input.callback_url;
                 hiring_timeline = None;
                 completed = [];
                 verified = false;
                 created_at = now;
               }
             in
             deps.store.put_session session >>= fun () -> ok session)

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
            let hit = Interview_corpus.ask deps.cfg deps.corpus q in
            let session =
              match hit.kind with
              | Interview_corpus.Recruiter ->
                  let marked = mark_completed session hit.completed in
                  { marked with hiring_timeline = Some q }
              | Interview_corpus.Cited _ -> mark_completed session hit.completed
              | Interview_corpus.Refuse -> session
            in
            deps.store.put_session session >>= fun () ->
            let remaining_ids = remaining deps.cfg session.completed in
            let just_completed =
              remaining_ids = []
              && hit.completed <> None
              &&
              match hit.kind with
              | Interview_corpus.Refuse -> false
              | _ -> true
            in
            (if just_completed && session.callback_url <> None then
               fire_webhook deps "interview.completed"
                 (session_payload session
                    [
                      ( "completed",
                        Interview_json.arr
                          (List.map Interview_json.str session.completed) );
                    ])
             else return ())
            >>= fun () ->
            ok
              {
                session_id = session.id;
                answer = hit.answer;
                cited =
                  (match hit.kind with
                  | Interview_corpus.Cited _ -> true
                  | _ -> false);
                citation =
                  (match hit.kind with
                  | Interview_corpus.Cited c -> Some c
                  | _ -> None);
                refused =
                  (match hit.kind with Interview_corpus.Refuse -> true | _ -> false);
                completed_item =
                  (match hit.kind with
                  | Interview_corpus.Refuse -> None
                  | _ -> hit.completed);
                required_progress = session.completed;
                required_remaining = remaining_ids;
              })

type verify_request_output = { session_id : string }

let request_verification (deps : deps) ~session_id =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None -> (
      match Interview_config.missing_magic_secret deps.cfg with
      | Some name -> err (Missing_env name)
      | None ->
          catch_store
          (deps.store.get_session session_id >>= function
          | None -> err Not_found
          | Some session ->
              let secret = Option.get deps.cfg.magic_link_secret in
              let raw = deps.random_id () in
              let now = deps.now_ms () in
              let tok : Interview_store.token =
                {
                  token = raw;
                  kind = "magic";
                  session_id = session.id;
                  expires_at =
                    Interview_crypto.iso_of_ms (now +. deps.cfg.magic_link_ttl_ms);
                  consumed = false;
                  created_at = Interview_crypto.iso_of_ms now;
                }
              in
              deps.store.put_token tok >>= fun () ->
              let signed = Interview_crypto.sign_token secret raw in
              let link =
                deps.cfg.site_url ^ "/interview/verify?token="
                ^ Interview_crypto.encode_uri signed
              in
              let subject = "Verify your work email for interview-me" in
              let text =
                "Click to verify your work email for the interview-me session \
                 with Nathan Sculli:\n\n" ^ link
                ^ "\n\nThe agent never needs your inbox. After you click, you \
                   will see a short-lived book token to give the agent."
              in
              let html =
                "<p>Click to verify your work email for the interview-me \
                 session with Nathan Sculli.</p><p><a href=\"" ^ escape_html link
                ^ "\">Verify work email</a></p><p>The agent never needs your \
                   inbox. After you click, you will see a short-lived book \
                   token to give the agent.</p>"
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
              | Error msg -> err (Mail msg)
              | Ok _ -> ok { session_id = session.id }))

type verify_output = {
  session_id : string;
  book_token : string;
  expires_at : string;
}

let verify (deps : deps) ~signed =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None -> (
      match deps.cfg.magic_link_secret with
      | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
      | Some secret -> (
          match Interview_crypto.unsign_token secret signed with
          | None -> err (Token_invalid "bad signature")
          | Some raw ->
              deps.store.get_token raw >>= function
              | None -> err (Token_invalid "unknown token")
              | Some tok ->
                  let now = deps.now_ms () in
                  if tok.kind <> "magic" then err (Token_invalid "wrong kind")
                  else if tok.consumed then err (Token_invalid "already used")
                  else if Interview_crypto.is_expired ~now tok.expires_at then
                    err (Token_invalid "expired")
                  else
                    deps.store.get_session tok.session_id >>= function
                    | None -> err Not_found
                    | Some session ->
                        deps.store.consume_token raw >>= fun () ->
                        let book_raw = deps.random_id () in
                        let expires_at =
                          Interview_crypto.iso_of_ms
                            (now +. deps.cfg.book_token_ttl_ms)
                        in
                        let book : Interview_store.token =
                          {
                            token = book_raw;
                            kind = "book";
                            session_id = session.id;
                            expires_at;
                            consumed = false;
                            created_at = Interview_crypto.iso_of_ms now;
                          }
                        in
                        deps.store.put_token book >>= fun () ->
                        deps.store.put_session { session with verified = true }
                        >>= fun () ->
                        let signed_book =
                          Interview_crypto.sign_token secret book_raw
                        in
                        ok
                          {
                            session_id = session.id;
                            book_token = signed_book;
                            expires_at;
                          }))

let lookup_book (deps : deps) signed =
  match deps.cfg.magic_link_secret with
  | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
  | Some secret -> (
      match Interview_crypto.unsign_token secret signed with
      | None -> err (Token_invalid "bad book token")
      | Some raw ->
          deps.store.get_token raw >>= function
          | None -> err (Token_invalid "unknown book token")
          | Some tok ->
              let now = deps.now_ms () in
              if tok.kind <> "book" then err (Token_invalid "not a book token")
              else if tok.consumed then err (Token_invalid "book token used")
              else if Interview_crypto.is_expired ~now tok.expires_at then
                err (Token_invalid "book token expired")
              else ok tok)

let hold_notification (deps : deps) (session : Interview_store.session)
    (hold : Interview_store.hold) ban_address_url ban_domain_url =
  let subject =
    "Interview-me hold: " ^ session.Interview_store.company ^ " / "
    ^ session.role
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
        "Start: " ^ hold.Interview_store.start_at;
        "End: " ^ hold.end_at;
        "Calendar: " ^ hold.calendar_id;
        "";
        "Ban this address: " ^ ban_address_url;
        "Ban this domain: " ^ ban_domain_url;
      ]
  in
  let html =
    "<p>A recruiter agent created a tentative calendar hold.</p><ul><li>Company: "
    ^ escape_html session.company ^ "</li><li>Role: " ^ escape_html session.role
    ^ "</li><li>Recruiter: " ^ escape_html session.recruiter_name
    ^ "</li><li>Work email: " ^ escape_html session.work_email
    ^ "</li><li>Start: " ^ escape_html hold.start_at ^ "</li><li>End: "
    ^ escape_html hold.end_at ^ "</li></ul><p><a href=\""
    ^ escape_html ban_address_url ^ "\">Ban this address</a> · <a href=\""
    ^ escape_html ban_domain_url ^ "\">Ban this domain</a></p>"
  in
  deps.mail.send
    {
      to_ = deps.cfg.mail_to;
      from_ = deps.cfg.mail_from;
      subject;
      text;
      html;
    }

let create_hold (deps : deps) ~start ~end_ ~book_token =
  match Interview_config.missing_store deps.cfg with
  | Some name -> err (Missing_env name)
  | None ->
      lookup_book deps book_token >>= function
      | Error e -> return (Error e)
      | Ok book ->
          deps.store.get_session book.session_id >>= function
          | None -> err Not_found
          | Some session ->
              if not session.verified then err Unverified
              else
                let missing = remaining deps.cfg session.completed in
                if missing <> [] then err (Required_incomplete missing)
                else
                  let now_iso = Interview_crypto.iso_of_ms (deps.now_ms ()) in
                  deps.store.is_banned "address" session.work_email
                  >>= fun addr_ban ->
                  deps.store.is_banned "domain" session.work_domain
                  >>= fun domain_ban ->
                  if addr_ban then err (Banned session.work_email)
                  else if domain_ban then err (Banned session.work_domain)
                  else
                    deps.store.count_active_holds session.work_domain now_iso
                    >>= fun n ->
                    if n >= deps.cfg.hold_cap then err (Hold_cap deps.cfg.hold_cap)
                    else
                      let start_iso = String.trim start in
                      if start_iso = "" then err (Invalid "start is required")
                      else
                        let end_iso =
                          match end_ with
                          | Some e when String.trim e <> "" -> String.trim e
                          | _ ->
                              Interview_crypto.iso_of_ms
                                (Interview_crypto.ms_of_iso start_iso
                                +. (float_of_int deps.cfg.hold_default_seconds
                                   *. 1000.))
                        in
                        let req : Interview_calendar.hold_request =
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
                          }
                        in
                        deps.calendar.create_tentative req >>= function
                        | Error msg -> err (Calendar msg)
                        | Ok created ->
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
                            let secret = Option.get deps.cfg.magic_link_secret in
                            let ban_addr_raw = deps.random_id () in
                            let ban_dom_raw = deps.random_id () in
                            let exp =
                              Interview_crypto.iso_of_ms
                                (deps.now_ms () +. (30. *. 86400000.))
                            in
                            let ban_address_url =
                              deps.cfg.site_url ^ "/interview/ban?kind=address&token="
                              ^ Interview_crypto.encode_uri
                                  (Interview_crypto.sign_token secret ban_addr_raw)
                            in
                            let ban_domain_url =
                              deps.cfg.site_url ^ "/interview/ban?kind=domain&token="
                              ^ Interview_crypto.encode_uri
                                  (Interview_crypto.sign_token secret ban_dom_raw)
                            in
                            let cancel_created () =
                              deps.calendar.delete_event
                                ~calendar_id:created.calendar_id
                                ~event_id:created.event_id
                              >>= fun _ -> return ()
                            in
                            hold_notification deps session hold ban_address_url
                              ban_domain_url
                            >>= fun mail_res ->
                            match mail_res with
                            | Error msg ->
                                cancel_created () >>= fun () -> err (Mail msg)
                            | Ok _ ->
                                deps.store.put_hold hold >>= fun () ->
                                deps.store.consume_token book.token >>= fun () ->
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
                                (match session.callback_url with
                                | None -> return ()
                                | Some _ ->
                                    fire_webhook deps "booking.requested"
                                      (session_payload session
                                         [
                                           ( "hold_id",
                                             Interview_json.str hold.id );
                                           ( "start",
                                             Interview_json.str start_iso );
                                           ("end", Interview_json.str end_iso);
                                         ]))
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
                                  }

let ban (deps : deps) ~kind ~signed =
  match deps.cfg.magic_link_secret with
  | None -> err (Missing_env "INTERVIEW_MAGIC_LINK_SECRET")
  | Some secret -> (
      match Interview_crypto.unsign_token secret signed with
      | None -> err (Token_invalid "bad ban token")
      | Some raw ->
          deps.store.get_token raw >>= function
          | None -> err (Token_invalid "unknown ban token")
          | Some tok ->
              let now = deps.now_ms () in
              if tok.consumed then err (Token_invalid "already used")
              else if Interview_crypto.is_expired ~now tok.expires_at then
                err (Token_invalid "expired")
              else
                deps.store.get_session tok.session_id >>= function
                | None -> err Not_found
                | Some session ->
                    let value, expect =
                      if kind = "domain" then
                        (session.work_domain, "ban_domain")
                      else (session.work_email, "ban_address")
                    in
                    if tok.kind <> expect && tok.kind <> "ban_" ^ kind then
                      err (Token_invalid "wrong ban kind")
                    else
                      deps.store.consume_token raw >>= fun () ->
                      deps.store.put_ban
                        {
                          kind;
                          value = String.lowercase_ascii value;
                          created_at = Interview_crypto.iso_of_ms now;
                        }
                      >>= fun () -> ok (kind, value))

let get_resume (deps : deps) = deps.corpus.resume_json

let search_experience (deps : deps) query =
  Interview_corpus.search deps.corpus query

let error_code = function
  | Missing_env _ -> 503
  | Invalid _ -> 400
  | Free_email _ -> 400
  | Banned _ -> 403
  | Not_found -> 404
  | Unverified -> 403
  | Token_invalid _ -> 401
  | Required_incomplete _ -> 409
  | Hold_cap _ -> 409
  | Calendar _ -> 502
  | Mail _ -> 502
  | Store _ -> 502

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
  | Unverified ->
      Interview_json.obj [ ("error", Interview_json.str "unverified") ]
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
  | Calendar msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "calendar");
          ("message", Interview_json.str msg);
        ]
  | Mail msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "mail");
          ("message", Interview_json.str msg);
        ]
  | Store msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "store");
          ("message", Interview_json.str msg);
        ]
