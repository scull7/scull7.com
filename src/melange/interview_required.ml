(* Required-set matching is a calculation over session progress + config.
   Refuses do not count. Completeness is remaining = []. *)

let default_ids =
  [ "current_work"; "leadership"; "systems"; "wants_next"; "hiring_timeline" ]

type progress = {
  completed : string list;
  hiring_timeline : string option;
}

type snapshot = {
  progress : progress;
  required_progress : string list;
  required_remaining : string list;
}

type classification =
  | Record_timeline of string
  | Echo_timeline of string
  | Refuse_timeline
  | Ask_corpus

let known id = List.exists (fun d -> d = id) default_ids

let split_csv raw =
  raw |> String.split_on_char ',' |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let ids_of_json text =
  try
    Interview_json.as_array (Interview_json.json_parse text)
    |> Array.to_list
    |> List.filter_map (fun json ->
           match Interview_json.as_object json with
           | Some dict ->
               let id =
                 Interview_json.string_field dict "id" |> String.trim
               in
               if id = "" then None else Some id
           | None ->
               let id = String.trim (Interview_json.as_string json) in
               if id = "" then None else Some id)
  with _ -> []

let parse = function
  | None -> default_ids
  | Some raw ->
      let trimmed = String.trim raw in
      if trimmed = "" then default_ids
      else
        let ids =
          if String.starts_with ~prefix:"[" trimmed then ids_of_json trimmed
          else split_csv trimmed
        in
        let known_ids = List.filter known ids in
        if known_ids = [] then default_ids else known_ids

let mem id xs = List.exists (fun x -> x = id) xs

let add id xs = if mem id xs then xs else xs @ [ id ]

let required_progress required completed =
  List.filter (fun id -> mem id completed) required

let remaining required completed =
  List.filter (fun id -> not (mem id completed)) required

let snapshot required (progress : progress) =
  let required_progress = required_progress required progress.completed in
  {
    progress;
    required_progress;
    required_remaining = remaining required required_progress;
  }

let just_completed ~before ~after =
  before.required_remaining <> [] && after.required_remaining = []

let cited_id_of_topic = function
  | Interview_corpus.Current_work -> Some "current_work"
  | Interview_corpus.Leadership -> Some "leadership"
  | Interview_corpus.Systems -> Some "systems"
  | Interview_corpus.Wants_next -> Some "wants_next"
  | Interview_corpus.General -> None

let cited_id_of_question question =
  cited_id_of_topic (Interview_corpus.topic_of_question question)

let is_recruiter_statement question =
  Interview_corpus.matches_pattern question
    "we need|our timeline|our hiring|need someone|start by|start date|hiring by|hire by|looking to fill|we're hiring"

let is_timeline_query question =
  Interview_corpus.matches_pattern question "hiring timeline|timeline"

let classify ~progress ~question =
  if is_recruiter_statement question then Record_timeline question
  else if is_timeline_query question then
    match progress.hiring_timeline with
    | Some words -> Echo_timeline words
    | None -> Refuse_timeline
  else Ask_corpus

let apply ~required ~progress = function
  | Record_timeline words ->
      let completed =
        if mem "hiring_timeline" required then
          add "hiring_timeline" progress.completed
        else progress.completed
      in
      snapshot required { completed; hiring_timeline = Some words }
  | Echo_timeline _ -> snapshot required progress
  | Refuse_timeline -> snapshot required progress
  | Ask_corpus -> snapshot required progress

let apply_cited ~required ~progress ~question =
  match cited_id_of_question question with
  | Some id when mem id required ->
      snapshot required
        { progress with completed = add id progress.completed }
  | _ -> snapshot required progress

let string_array xs = Interview_json.arr (List.map Interview_json.str xs)

let timeline_record_answer words =
  "Recorded your hiring timeline (recruiter fact, not a resume citation): "
  ^ words

let timeline_echo_answer words =
  "Hiring timeline previously stated by the recruiter (their words, not a \
   resume citation): " ^ words
