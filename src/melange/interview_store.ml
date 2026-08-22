(* Session / token / hold persistence. Production and deploy-preview are Turso
   (libSQL HTTP) only. Tests inject Memory.bind in-process; of_config never
   honors an INTERVIEW_STORE=memory switch. *)

type session = {
  id : string;
  company : string;
  role : string;
  recruiter_name : string;
  work_email : string;
  work_domain : string;
  callback_url : string option;
  hiring_timeline : string option;
  completed : string list;
  verified : bool;
  created_at : string;
}

type token = {
  token : string;
  kind : string;
  session_id : string;
  expires_at : string;
  consumed : bool;
  created_at : string;
}

type hold = {
  id : string;
  session_id : string;
  work_domain : string;
  start_at : string;
  end_at : string;
  status : string;
  calendar_id : string;
  calendar_event_id : string;
  created_at : string;
}

type ban = { kind : string; value : string; created_at : string }

type t = {
  ensure_schema : unit -> unit Js.Promise.t;
  put_session : session -> unit Js.Promise.t;
  get_session : string -> session option Js.Promise.t;
  put_token : token -> unit Js.Promise.t;
  get_token : string -> token option Js.Promise.t;
  consume_token : string -> unit Js.Promise.t;
  put_hold : hold -> unit Js.Promise.t;
  count_active_holds : string -> string -> int Js.Promise.t;
  put_ban : ban -> unit Js.Promise.t;
  is_banned : string -> string -> bool Js.Promise.t;
}

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let schema_sql =
  [
    {|CREATE TABLE IF NOT EXISTS interview_sessions (
        id TEXT PRIMARY KEY,
        company TEXT NOT NULL,
        role TEXT NOT NULL,
        recruiter_name TEXT NOT NULL,
        work_email TEXT NOT NULL,
        work_domain TEXT NOT NULL,
        callback_url TEXT,
        hiring_timeline TEXT,
        completed TEXT NOT NULL DEFAULT '[]',
        verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )|};
    {|CREATE TABLE IF NOT EXISTS interview_tokens (
        token TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        session_id TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )|};
    {|CREATE TABLE IF NOT EXISTS interview_holds (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        work_domain TEXT NOT NULL,
        start_at TEXT NOT NULL,
        end_at TEXT NOT NULL,
        status TEXT NOT NULL,
        calendar_id TEXT NOT NULL,
        calendar_event_id TEXT,
        created_at TEXT NOT NULL
      )|};
    {|CREATE TABLE IF NOT EXISTS interview_bans (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT NOT NULL
      )|};
  ]

module Memory = struct
  type tables = {
    sessions : (string, session) Hashtbl.t;
    tokens : (string, token) Hashtbl.t;
    holds : (string, hold) Hashtbl.t;
    bans : (string, ban) Hashtbl.t;
  }

  let create () =
    {
      sessions = Hashtbl.create 16;
      tokens = Hashtbl.create 16;
      holds = Hashtbl.create 16;
      bans = Hashtbl.create 16;
    }

  let bind tables : t =
    {
      ensure_schema = (fun () -> return ());
      put_session =
        (fun s ->
          Hashtbl.replace tables.sessions s.id s;
          return ());
      get_session =
        (fun id ->
          return (try Some (Hashtbl.find tables.sessions id) with Not_found -> None));
      put_token =
        (fun tok ->
          Hashtbl.replace tables.tokens tok.token tok;
          return ());
      get_token =
        (fun id ->
          return (try Some (Hashtbl.find tables.tokens id) with Not_found -> None));
      consume_token =
        (fun id ->
          (try
             let tok = Hashtbl.find tables.tokens id in
             Hashtbl.replace tables.tokens id { tok with consumed = true }
           with Not_found -> ());
          return ());
      put_hold =
        (fun h ->
          Hashtbl.replace tables.holds h.id h;
          return ());
      count_active_holds =
        (fun domain now_iso ->
          let n = ref 0 in
          Hashtbl.iter
            (fun _ h ->
              if
                h.work_domain = domain && h.status = "tentative"
                && h.end_at > now_iso
              then incr n)
            tables.holds;
          return !n);
      put_ban =
        (fun b ->
          Hashtbl.replace tables.bans (b.kind ^ ":" ^ b.value) b;
          return ());
      is_banned =
        (fun kind value ->
          let v = String.lowercase_ascii (String.trim value) in
          let hit = ref false in
          Hashtbl.iter
            (fun _ b ->
              if b.kind = kind && b.value = v then hit := true)
            tables.bans;
          return !hit);
    }
end

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

let js_err_message err =
  match peek_exn err 0 with Some s -> s | None -> "fetch failed"

let strip_slash u =
  if String.ends_with ~suffix:"/" u && String.length u > 1 then
    String.sub u 0 (String.length u - 1)
  else u

let http_url raw =
  let u = String.trim raw in
  let u =
    if String.starts_with ~prefix:"libsql://" u then
      "https://" ^ String.sub u 9 (String.length u - 9)
    else if String.starts_with ~prefix:"https://" u then u
    else if String.starts_with ~prefix:"http://" u then u
    else "https://" ^ u
  in
  strip_slash u

let pipeline_url raw =
  let u = http_url raw in
  if String.ends_with ~suffix:"/v2/pipeline" u then u else u ^ "/v2/pipeline"

let arg_text v =
  Interview_json.obj
    [ ("type", Interview_json.str "text"); ("value", Interview_json.str v) ]

let arg_int n =
  Interview_json.obj
    [
      ("type", Interview_json.str "integer");
      ("value", Interview_json.str (string_of_int n));
    ]

let arg_null =
  Interview_json.obj [ ("type", Interview_json.str "null") ]

let exec_stmt sql args =
  Interview_json.obj
    [
      ("type", Interview_json.str "execute");
      ( "stmt",
        Interview_json.obj
          [ ("sql", Interview_json.str sql); ("args", Interview_json.arr args) ]
      );
    ]

let pipeline_body stmts =
  Interview_json.obj
    [
      ("baton", Interview_json.null);
      ( "requests",
        Interview_json.arr
          (stmts @ [ Interview_json.obj [ ("type", Interview_json.str "close") ] ])
      );
    ]

let completed_of_json raw =
  try Interview_json.string_list (Interview_json.json_parse raw) with _ -> []

let completed_to_json xs = Interview_json.json_stringify (Interview_json.arr (List.map Interview_json.str xs))

let cell_string json =
  match Interview_json.as_object json with
  | None -> Interview_json.as_string json
  | Some dict ->
      (match Interview_json.opt_string_field dict "value" with
      | Some v -> v
      | None -> Interview_json.as_string json)

let rows_of_result json =
  match Interview_json.as_object json with
  | None -> []
  | Some root ->
      let results = Interview_json.as_array (Interview_json.field root "results") in
      let rec first_rows i =
        if i >= Array.length results then []
        else
          match Interview_json.as_object results.(i) with
          | None -> first_rows (i + 1)
          | Some item ->
              let resp = Interview_json.object_field item "response" in
              let result = Interview_json.object_field resp "result" in
              let rows = Interview_json.as_array (Interview_json.field result "rows") in
              if Array.length rows = 0 then first_rows (i + 1)
              else
                rows |> Array.to_list
                |> List.map (fun row ->
                       Interview_json.as_array row
                       |> Array.to_list |> List.map cell_string)
      in
      first_rows 0

let session_of_row = function
  | id :: company :: role :: recruiter :: email :: domain :: callback
    :: timeline :: completed :: verified :: created :: _ ->
      {
        id;
        company;
        role;
        recruiter_name = recruiter;
        work_email = email;
        work_domain = domain;
        callback_url = (if callback = "" then None else Some callback);
        hiring_timeline = (if timeline = "" then None else Some timeline);
        completed = completed_of_json completed;
        verified = verified = "1" || verified = "true";
        created_at = created;
      }
  | _ ->
      {
        id = "";
        company = "";
        role = "";
        recruiter_name = "";
        work_email = "";
        work_domain = "";
        callback_url = None;
        hiring_timeline = None;
        completed = [];
        verified = false;
        created_at = "";
      }

let token_of_row = function
  | token :: kind :: session_id :: expires :: consumed :: created :: _ ->
      {
        token;
        kind;
        session_id;
        expires_at = expires;
        consumed = consumed = "1" || consumed = "true";
        created_at = created;
      }
  | _ ->
      {
        token = "";
        kind = "";
        session_id = "";
        expires_at = "";
        consumed = false;
        created_at = "";
      }

let clip_body body =
  let t = String.trim body in
  if String.length t <= 300 then t else String.sub t 0 297 ^ "..."

let pipeline_error json =
  match Interview_json.as_object json with
  | None -> None
  | Some root ->
      let results = Interview_json.as_array (Interview_json.field root "results") in
      let rec loop i =
        if i >= Array.length results then None
        else
          match Interview_json.as_object results.(i) with
          | Some item
            when Interview_json.string_field item "type" = "error" ->
              let e = Interview_json.object_field item "error" in
              let msg = Interview_json.string_field e "message" in
              Some (if msg = "" then "pipeline error" else msg)
          | _ -> loop (i + 1)
      in
      loop 0

let turso ~url ~token () : t =
  let endpoint = pipeline_url url in
  let ready = ref false in
  let post stmts =
    let headers = Js.Dict.empty () in
    Js.Dict.set headers "Authorization" ("Bearer " ^ token);
    Js.Dict.set headers "Content-Type" "application/json";
    Interview_http_fetch.post endpoint ~headers
      ~body:(Interview_json.json_stringify (pipeline_body stmts))
    |> Js.Promise.catch (fun e ->
           Js.Promise.reject
             (Failure ("turso fetch failed: " ^ js_err_message e)))
    >>= fun res ->
    Interview_http_fetch.response_text res >>= fun body ->
    let status = Interview_http_fetch.response_status res in
    if not (Interview_http_fetch.response_ok res) then
      Js.Promise.reject
        (Failure ("turso " ^ string_of_int status ^ ": " ^ clip_body body))
    else
      let json =
        try Interview_json.json_parse body with _ -> Interview_json.null
      in
      match pipeline_error json with
      | Some msg -> Js.Promise.reject (Failure ("turso: " ^ msg))
      | None -> return json
  in
  let ensure () =
    if !ready then return ()
    else
      post (List.map (fun sql -> exec_stmt sql []) schema_sql) >>= fun _ ->
      ready := true;
      return ()
  in
  {
    ensure_schema = ensure;
    put_session =
      (fun s ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|INSERT INTO interview_sessions
                  (id, company, role, recruiter_name, work_email, work_domain,
                   callback_url, hiring_timeline, completed, verified, created_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET
                  company=excluded.company, role=excluded.role,
                  recruiter_name=excluded.recruiter_name,
                  work_email=excluded.work_email, work_domain=excluded.work_domain,
                  callback_url=excluded.callback_url,
                  hiring_timeline=excluded.hiring_timeline,
                  completed=excluded.completed, verified=excluded.verified|}
              [
                arg_text s.id;
                arg_text s.company;
                arg_text s.role;
                arg_text s.recruiter_name;
                arg_text s.work_email;
                arg_text s.work_domain;
                (match s.callback_url with Some u -> arg_text u | None -> arg_null);
                (match s.hiring_timeline with
                | Some t -> arg_text t
                | None -> arg_null);
                arg_text (completed_to_json s.completed);
                arg_int (if s.verified then 1 else 0);
                arg_text s.created_at;
              ];
          ]
        >>= fun _ -> return ());
    get_session =
      (fun id ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|SELECT id, company, role, recruiter_name, work_email, work_domain,
                       callback_url, hiring_timeline, completed, verified, created_at
                  FROM interview_sessions WHERE id = ?|}
              [ arg_text id ];
          ]
        >>= fun json ->
        match rows_of_result json with
        | row :: _ ->
            let s = session_of_row row in
            return (if s.id = "" then None else Some s)
        | [] -> return None);
    put_token =
      (fun tok ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|INSERT INTO interview_tokens
                  (token, kind, session_id, expires_at, consumed, created_at)
                VALUES (?,?,?,?,?,?)
                ON CONFLICT(token) DO UPDATE SET
                  consumed=excluded.consumed, expires_at=excluded.expires_at|}
              [
                arg_text tok.token;
                arg_text tok.kind;
                arg_text tok.session_id;
                arg_text tok.expires_at;
                arg_int (if tok.consumed then 1 else 0);
                arg_text tok.created_at;
              ];
          ]
        >>= fun _ -> return ());
    get_token =
      (fun id ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|SELECT token, kind, session_id, expires_at, consumed, created_at
                  FROM interview_tokens WHERE token = ?|}
              [ arg_text id ];
          ]
        >>= fun json ->
        match rows_of_result json with
        | row :: _ ->
            let tok = token_of_row row in
            return (if tok.token = "" then None else Some tok)
        | [] -> return None);
    consume_token =
      (fun id ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              "UPDATE interview_tokens SET consumed = 1 WHERE token = ?"
              [ arg_text id ];
          ]
        >>= fun _ -> return ());
    put_hold =
      (fun h ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|INSERT INTO interview_holds
                  (id, session_id, work_domain, start_at, end_at, status,
                   calendar_id, calendar_event_id, created_at)
                VALUES (?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET status=excluded.status|}
              [
                arg_text h.id;
                arg_text h.session_id;
                arg_text h.work_domain;
                arg_text h.start_at;
                arg_text h.end_at;
                arg_text h.status;
                arg_text h.calendar_id;
                arg_text h.calendar_event_id;
                arg_text h.created_at;
              ];
          ]
        >>= fun _ -> return ());
    count_active_holds =
      (fun domain now_iso ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|SELECT COUNT(*) FROM interview_holds
                 WHERE work_domain = ? AND status = 'tentative' AND end_at > ?|}
              [ arg_text domain; arg_text now_iso ];
          ]
        >>= fun json ->
        match rows_of_result json with
        | (n :: _) :: _ -> return (try int_of_string n with _ -> 0)
        | _ -> return 0);
    put_ban =
      (fun b ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              {|INSERT INTO interview_bans (id, kind, value, created_at)
                VALUES (?,?,?,?)|}
              [
                arg_text (b.kind ^ ":" ^ b.value);
                arg_text b.kind;
                arg_text b.value;
                arg_text b.created_at;
              ];
          ]
        >>= fun _ -> return ());
    is_banned =
      (fun kind value ->
        ensure () >>= fun () ->
        post
          [
            exec_stmt
              "SELECT id FROM interview_bans WHERE kind = ? AND value = ?"
              [ arg_text kind; arg_text (String.lowercase_ascii value) ];
          ]
        >>= fun json -> return (rows_of_result json <> []));
  }

let unavailable name : t =
  let fail () =
    Js.Promise.reject (Failure ("missing_env:" ^ name))
  in
  {
    ensure_schema = (fun () -> fail ());
    put_session = (fun _ -> fail ());
    get_session = (fun _ -> fail ());
    put_token = (fun _ -> fail ());
    get_token = (fun _ -> fail ());
    consume_token = (fun _ -> fail ());
    put_hold = (fun _ -> fail ());
    count_active_holds = (fun _ _ -> fail ());
    put_ban = (fun _ -> fail ());
    is_banned = (fun _ _ -> fail ());
  }

let of_config (cfg : Interview_config.t) =
  match (cfg.turso_url, cfg.turso_token) with
  | Some url, Some tok -> turso ~url ~token:tok ()
  | None, _ -> unavailable "TURSO_DATABASE_URL"
  | _, None -> unavailable "TURSO_AUTH_TOKEN"
