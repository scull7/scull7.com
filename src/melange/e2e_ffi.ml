(* Shared Node/preview helpers for Melange e2e runners. *)

type child
type readable
type response
type headers

external exec_path : string = "execPath" [@@mel.module "process"]
external process : < > Js.t = "process"
external process_get : < > Js.t -> string -> int Js.undefined = ""
[@@mel.get_index]
external process_set : < > Js.t -> string -> int -> unit = ""
[@@mel.set_index]

let exit_code () = process_get process "exitCode"
let set_exit_code n = process_set process "exitCode" n
external process_kill : int -> string -> unit = "kill" [@@mel.module "process"]

external set_timeout : (unit -> unit) -> int -> unit = "setTimeout"
[@@mel.scope "globalThis"]

external set_timeout_handle :
  (unit -> unit) -> int -> < unref : unit -> 'a [@mel.meth] > Js.t
  = "setTimeout"
[@@mel.scope "globalThis"]

external stdout_write : 'a -> unit = "write" [@@mel.scope ("process", "stdout")]
external stderr_write : 'a -> unit = "write" [@@mel.scope ("process", "stderr")]
external console_log : string -> unit = "log" [@@mel.scope "console"]
external console_error : string -> unit = "error" [@@mel.scope "console"]

external spawn :
  string ->
  string array ->
  < cwd : string ; stdio : string array ; env : string Js.Dict.t > Js.t ->
  child = "spawn"
[@@mel.module "child_process"]

external spawn_sync :
  string ->
  string array ->
  'opts ->
  < status : int Js.null ; stdout : string ; stderr : string > Js.t
  = "spawnSync"
[@@mel.module "child_process"]

external child_pid : child -> int Js.undefined = "pid" [@@mel.get]
external child_kill : child -> string -> unit = "kill" [@@mel.send]
external child_stdout : child -> readable = "stdout" [@@mel.get]
external child_stderr : child -> readable = "stderr" [@@mel.get]
external child_on : child -> string -> ('a -> unit) -> unit = "on" [@@mel.send]
external readable_on : readable -> string -> ('a -> unit) -> unit = "on" [@@mel.send]

external fetch1 : string -> response Js.Promise.t = "fetch"

external fetch2 : string -> 'a -> response Js.Promise.t = "fetch"
external response_ok : response -> bool = "ok" [@@mel.get]
external response_status : response -> int = "status" [@@mel.get]
external response_headers : response -> headers = "headers" [@@mel.get]
external response_text : response -> string Js.Promise.t = "text" [@@mel.send]
external headers_get_null : headers -> string -> string Js.null = "get" [@@mel.send]

external object_assign : 'a -> string Js.Dict.t -> string Js.Dict.t = "assign"
[@@mel.scope "Object"]

external json_stringify : Js.Json.t -> 'a Js.null -> int -> string
  = "stringify"
[@@mel.scope "JSON"]

let root = Node.Process.cwd ()

let vite_bin =
  Node.Path.join [| root; "node_modules/vite/bin/vite.js" |]

let vite_config =
  Node.Path.join
    [| root; "_build/default/src/melange/vite/src/melange/vite_config.js" |]

let self () = Node.Process.argv.(1)

let env_get name = Js.Dict.get Node.Process.process##env name

let env_or name fallback =
  match env_get name with Some v when v <> "" -> v | _ -> fallback

let copy_env () = object_assign (Js.Dict.empty ()) Node.Process.process##env

let env_with key value =
  let env = copy_env () in
  Js.Dict.set env key value;
  env

let assert_ cond message = if not cond then failwith message

let pass label = console_log ("PASS " ^ label)

let status_of result =
  match Js.Null.toOption result##status with Some s -> s | None -> -1

let run_sync cmd args opts = spawn_sync cmd (Array.of_list args) opts

let run_or_throw cmd args label =
  let result =
    spawn_sync cmd (Array.of_list args)
      [%mel.obj
        {
          cwd = root;
          encoding = "utf8";
          stdio = "inherit";
          env = Node.Process.process##env;
        }]
  in
  let status = status_of result in
  if status <> 0 then failwith (label ^ " exited " ^ string_of_int status)

let pids_on_port port =
  let result =
    spawn_sync "lsof"
      [| "-nP"; "-iTCP:" ^ port; "-sTCP:LISTEN"; "-t" |]
      [%mel.obj { encoding = "utf8" }]
  in
  result##stdout |> String.trim |> String.split_on_char ' '
  |> List.filter (fun s -> s <> "")
  |> List.concat_map (fun s -> String.split_on_char '\n' s)
  |> List.map String.trim
  |> List.filter (fun s -> s <> "")

let kill_port port =
  List.iter
    (fun pid ->
      try process_kill (int_of_string pid) "SIGKILL" with _ -> ())
    (pids_on_port port)

let sleep_ms ms : unit Js.Promise.t =
  Js.Promise.make (fun ~resolve ~reject:_ ->
      set_timeout
        (fun () ->
          let u = () in
          resolve u [@u])
        ms)

let rec wait_http ?(cache = true) url attempts : unit Js.Promise.t =
  if attempts <= 0 then
    Js.Promise.reject (Failure ("server not ready: " ^ url))
  else
    let req =
      if cache then fetch1 url
      else fetch2 url [%mel.obj { cache = "no-store" }]
    in
    req
    |> Js.Promise.then_ (fun res ->
           if response_ok res then Js.Promise.resolve ()
           else
             sleep_ms 250
             |> Js.Promise.then_ (fun () -> wait_http ~cache url (attempts - 1)))
    |> Js.Promise.catch (fun _ ->
           sleep_ms 250
           |> Js.Promise.then_ (fun () -> wait_http ~cache url (attempts - 1)))

let rec wait_port_free port attempts : unit Js.Promise.t =
  if attempts <= 0 then
    Js.Promise.reject (Failure ("port " ^ port ^ " still in use"))
  else if pids_on_port port = [] then Js.Promise.resolve ()
  else (
    kill_port port;
    sleep_ms 100
    |> Js.Promise.then_ (fun () -> wait_port_free port (attempts - 1)))

let pipe_stdio child =
  readable_on (child_stdout child) "data" (fun d -> stdout_write d);
  readable_on (child_stderr child) "data" (fun d -> stderr_write d)

let start_preview port =
  let child =
    spawn exec_path
      [|
        vite_bin;
        "preview";
        "--config";
        vite_config;
        "--host";
        "127.0.0.1";
        "--port";
        port;
        "--strictPort";
      |]
      [%mel.obj
        {
          cwd = root;
          stdio = [| "ignore"; "pipe"; "pipe" |];
          env = Node.Process.process##env;
        }]
  in
  pipe_stdio child;
  child

let stop_preview port child_opt =
  (match child_opt with
  | Some child -> (
      match Js.Undefined.toOption (child_pid child) with
      | Some _ -> ( try child_kill child "SIGTERM" with _ -> ())
      | None -> ())
  | None -> ());
  kill_port port

let header_get headers name =
  match Js.Null.toOption (headers_get_null headers name) with
  | Some v -> v
  | None -> ""

let header_has headers name needle =
  let value = String.lowercase_ascii (header_get headers name) in
  let needle = String.lowercase_ascii needle in
  Js.String.includes ~search:needle value

let schedule_exit () =
  let handle =
    set_timeout_handle
      (fun () ->
        let code =
          match Js.Undefined.toOption (exit_code ()) with
          | Some c -> c
          | None -> 0
        in
        Node.Process.exit code)
      100
  in
  ignore handle##unref

let capture1 re s =
  match Js.Re.exec ~str:s re with
  | None -> None
  | Some result -> Js.Nullable.toOption (Js.Re.captures result).(1)

let global_captures re s =
  let rec loop acc =
    match Js.Re.exec ~str:s re with
    | None -> List.rev acc
    | Some result -> (
        match Js.Nullable.toOption (Js.Re.captures result).(1) with
        | Some g -> loop (g :: acc)
        | None -> loop acc)
  in
  loop []

let visible_text html =
  let body =
    match capture1 [%mel.re "/<body[^>]*>([\\s\\S]*)<\\/body>/i"] html with
    | Some b -> b
    | None -> html
  in
  body
  |> Js.String.replaceByRe
       ~regexp:[%mel.re "/<script\\b[\\s\\S]*?<\\/script>/gi"]
       ~replacement:" "
  |> Js.String.replaceByRe
       ~regexp:[%mel.re "/<style\\b[\\s\\S]*?<\\/style>/gi"]
       ~replacement:" "
  |> Js.String.replaceByRe
       ~regexp:[%mel.re "/<noscript\\b[\\s\\S]*?<\\/noscript>/gi"]
       ~replacement:" "
  |> Js.String.replaceByRe ~regexp:[%mel.re "/<[^>]+>/g"] ~replacement:" "
  |> Js.String.replaceByRe ~regexp:[%mel.re "/\\s+/g"] ~replacement:" "
  |> String.trim
