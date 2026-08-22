(* Transactional mail. Smallest real path: Resend HTTP. Tests capture. *)

type message = {
  to_ : string;
  from_ : string;
  subject : string;
  text : string;
  html : string;
}

type t = { send : message -> (string, string) result Js.Promise.t }

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let capture () =
  let sent = ref [] in
  ( {
      send =
        (fun m ->
          sent := m :: !sent;
          return (Ok "captured"));
    },
    sent )

let failing ?(message = "mail failed") () =
  { send = (fun _ -> return (Error message)) }

let resend api_key =
  {
    send =
      (fun m ->
        let headers = Js.Dict.empty () in
        Js.Dict.set headers "Authorization" ("Bearer " ^ api_key);
        Js.Dict.set headers "Content-Type" "application/json";
        let body =
          Interview_json.json_stringify
            (Interview_json.obj
               [
                 ("from", Interview_json.str m.from_);
                 ("to", Interview_json.arr [ Interview_json.str m.to_ ]);
                 ("subject", Interview_json.str m.subject);
                 ("text", Interview_json.str m.text);
                 ("html", Interview_json.str m.html);
               ])
        in
        Interview_http_fetch.post "https://api.resend.com/emails" ~headers ~body
        >>= fun res ->
        Interview_http_fetch.response_text res >>= fun text ->
        if Interview_http_fetch.response_ok res then return (Ok text)
        else
          return
            (Error
               ("resend "
               ^ string_of_int (Interview_http_fetch.response_status res)
               ^ ": " ^ text)));
  }

let of_config (cfg : Interview_config.t) =
  match cfg.resend_api_key with
  | Some key -> resend key
  | None ->
      {
        send =
          (fun _ ->
            return
              (Error
                 "missing_env:RESEND_API_KEY (or INTERVIEW_RESEND_API_KEY)"));
      }
