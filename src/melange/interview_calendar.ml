(* Isolated booking-backend port. create_tentative and delete_event are the
   only side effects. This module knows nothing about which backend is used;
   Interview_calrs builds the production one and tests inject capture(). *)

type request = {
  calendar_id : string;
  summary : string;
  description : string;
  start_iso : string;
  end_iso : string;
  guest_name : string;
  guest_email : string;
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
  (* Does the booking still exist on the backend? A hold cancelled there
     never reaches us, so the cap has to ask. Error means "unknown", and
     callers must treat unknown as still-live rather than free a slot on a
     flaky backend. *)
  event_exists :
    calendar_id:string -> event_id:string -> (bool, string) result Js.Promise.t;
}

let return x = Js.Promise.resolve x

let unused () =
  {
    create_tentative = (fun _ -> return (Error "create_hold is not available"));
    delete_event = (fun ~calendar_id:_ ~event_id:_ -> return (Ok ()));
    event_exists = (fun ~calendar_id:_ ~event_id:_ -> return (Ok true));
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
      event_exists =
        (fun ~calendar_id:_ ~event_id ->
          return
            (Ok (List.exists (fun rec_ -> rec_.event_id = event_id) !created)));
    },
    created )
