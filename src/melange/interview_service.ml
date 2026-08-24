(* Named session + cited ask. Verify/hold are fail-closed names only. *)

type error =
  | Missing_env of string
  | Invalid of string
  | Free_email of string
  | Not_found

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

type deps = {
  now_ms : unit -> float;
  random_id : unit -> string;
  cfg : Interview_config.t;
  store : Interview_store.t;
  corpus : Interview_corpus.t;
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

let request_verification (_deps : deps) ~session_id:_ =
  err (Invalid "request_verification is not available")

let create_hold (_deps : deps) ~start:_ ~end_:_ ~book_token:_ =
  err (Invalid "create_hold is not available")

let get_resume (deps : deps) = deps.corpus.resume_json

let search_experience (deps : deps) query =
  Interview_corpus.search deps.corpus query

let error_code = function
  | Missing_env _ -> 503
  | Invalid _ -> 400
  | Free_email _ -> 400
  | Not_found -> 404

let error_name = function
  | Missing_env _ -> "missing_env"
  | Invalid _ -> "invalid"
  | Free_email _ -> "free_email"
  | Not_found -> "not_found"

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
