(* Isolated webhook POST. interview.completed only — this card never
   sends booking.requested. Tests inject capture / failing. *)

type sent = { url : string; body : string }

type t = { post : string -> string -> (unit, string) result Js.Promise.t }

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let capture () =
  let sent = ref [] in
  ( {
      post =
        (fun url body ->
          sent := { url; body } :: !sent;
          return (Ok ()));
    },
    sent )

let failing ?(message = "webhook failed") () =
  { post = (fun _ _ -> return (Error message)) }

let capture_failing ?(message = "webhook failed") () =
  let sent = ref [] in
  ( {
      post =
        (fun url body ->
          sent := { url; body } :: !sent;
          return (Error message));
    },
    sent )

let unused () = { post = (fun _ _ -> return (Ok ())) }

let http () =
  {
    post =
      (fun url body ->
        let headers = Js.Dict.empty () in
        Js.Dict.set headers "Content-Type" "application/json";
        Interview_http_fetch.post url ~headers ~body >>= fun res ->
        if Interview_http_fetch.response_ok res then return (Ok ())
        else
          return
            (Error
               ("webhook "
               ^ string_of_int (Interview_http_fetch.response_status res))));
  }

let interview_completed_body ~session ~required_progress ~required_remaining =
  let (s : Interview_store.session) = session in
  Interview_json.obj
    [
      ("event", Interview_json.str "interview.completed");
      ( "payload",
        Interview_json.obj
          ([
             ("session_id", Interview_json.str s.id);
             ("company", Interview_json.str s.company);
             ("role", Interview_json.str s.role);
             ("recruiter_name", Interview_json.str s.recruiter_name);
             ("work_email", Interview_json.str s.work_email);
             ( "required_progress",
               Interview_required.string_array required_progress );
             ( "required_remaining",
               Interview_required.string_array required_remaining );
           ]
          @
          match s.callback_url with
          | Some u -> [ ("callback_url", Interview_json.str u) ]
          | None -> []) );
    ]
