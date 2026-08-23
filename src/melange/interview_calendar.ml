(* Isolated calendar action. T-17 never creates events; create_hold stays
   fail-closed. Tests inject capture() to prove no event is created. *)

type created = {
  calendar_id : string;
  event_id : string;
  html_link : string;
}

type request = {
  calendar_id : string;
  summary : string;
  start_iso : string;
  end_iso : string;
}

type t = { create_tentative : request -> (created, string) result Js.Promise.t }

let return x = Js.Promise.resolve x

let unused () =
  { create_tentative = (fun _ -> return (Error "create_hold is not available")) }

let capture () =
  let created = ref [] in
  ( {
      create_tentative =
        (fun req ->
          let event =
            {
              calendar_id = req.calendar_id;
              event_id = "evt_unused";
              html_link = "https://calendar.example/unused";
            }
          in
          created := event :: !created;
          return (Ok event));
    },
    created )
