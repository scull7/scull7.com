(* Cited Q&A over resume.json + public site pages. Refuses unpublished facts. *)

type passage = { source : string; path : string; text : string }

type citation = { source : string; path : string; quote : string }

type ask_kind = Cited of citation | Recruiter | Refuse

type ask_hit = {
  kind : ask_kind;
  answer : string;
  completed : string option;
}

type t = { passages : passage list; resume_json : Js.Json.t }

let stopwords =
  [
    "the";
    "a";
    "an";
    "and";
    "or";
    "of";
    "to";
    "in";
    "on";
    "for";
    "is";
    "are";
    "was";
    "were";
    "what";
    "who";
    "how";
    "does";
    "did";
    "nathan";
    "sculli";
    "his";
    "he";
    "him";
    "about";
    "tell";
    "me";
    "please";
    "can";
    "you";
    "your";
    "with";
    "from";
    "that";
    "this";
    "have";
    "has";
    "been";
    "at";
    "as";
    "it";
    "be";
  ]

let is_stop w = List.exists (fun s -> s = w) stopwords

let normalize s =
  s |> String.lowercase_ascii
  |> Js.String.replaceByRe ~regexp:[%mel.re "/[^a-z0-9]+/g"] ~replacement:" "
  |> String.trim

let tokens s =
  normalize s |> String.split_on_char ' '
  |> List.filter (fun t -> String.length t >= 2 && not (is_stop t))

let contains_ci hay needle =
  let h = String.lowercase_ascii hay in
  let n = String.lowercase_ascii needle in
  n <> "" && Js.String.includes ~search:n h

let pattern_parts pattern =
  pattern |> String.split_on_char '|' |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let matches_pattern text pattern =
  List.exists (fun part -> contains_ci text part) (pattern_parts pattern)

let required_item_for (cfg : Interview_config.t) question =
  List.find_opt
    (fun (item : Interview_config.required_item) ->
      matches_pattern question item.pattern)
    cfg.required

let score question_tokens passage =
  let hay = normalize passage.text in
  List.fold_left
    (fun acc tok ->
      if Js.String.includes ~search:tok hay then acc + 1 else acc)
    0 question_tokens

let clip text =
  let t = String.trim text in
  if String.length t <= 400 then t else String.sub t 0 397 ^ "..."

let present s = String.trim s <> ""

let passage source path text =
  if present text then Some { source; path; text = String.trim text } else None

let cons_opt x xs = match x with None -> xs | Some v -> v :: xs

let decode_job_passages index json =
  match Interview_json.as_object json with
  | None -> []
  | Some dict ->
      let name = Interview_json.string_field dict "name" in
      let position = Interview_json.string_field dict "position" in
      let summary = Interview_json.string_field dict "summary" in
      let description = Interview_json.string_field dict "description" in
      let prefix = "work[" ^ string_of_int index ^ "]" in
      let highlights =
        Interview_json.string_list (Interview_json.field dict "highlights")
        |> List.mapi (fun i h ->
               passage "/resume.json"
                 (prefix ^ ".highlights[" ^ string_of_int i ^ "]")
                 h)
        |> List.filter_map (fun x -> x)
      in
      let blob =
        String.concat " "
          (List.filter present [ name; position; summary; description ])
      in
      cons_opt
        (passage "/resume.json" prefix blob)
        highlights

let decode_project_passages index json =
  match Interview_json.as_object json with
  | None -> []
  | Some dict ->
      let name = Interview_json.string_field dict "name" in
      let description = Interview_json.string_field dict "description" in
      let prefix = "projects[" ^ string_of_int index ^ "]" in
      cons_opt
        (passage "/resume.json" prefix (String.concat " " [ name; description ]))
        []

let decode_skill_passages index json =
  match Interview_json.as_object json with
  | None -> []
  | Some dict ->
      let name = Interview_json.string_field dict "name" in
      let keywords =
        String.concat ", "
          (Interview_json.string_list (Interview_json.field dict "keywords"))
      in
      cons_opt
        (passage "/resume.json"
           ("skills[" ^ string_of_int index ^ "]")
           (name ^ " " ^ keywords))
        []

let of_resume_json json =
  match Interview_json.as_object json with
  | None -> { passages = []; resume_json = json }
  | Some dict ->
      let basics = Interview_json.object_field dict "basics" in
      let work =
        Interview_json.as_array (Interview_json.field dict "work")
        |> Array.to_list
        |> List.mapi decode_job_passages
        |> List.concat
      in
      let projects =
        Interview_json.as_array (Interview_json.field dict "projects")
        |> Array.to_list
        |> List.mapi decode_project_passages
        |> List.concat
      in
      let skills =
        Interview_json.as_array (Interview_json.field dict "skills")
        |> Array.to_list
        |> List.mapi decode_skill_passages
        |> List.concat
      in
      let basics_passages =
        [
          passage "/resume.json" "basics.summary"
            (Interview_json.string_field basics "summary");
          passage "/resume.json" "basics.label"
            (Interview_json.string_field basics "label");
          passage "/resume.json" "basics.name"
            (Interview_json.string_field basics "name");
        ]
        |> List.filter_map (fun x -> x)
      in
      {
        passages = basics_passages @ work @ projects @ skills;
        resume_json = json;
      }

let add_page corpus source body =
  let text = String.trim body in
  if text = "" then corpus
  else
    {
      corpus with
      passages = corpus.passages @ [ { source; path = source; text } ];
    }

let of_pages ~resume_json pages =
  List.fold_left
    (fun corpus (source, body) -> add_page corpus source body)
    (of_resume_json resume_json) pages

let refuse_text =
  "That fact is not published on scull7.com. Answers are cited from \
   /resume.json and public site pages only. I will not invent career facts."

let best_passage corpus question =
  let qtoks = tokens question in
  if qtoks = [] then None
  else
    let ranked =
      corpus.passages
      |> List.map (fun p -> (score qtoks p, p))
      |> List.filter (fun (s, _) -> s > 0)
      |> List.sort (fun (a, _) (b, _) -> compare b a)
    in
    match ranked with
    | (s, p) :: _ when s >= 2 -> Some p
    | (1, p) :: _ ->
        let strong =
          List.exists
            (fun tok ->
              String.length tok >= 5
              || tok = "rust"
              || tok = "relay"
              || tok = "gpu")
            qtoks
        in
        if strong && contains_ci p.text (List.hd qtoks) then Some p
        else if
          List.exists
            (fun tok ->
              contains_ci p.text tok
              && (tok = "tensorwave" || tok = "relay" || tok = "rust"
                 || tok = "influential" || tok = "allegiant"))
            qtoks
        then Some p
        else None
    | _ -> None

let wants_next_passage passage =
  matches_pattern passage.text
    "want next|wants next|looking for|seeking|next role|open to opportunities|open to roles"

let cited_answer passage =
  let quote = clip passage.text in
  let citation = { source = passage.source; path = passage.path; quote } in
  let answer =
    quote ^ "\n\nSource: " ^ passage.source
    ^ (if passage.path = passage.source then "" else " (" ^ passage.path ^ ")")
  in
  (answer, citation)

let ask (cfg : Interview_config.t) corpus question =
  let q = String.trim question in
  match required_item_for cfg q with
  | Some item when item.kind = "recruiter" ->
      {
        kind = Recruiter;
        answer =
          "Recorded your hiring timeline (recruiter fact, not a resume \
           citation): " ^ q;
        completed = Some item.id;
      }
  | Some item when item.id = "wants_next" -> (
      match
        List.find_opt wants_next_passage corpus.passages
      with
      | None ->
          {
            kind = Refuse;
            answer = refuse_text;
            completed = None;
          }
      | Some passage ->
          if not (matches_pattern q item.pattern) then
            {
              kind = Refuse;
              answer = refuse_text;
              completed = None;
            }
          else
            let answer, citation = cited_answer passage in
            {
              kind = Cited citation;
              answer;
              completed = Some item.id;
            })
  | required -> (
      match best_passage corpus q with
      | None -> { kind = Refuse; answer = refuse_text; completed = None }
      | Some passage ->
          let answer, citation = cited_answer passage in
          let completed =
            match required with
            | Some item when item.kind = "cited" -> Some item.id
            | _ -> None
          in
          { kind = Cited citation; answer; completed })

let search corpus query =
  match best_passage corpus query with
  | None -> []
  | Some first ->
      let qtoks = tokens query in
      corpus.passages
      |> List.map (fun p -> (score qtoks p, p))
      |> List.filter (fun (s, _) -> s >= 2)
      |> List.sort (fun (a, _) (b, _) -> compare b a)
      |> fun ranked ->
      (if ranked = [] then [ (2, first) ] else ranked)
      |> List.map snd
      |> fun xs ->
      let rec take n acc = function
        | [] -> List.rev acc
        | _ when n <= 0 -> List.rev acc
        | h :: t -> take (n - 1) (h :: acc) t
      in
      take 8 [] xs

let citation_json (c : citation) =
  Interview_json.obj
    [
      ("source", Interview_json.str c.source);
      ("path", Interview_json.str c.path);
      ("quote", Interview_json.str c.quote);
    ]
