(* RFC 9110 Accept parsing for HTML vs Markdown negotiation.
   Shared by the Netlify edge function, Vite preview middleware, and tests. *)

type accept_entry = { type_ : string; q : float; specificity : int }

let html_type = "text/html"
let markdown_type = "text/markdown"
let produces = [ html_type; markdown_type ]

let parse_q value =
  try
    let parsed = float_of_string value in
    if parsed <> parsed then 1. else max 0. (min 1. parsed)
  with _ -> 1.

let parse_accept header =
  header |> String.split_on_char ','
  |> List.filter_map (fun raw ->
         let parts =
           raw |> String.split_on_char ';' |> List.map String.trim
           |> List.filter (fun s -> s <> "")
         in
         match parts with
         | [] -> None
         | type_raw :: rest ->
             let type_ = String.lowercase_ascii type_raw in
             if type_ = "" then None
             else
               let q =
                 List.fold_left
                   (fun q param ->
                     match String.index_opt param '=' with
                     | None -> q
                     | Some eq ->
                         let name =
                           String.lowercase_ascii
                             (String.trim (String.sub param 0 eq))
                         in
                         let value =
                           String.trim
                             (String.sub param (eq + 1)
                                (String.length param - eq - 1))
                         in
                         if name = "q" then parse_q value else q)
                   1. rest
               in
               let specificity =
                 if type_ = "*/*" then 0
                 else if String.ends_with ~suffix:"/*" type_ then 1
                 else 2
               in
               Some { type_; q; specificity })

let matches entry candidate =
  if entry.type_ = "*/*" then true
  else if String.ends_with ~suffix:"/*" entry.type_ then
    let prefix =
      String.sub entry.type_ 0 (String.length entry.type_ - 1)
    in
    String.starts_with ~prefix candidate
  else entry.type_ = candidate

(* Pick the best of `produces` for this Accept header.
   Missing / blank Accept -> produces[0] (HTML). A catch-all Accept also
   prefers produces[0] when q-values tie, so ordinary browsers are never 406'd. *)
let preferred_type header produces =
  match produces with
  | [] -> None
  | first :: _ -> (
      match header with
      | None -> Some first
      | Some h when String.trim h = "" -> Some first
      | Some h ->
          let entries = parse_accept h in
          if entries = [] then Some first
          else
            let indexed = List.mapi (fun i e -> (i, e)) entries in
            let best_type, _best_q, _best_pos =
              List.fold_left
                (fun (best_type, best_q, best_pos) candidate ->
                  let matched =
                    List.fold_left
                      (fun acc (idx, entry) ->
                        if not (matches entry candidate) then acc
                        else
                          match acc with
                          | None -> Some (entry, idx)
                          | Some (prev, prev_idx) ->
                              if
                                entry.specificity > prev.specificity
                                || entry.specificity = prev.specificity
                                   && idx < prev_idx
                              then Some (entry, idx)
                              else acc)
                      None indexed
                  in
                  match matched with
                  | None -> (best_type, best_q, best_pos)
                  | Some (entry, _) when entry.q <= 0. ->
                      (best_type, best_q, best_pos)
                  | Some (entry, idx)
                    when entry.q > best_q || (entry.q = best_q && idx < best_pos)
                    ->
                      (Some candidate, entry.q, idx)
                  | Some _ -> (best_type, best_q, best_pos))
                (None, -1., max_int) produces
            in
            best_type)

let vary_accept_value existing =
  match existing with
  | None | Some "" -> "Accept, Accept-Encoding"
  | Some existing ->
      let tokens =
        existing |> String.split_on_char ','
        |> List.map (fun s -> String.lowercase_ascii (String.trim s))
      in
      let parts =
        existing |> String.split_on_char ',' |> List.map String.trim
        |> List.filter (fun s -> s <> "")
      in
      let parts =
        if List.mem "accept" tokens then parts else "Accept" :: parts
      in
      let parts =
        if List.mem "accept-encoding" tokens then parts
        else parts @ [ "Accept-Encoding" ]
      in
      String.concat ", " parts

let not_acceptable_body requested =
  let lines =
    [
      "Not Acceptable";
      "";
      "This resource is available in:";
      "- text/html";
      "- text/markdown";
      (if requested = "" then "" else "");
      (if requested = "" then "" else "You requested: " ^ requested);
      "";
    ]
  in
  let rec filter i prev acc = function
    | [] -> List.rev acc
    | line :: rest ->
        let keep = line <> "" || (i > 0 && prev <> "") in
        if keep then filter (i + 1) line (line :: acc) rest
        else filter (i + 1) line acc rest
  in
  String.concat "\n" (filter 0 "" [] lines)
