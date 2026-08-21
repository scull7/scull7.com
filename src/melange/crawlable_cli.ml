(* Actions: read resume.json, write crawlable HTML. Calculations live in
   Resume_doc / Crawlable. *)

external read_utf8 : string -> string -> string = "readFileSync"
[@@mel.module "fs"]

external write_utf8 : string -> string -> string -> unit = "writeFileSync"
[@@mel.module "fs"]

external stdout_write : string -> unit = "write"
[@@mel.scope ("process", "stdout")]

external eprint : string -> unit = "error" [@@mel.scope "console"]

let fail msg =
  eprint msg;
  Node.Process.exit 1

let read_file path =
  try read_utf8 path "utf8"
  with _ -> fail ("crawlable-resume: cannot read " ^ path)

let write_file path body =
  try write_utf8 path body "utf8"
  with _ -> fail ("crawlable-resume: cannot write " ^ path)

let parse_resume path =
  let raw = read_file path in
  try Resume_doc.of_json (Js.Json.parseExn raw)
  with _ -> fail ("crawlable-resume: invalid JSON in " ^ path)

let fragment_from resume_path =
  parse_resume resume_path |> Crawlable.render_fragment

let default_resume cwd = Node.Path.join2 cwd "public/resume.json"
let default_html cwd = Node.Path.join2 cwd "dist/index.html"

let print_fragment resume_path =
  let inner = fragment_from resume_path in
  stdout_write (Crawlable.wrap_noscript inner ^ "\n")

let inject_file html_path resume_path =
  let inner = fragment_from resume_path in
  let html = read_file html_path in
  write_file html_path (Crawlable.inject html inner)

let usage () =
  fail
    "usage: crawlable_cli.js [print] [resume.json]\n\
     or:    crawlable_cli.js inject [dist/index.html] [public/resume.json]"

let nth argv i = if Array.length argv > i then Some argv.(i) else None

let () =
  let argv = Node.Process.argv in
  let cwd = Node.Process.cwd () in
  match nth argv 2 with
  | None | Some "print" ->
      let resume =
        match nth argv 3 with
        | Some path -> path
        | None -> default_resume cwd
      in
      print_fragment resume
  | Some "inject" ->
      let html =
        match nth argv 3 with
        | Some path -> path
        | None -> default_html cwd
      in
      let resume =
        match nth argv 4 with
        | Some path -> path
        | None -> default_resume cwd
      in
      inject_file html resume
  | Some _ -> usage ()
