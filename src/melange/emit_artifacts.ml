(* Copy Melange-emitted Netlify edge files into netlify/edge-functions/.
   The hand-authored source of truth is negotiate_edge.ml. *)

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

let () =
  if not (Node.Fs.existsSync edge_src) then (
    Js.Console.error
      ("emit-artifacts: missing edge emit at " ^ edge_src);
    Node.Process.exit 1);
  mkdir_sync edge_dest [%mel.obj { recursive = true }];
  if Node.Fs.existsSync edge_gen then
    rm_sync edge_gen [%mel.obj { recursive = true; force = true }];
  copy_tree edge_src edge_gen;
  write_negotiate_wrapper ();
  console_log
    ("emit-artifacts: wrote " ^ Node.Path.join2 edge_dest "negotiate.js")
