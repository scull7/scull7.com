(* Vite config — authored in Melange, invoked via `vite --config` on the
   dune emit. Crawlable inject + Accept negotiation live here. *)

type incoming
type outgoing
type next
type server
type middlewares
type child_result
type vite_plugin

external req_url : incoming -> string Js.undefined = "url" [@@mel.get]
external req_headers : incoming -> string Js.Dict.t = "headers" [@@mel.get]
external set_status : outgoing -> int -> unit = "statusCode" [@@mel.set]

external set_header : outgoing -> string -> string -> unit = "setHeader"
[@@mel.send]

external res_end : outgoing -> string -> unit = "end" [@@mel.send]
external url : string -> string -> < pathname : string > Js.t = "URL" [@@mel.new]
external exec_path : string = "execPath" [@@mel.module "process"]

external spawn_sync :
  string ->
  string array ->
  < cwd : string ; encoding : string > Js.t ->
  < status : int Js.null ; stdout : string ; stderr : string > Js.t
  = "spawnSync"
[@@mel.module "child_process"]

external define_config : 'a -> 'a = "defineConfig" [@@mel.module "vite"]
external elm_plugin : 'a -> vite_plugin = "default" [@@mel.module "vite-plugin-elm"]

external make_crawlable_plugin :
  name:string -> apply:string -> closeBundle:(unit -> unit) -> vite_plugin = ""
[@@mel.obj]

external make_negotiate_plugin :
  name:string ->
  configureServer:(server -> unit) ->
  configurePreviewServer:(server -> unit) ->
  vite_plugin = ""
[@@mel.obj]

external server_middlewares : server -> middlewares = "middlewares" [@@mel.get]

external middlewares_use :
  middlewares ->
  ((incoming -> outgoing -> next -> unit)[@mel.uncurry]) ->
  unit = "use"
[@@mel.send]

external next_ok : next -> unit = "call" [@@mel.send]
external next_err : next -> exn -> unit = "call" [@@mel.send]

external elm_opts : debug:bool -> optimize:bool -> 'a = "" [@@mel.obj]
external resolve_field : alias:string Js.Dict.t -> 'a = "" [@@mel.obj]
external build_field : target:string -> 'a = "" [@@mel.obj]
external fs_field : allow:string array -> 'a = "" [@@mel.obj]
external server_field : fs:'a -> 'b = "" [@@mel.obj]

external vite_opts :
  plugins:vite_plugin array ->
  appType:string ->
  publicDir:string ->
  resolve:'a ->
  build:'b ->
  server:'c ->
  'd = ""
[@@mel.obj]

let root = Node.Process.cwd ()

let crawlable_cli =
  Node.Path.join
    [|
      root;
      "_build/default/src/melange/crawlable/src/melange/crawlable_cli.cjs";
    |]

let env name =
  match Js.Dict.get Node.Process.process##env name with
  | Some v -> v
  | None -> ""

let run_crawlable_cli args label =
  if not (Node.Fs.existsSync crawlable_cli) then
    failwith
      "crawlable Melange CLI missing; run `npm run melange` before `vite build`";
  let result =
    spawn_sync exec_path
      (Array.append [| crawlable_cli |] (Array.of_list args))
      [%mel.obj { cwd = root; encoding = "utf8" }]
  in
  match Js.Null.toOption result##status with
  | Some 0 -> ()
  | Some status ->
      let msg = String.trim (result##stderr ^ result##stdout) in
      failwith (if msg = "" then label ^ " exited " ^ string_of_int status else msg)
  | None -> failwith (label ^ " exited without status")

let inject_crawlable_resume () =
  let html = Node.Path.join2 root "dist/index.html" in
  let md = Node.Path.join2 root "dist/index.md" in
  let resume = Node.Path.join2 root "public/resume.json" in
  run_crawlable_cli [ "inject"; html; resume ] "crawlable inject";
  run_crawlable_cli [ "write-md"; md; resume ] "crawlable write-md"

let crawlable_resume_plugin () =
  make_crawlable_plugin ~name:"crawlable-resume-melange" ~apply:"build"
    ~closeBundle:inject_crawlable_resume

let strip_slash path =
  if String.length path > 0 && path.[0] = '/' then
    String.sub path 1 (String.length path - 1)
  else path

let dist_store dist_dir =
  {
    Handler.has =
      (fun file_path ->
        Node.Fs.existsSync (Node.Path.join2 dist_dir (strip_slash file_path)));
    read =
      (fun file_path ->
        Node.Fs.readFileAsUtf8Sync
          (Node.Path.join2 dist_dir (strip_slash file_path)));
  }

let apply_result res (result : Handler.negotiated) =
  set_status res result.status;
  List.iter (fun (key, value) -> set_header res key value) result.headers;
  res_end res result.body

let accept_of_req req = Js.Dict.get (req_headers req) "accept"

let negotiate_middleware store req res next =
  try
    let raw =
      match Js.Undefined.toOption (req_url req) with
      | Some u -> u
      | None -> "/"
    in
    let pathname = (url raw "http://127.0.0.1")##pathname in
    match
      Handler.negotiate_request ~pathname ~accept:(accept_of_req req) store
    with
    | None -> next_ok next
    | Some result -> apply_result res result
  with exn -> next_err next exn

let markdown_negotiate_plugin root =
  let dist_dir = Node.Path.join2 root "dist" in
  let install server =
    middlewares_use (server_middlewares server)
      (negotiate_middleware (dist_store dist_dir))
  in
  make_negotiate_plugin ~name:"markdown-negotiate"
    ~configureServer:(fun server ->
      if Node.Fs.existsSync dist_dir then install server)
    ~configurePreviewServer:install

let alias =
  let d = Js.Dict.empty () in
  Js.Dict.set d "melange" (Node.Path.resolve root "node_modules/melange");
  Js.Dict.set d "melange.js" (Node.Path.resolve root "node_modules/melange.js");
  d

let default =
  define_config
    (vite_opts
       ~plugins:
         [|
           elm_plugin
             (elm_opts ~debug:false ~optimize:(env "NODE_ENV" = "production"));
           crawlable_resume_plugin ();
           markdown_negotiate_plugin root;
         |]
       ~appType:"mpa" ~publicDir:"public" ~resolve:(resolve_field ~alias)
       ~build:(build_field ~target:"es2020")
       ~server:(server_field ~fs:(fs_field ~allow:[| root |])))
