(* Named session + cited ask + human magic-link verify. create_hold stays
   fail-closed; T-19 owns calendar holds. *)

type error =
  | Missing_env of string
  | Invalid of string
  | Free_email of string
  | Not_found
  | Token_invalid of string

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
}

type verify_request_output = { session_id : string }

type verify_output = {
  session_id : string;
  book_token : string;
  expires_at : string;
}

type deps = {
  now_ms : unit -> float;
  random_id : unit -> string;
  cfg : Interview_config.t;
  store : Interview_store.t;
  corpus : Interview_corpus.t;
  mail : Interview_mail.t;
  calendar : Interview_calendar.t;
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
            verified = false;
            created_at = now;
          }
        in
        catch_store
          (deps.store.put_session session >>= fun () -> ok session)

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
              let hit = Interview_corpus.ask deps.corpus q in
              ok
                {
                  session_id = session.id;
                  company = session.company;
                  role = session.role;
                  recruiter_name = session.recruiter_name;
                  work_email = session.work_email;
                  callback_url = session.callback_url;
                  answer = hit.answer;
                  cited =
                    (match hit.kind with
                    | Interview_corpus.Cited _ -> true
                    | Interview_corpus.Refuse -> false);
                  citation =
                    (match hit.kind with
                    | Interview_corpus.Cited c -> Some c
                    | Interview_corpus.Refuse -> None);
                  refused =
                    (match hit.kind with
                    | Interview_corpus.Refuse -> true
                    | Interview_corpus.Cited _ -> false);
                })

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

let create_hold (_deps : deps) ~start:_ ~end_:_ ~book_token:_ =
  (* T-19. Never call the calendar action. *)
  err (Invalid "create_hold is not available")

let get_resume (deps : deps) = deps.corpus.resume_json

let search_experience (deps : deps) query =
  Interview_corpus.search deps.corpus query

let error_code = function
  | Missing_env _ -> 503
  | Invalid _ -> 400
  | Free_email _ -> 400
  | Not_found -> 404
  | Token_invalid _ -> 401

let error_name = function
  | Missing_env _ -> "missing_env"
  | Invalid _ -> "invalid"
  | Free_email _ -> "free_email"
  | Not_found -> "not_found"
  | Token_invalid _ -> "token_invalid"

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
  | Not_found -> Interview_json.obj [ ("error", Interview_json.str "not_found") ]
  | Token_invalid msg ->
      Interview_json.obj
        [
          ("error", Interview_json.str "token_invalid");
          ("message", Interview_json.str msg);
        ]
