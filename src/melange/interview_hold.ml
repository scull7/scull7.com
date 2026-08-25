(* Hold-cap and default-end calculations. Isolated from the calendar port, mail, and
   webhook actions — those stay in their modules. *)

let default_cap = 3
let default_seconds = 3600

let parse_cap raw =
  max 1
    (match raw with
    | None -> default_cap
    | Some s -> ( try int_of_string (String.trim s) with _ -> default_cap))

let parse_seconds raw =
  max 60
    (match raw with
    | None -> default_seconds
    | Some s -> ( try int_of_string (String.trim s) with _ -> default_seconds))

let resolve_end ~start_iso ~end_ ~default_seconds =
  match end_ with
  | Some e when String.trim e <> "" -> String.trim e
  | _ ->
      Interview_clock.iso_of_ms
        (Interview_token.ms_of_iso start_iso
        +. (float_of_int default_seconds *. 1000.))

let at_or_over_cap ~active ~cap = active >= cap

let is_active ~status ~end_at ~now_iso =
  status = "tentative" && end_at > now_iso
