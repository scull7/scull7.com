(* Isolated booking-backend (calendar) port. create_tentative and
   delete_event are the only side effects. Tests inject capture() so no live
   backend is used. *)

type request = {
  calendar_id : string;
  summary : string;
  description : string;
  start_iso : string;
  end_iso : string;
}

type created = {
  calendar_id : string;
  event_id : string;
  html_link : string;
  start_iso : string;
  end_iso : string;
}

type t = {
  create_tentative : request -> (created, string) result Js.Promise.t;
  delete_event :
    calendar_id:string ->
    event_id:string ->
    (unit, string) result Js.Promise.t;
}

let ( >>= ) p f = Js.Promise.then_ f p
let return x = Js.Promise.resolve x

let unused () =
  {
    create_tentative =
      (fun _ -> return (Error "create_hold is not available"));
    delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
  }

let capture () =
  let created = ref [] in
  ( {
      create_tentative =
        (fun req ->
          let event_id = "evt_" ^ Interview_clock.random_id () in
          let event =
            {
              calendar_id = req.calendar_id;
              event_id;
              html_link = "https://scull7.com/interview/holds/" ^ event_id;
              start_iso = req.start_iso;
              end_iso = req.end_iso;
            }
          in
          created := event :: !created;
          return (Ok event));
      delete_event =
        (fun ~calendar_id:_ ~event_id ->
          created :=
            List.filter (fun rec_ -> rec_.event_id <> event_id) !created;
          return (Ok ()));
    },
    created )

let of_config (cfg : Interview_config.t) =
  match cfg.cal_api_url with
  | None ->
      {
        create_tentative =
          (fun _ -> return (Error "missing_env:INTERVIEW_CAL_API_URL"));
        delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
      }
  | Some _ ->
      (* cal.rs (Rust service on Vultr) API does not exist yet; wiring it is a
         later card. Until then the port stays fail-closed: no fetch, no
         localhost, no Ok created. *)
      {
        create_tentative =
          (fun _ -> return (Error "cal_api_not_wired"));
        delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
      }
