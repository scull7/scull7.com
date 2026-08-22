(* Map request paths to HTML / Markdown siblings and decide passthrough. *)

external decode_uri_component : string -> string = "decodeURIComponent"

let static_ext =
  [%mel.re
    "/\\.(?:css|js|mjs|map|png|jpe?g|webp|gif|svg|avif|ico|woff2?|ttf|otf|eot|xml|txt|json|pdf|mp4|webm|mp3|wav|ogg|zip|wasm)$/i"]

let rec rtrim_slashes s =
  let n = String.length s in
  if n > 0 && s.[n - 1] = '/' then rtrim_slashes (String.sub s 0 (n - 1))
  else s

let before_delim s delim =
  match String.index_opt s delim with
  | None -> s
  | Some i -> String.sub s 0 i

let normalize_path pathname =
  if pathname = "" then "/"
  else
    try
      let decoded = decode_uri_component pathname in
      let clean = decoded |> fun s -> before_delim s '?' |> fun s -> before_delim s '#' in
      if clean = "" || clean = "/" then "/"
      else
        let trimmed = rtrim_slashes clean in
        if trimmed = "" then "/" else trimmed
    with _ -> if pathname = "" then "/" else pathname

let last_segment clean =
  match List.rev (String.split_on_char '/' clean) with
  | [] -> ""
  | last :: _ -> last

(* Assets and already-negotiated files skip Accept handling. *)
let is_passthrough_path pathname =
  let clean = normalize_path pathname in
  if clean = "/" then false
  else
    let last = last_segment clean in
    if not (String.contains last '.') then false
    else if Js.Re.test ~str:last [%mel.re "/\\.html?$/i"] then false
    else Js.Re.test ~str:last static_ext || String.ends_with ~suffix:".md" last

let html_candidates pathname =
  let clean = normalize_path pathname in
  if clean = "/" then [ "/index.html" ]
  else [ clean ^ ".html"; clean ^ "/index.html" ]

let markdown_candidates pathname =
  let clean = normalize_path pathname in
  if clean = "/" then [ "/index.md" ]
  else [ clean ^ ".md"; clean ^ "/index.md" ]

let is_not_found_probe pathname =
  let clean = normalize_path pathname in
  clean = "/__missing_agentic_404__" || String.starts_with ~prefix:"/__missing" clean
