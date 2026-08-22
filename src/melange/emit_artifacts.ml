(* Copy Melange-emitted Netlify edge files and bundle the interview function.
   Edge can re-export: Deno resolves `melange.js` from the project.
   The Node function cannot — Lambda 502s on `import from "melange.js"`
   unless emit inlines that runtime. No hand-authored JS. *)

external mkdir_sync : string -> < recursive : bool > Js.t -> unit
  = "mkdirSync"
[@@mel.module "fs"]

external copy_file_sync : string -> string -> unit = "copyFileSync"
[@@mel.module "fs"]

external rm_sync : string -> < recursive : bool ; force : bool > Js.t -> unit
  = "rmSync"
[@@mel.module "fs"]

external chmod_sync : string -> int -> unit = "chmodSync" [@@mel.module "fs"]

external stat_sync :
  string ->
  < isDirectory : (unit -> bool[@mel.meth])
  ; isFile : (unit -> bool[@mel.meth]) >
  Js.t = "statSync"
[@@mel.module "fs"]

external spawn_sync :
  string ->
  string array ->
  < cwd : string ; encoding : string > Js.t ->
  < status : int Js.null ; stdout : string ; stderr : string > Js.t
  = "spawnSync"
[@@mel.module "child_process"]

external console_log : string -> unit = "log" [@@mel.scope "console"]

let cwd = Node.Process.cwd ()

let edge_src =
  Node.Path.join [| cwd; "_build/default/src/melange/edge/src/melange" |]

let edge_dest = Node.Path.join [| cwd; "netlify/edge-functions" |]
let edge_gen = Node.Path.join2 edge_dest "_melange"

let rec copy_tree src dest =
  mkdir_sync dest [%mel.obj { recursive = true }];
  Array.iter
    (fun name ->
      if name = "." || name = ".." then ()
      else
        let from = Node.Path.join2 src name in
        let toward = Node.Path.join2 dest name in
        let st = stat_sync from in
        if st##isDirectory () then copy_tree from toward
        else if st##isFile () then (
          copy_file_sync from toward;
          chmod_sync toward 0o644))
    (Node.Fs.readdirSync src)

let write_negotiate_wrapper () =
  let body =
    "export { config, default } from \"./_melange/negotiate_edge.js\";\n"
  in
  Node.Fs.writeFileAsUtf8Sync (Node.Path.join2 edge_dest "negotiate.js") body

let fn_src =
  Node.Path.join [| cwd; "_build/default/src/melange/functions/src/melange" |]

let fn_dest = Node.Path.join [| cwd; "netlify/functions" |]
let fn_gen = Node.Path.join2 fn_dest "_melange"
let fn_corpus = Node.Path.join2 fn_dest "_corpus"
let interview_entry = Node.Path.join2 fn_src "interview_fn.js"
let interview_out = Node.Path.join2 fn_dest "interview.js"

let first_existing paths =
  let rec loop = function
    | [] -> None
    | p :: rest -> if Node.Fs.existsSync p then Some p else loop rest
  in
  loop paths

let status_of result =
  match Js.Null.toOption result##status with Some s -> s | None -> -1

let esbuild_bin () =
  match
    first_existing
      [
        Node.Path.join [| cwd; "node_modules/esbuild/bin/esbuild" |];
        Node.Path.join
          [| cwd; "node_modules/vite/node_modules/esbuild/bin/esbuild" |];
      ]
  with
  | Some p -> p
  | None ->
      Js.Console.error
        "emit-artifacts: esbuild binary not found (required to bundle interview \
         for Netlify Lambda)";
      Node.Process.exit 1

let banned_import_needles =
  [
    "from \"melange.js";
    "from 'melange.js";
    "from \"melange/";
    "from 'melange/";
    "from\"melange.js";
    "from'melange.js";
    "from\"melange/";
    "from'melange/";
  ]

let assert_self_contained path =
  let body = Node.Fs.readFileAsUtf8Sync path in
  List.iter
    (fun needle ->
      if Js.String.includes ~search:needle body then (
        Js.Console.error
          ("emit-artifacts: bundled interview still imports Melange runtime ("
         ^ needle ^ ")");
        Node.Process.exit 1))
    banned_import_needles;
  if
    not
      (Js.String.includes ~search:"export" body
      && Js.String.includes ~search:"config" body)
  then (
    Js.Console.error
      "emit-artifacts: bundled interview is missing an exported config";
    Node.Process.exit 1)

let bundle_interview () =
  if not (Node.Fs.existsSync interview_entry) then (
    Js.Console.error
      ("emit-artifacts: missing interview entry at " ^ interview_entry);
    Node.Process.exit 1);
  mkdir_sync fn_dest [%mel.obj { recursive = true }];
  if Node.Fs.existsSync fn_gen then
    rm_sync fn_gen [%mel.obj { recursive = true; force = true }];
  let bin = esbuild_bin () in
  let result =
    spawn_sync bin
      [|
        interview_entry;
        "--bundle";
        "--format=esm";
        "--platform=node";
        "--packages=bundle";
        "--outfile=" ^ interview_out;
      |]
      [%mel.obj { cwd; encoding = "utf8" }]
  in
  let status = status_of result in
  if status <> 0 then (
    if String.trim result##stderr <> "" then
      Js.Console.error result##stderr;
    if String.trim result##stdout <> "" then
      Js.Console.error result##stdout;
    Js.Console.error
      ("emit-artifacts: esbuild interview bundle failed ("
     ^ string_of_int status ^ ")");
    Node.Process.exit 1);
  if not (Node.Fs.existsSync interview_out) then (
    Js.Console.error
      ("emit-artifacts: esbuild did not write " ^ interview_out);
    Node.Process.exit 1);
  chmod_sync interview_out 0o644;
  assert_self_contained interview_out

let corpus_names =
  [ "resume.json"; "about.md"; "contact.md"; "llms.txt"; "llms-full.txt" ]

let copy_corpus () =
  mkdir_sync fn_corpus [%mel.obj { recursive = true }];
  List.iter
    (fun name ->
      let from = Node.Path.join [| cwd; "public"; name |] in
      if Node.Fs.existsSync from then (
        let toward = Node.Path.join2 fn_corpus name in
        copy_file_sync from toward;
        chmod_sync toward 0o644))
    corpus_names

let () =
  if not (Node.Fs.existsSync edge_src) then (
    Js.Console.error ("emit-artifacts: missing edge emit at " ^ edge_src);
    Node.Process.exit 1);
  if not (Node.Fs.existsSync fn_src) then (
    Js.Console.error
      ("emit-artifacts: missing functions emit at " ^ fn_src);
    Node.Process.exit 1);
  mkdir_sync edge_dest [%mel.obj { recursive = true }];
  if Node.Fs.existsSync edge_gen then
    rm_sync edge_gen [%mel.obj { recursive = true; force = true }];
  copy_tree edge_src edge_gen;
  write_negotiate_wrapper ();
  console_log
    ("emit-artifacts: wrote " ^ Node.Path.join2 edge_dest "negotiate.js");
  bundle_interview ();
  copy_corpus ();
  console_log ("emit-artifacts: wrote self-contained " ^ interview_out)
