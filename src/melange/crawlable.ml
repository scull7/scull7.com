(* Pure: Resume_doc.t → crawlable HTML fragment and Markdown. *)

let work_count = 3
let fragment_id = "crawlable-resume"

let split_paragraphs text =
  let lines = String.split_on_char '\n' text in
  let flush acc cur =
    let t = String.trim cur in
    if t = "" then acc else t :: acc
  in
  let acc, cur =
    List.fold_left
      (fun (acc, cur) line ->
        if String.trim line = "" then (flush acc cur, "")
        else
          let next = if cur = "" then line else cur ^ "\n" ^ line in
          (acc, next))
      ([], "")
      lines
  in
  List.rev (flush acc cur)

let contact_hrefs (basics : Resume_doc.basics) =
  let email =
    if Resume_doc.present basics.email then [ "mailto:" ^ basics.email ]
    else []
  in
  let site = if Resume_doc.present basics.url then [ basics.url ] else [] in
  email @ site @ basics.profile_urls

let anchor_label href =
  let prefix = "mailto:" in
  let n = String.length prefix in
  if String.length href >= n && String.sub href 0 n = prefix then
    String.sub href n (String.length href - n)
  else href

let render_contact basics =
  let anchors =
    contact_hrefs basics
    |> List.map (fun href -> Html.anchor href (anchor_label href))
    |> Html.nonempty
  in
  if anchors = [] then "" else Html.wrap "p" (String.concat " " anchors)

let render_basics (basics : Resume_doc.basics) =
  let paras =
    split_paragraphs basics.summary
    |> List.map (fun p -> Html.el "p" p)
  in
  Html.join_lines
    ([ Html.el "h1" basics.name; Html.el "p" basics.label ]
    @ paras
    @ [ render_contact basics ])

let render_dates (job : Resume_doc.job) =
  let times =
    (if job.start_date <> "" then [ Html.el "time" job.start_date ] else [])
    @ if job.end_date <> "" then [ Html.el "time" job.end_date ] else []
  in
  if times = [] then "" else Html.wrap "p" (String.concat " - " times)

let render_highlights items =
  match List.map (fun h -> Html.el "li" h) items |> Html.nonempty with
  | [] -> ""
  | lis -> Html.wrap "ul" (String.concat "" lis)

(* Headings stay plain text. Company URLs are sibling links so H2/H3 are
   never trapped inside <a>. *)
let render_heading (job : Resume_doc.job) = Html.el "h2" job.name

let render_job_url (job : Resume_doc.job) =
  if Resume_doc.present job.url then
    Html.wrap "p" (Html.anchor job.url (anchor_label job.url))
  else ""

let render_job (job : Resume_doc.job) =
  Html.wrap "section"
    (Html.join_lines
       [
         render_heading job;
         Html.el "h3" job.position;
         render_dates job;
         render_job_url job;
         render_highlights job.highlights;
       ])

let take n xs =
  let rec loop n xs acc =
    match (n, xs) with
    | k, _ when k <= 0 -> List.rev acc
    | _, [] -> List.rev acc
    | k, x :: rest -> loop (k - 1) rest (x :: acc)
  in
  loop n xs []

let render_fragment (doc : Resume_doc.t) =
  let jobs = take work_count doc.work |> List.map render_job in
  Html.join_lines (render_basics doc.basics :: jobs)

let wrap_fragment inner =
  "<main id=\"" ^ fragment_id ^ "\">\n" ^ inner ^ "\n    </main>"

(* Backward-compatible alias used by older print callers / docs. *)
let wrap_noscript = wrap_fragment

let inject html inner =
  let wrapped = wrap_fragment inner in
  let main_re =
    [%mel.re
      "/<main\\s+id=[\"']crawlable-resume[\"']\\s*>[\\s\\S]*?<\\/main>/i"]
  in
  let noscript_re =
    [%mel.re
      "/<noscript\\s+id=[\"']crawlable-resume[\"']\\s*>[\\s\\S]*?<\\/noscript>/i"]
  in
  let body_re = [%mel.re "/<\\/body>/i"] in
  if Js.Re.test ~str:html main_re then
    Js.String.replaceByRe ~regexp:main_re ~replacement:wrapped html
  else if Js.Re.test ~str:html noscript_re then
    Js.String.replaceByRe ~regexp:noscript_re ~replacement:wrapped html
  else if Js.Re.test ~str:html body_re then
    Js.String.replaceByRe ~regexp:body_re
      ~replacement:("    " ^ wrapped ^ "\n  </body>")
      html
  else html ^ "\n" ^ wrapped ^ "\n"

(* --- Markdown (same facts as the HTML fragment) ------------------------- *)

let md_escape text = text

let md_heading level text =
  if text = "" then "" else String.make level '#' ^ " " ^ md_escape text

let md_para text = if text = "" then "" else md_escape text

let md_link href label = "[" ^ md_escape label ^ "](" ^ href ^ ")"

let render_md_contact basics =
  let items =
    contact_hrefs basics
    |> List.map (fun href -> "- " ^ md_link href (anchor_label href))
  in
  if items = [] then "" else String.concat "\n" items

let render_md_dates (job : Resume_doc.job) =
  match (job.start_date, job.end_date) with
  | "", "" -> ""
  | start, "" -> start
  | "", finish -> finish
  | start, finish -> start ^ " - " ^ finish

let render_md_job (job : Resume_doc.job) =
  let highlights =
    List.map (fun h -> "- " ^ md_escape h) job.highlights |> Html.nonempty
  in
  Html.join_lines
    [
      md_heading 2 job.name;
      md_heading 3 job.position;
      render_md_dates job;
      (if Resume_doc.present job.url then md_link job.url job.url else "");
      (if highlights = [] then "" else String.concat "\n" highlights);
    ]

let render_markdown (doc : Resume_doc.t) =
  let basics = doc.basics in
  let jobs = take work_count doc.work |> List.map render_md_job in
  let summary = split_paragraphs basics.summary |> List.map md_para in
  Html.join_lines
    ([
       md_heading 1 basics.name;
       md_para basics.label;
     ]
    @ summary
    @ [
        md_heading 2 "Contact";
        render_md_contact basics;
        md_heading 2 "Experience";
      ]
    @ jobs
    @ [ "" ])
