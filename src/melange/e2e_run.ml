(* Build (optional) + vite preview + navigation and keyboard e2e. *)

let port = E2e_ffi.env_or "PORT" "4173"
let base = "http://127.0.0.1:" ^ port

external spawn_inherit :
  string ->
  string array ->
  < cwd : string ; stdio : string ; env : string Js.Dict.t > Js.t ->
  E2e_ffi.child = "spawn"
[@@mel.module "child_process"]

let run_inherit args env : unit Js.Promise.t =
  Js.Promise.make (fun ~resolve ~reject ->
      let child =
        spawn_inherit E2e_ffi.exec_path (Array.of_list args)
          [%mel.obj { cwd = E2e_ffi.root; stdio = "inherit"; env }]
      in
      E2e_ffi.child_on child "error" (fun err -> reject err [@u]);
      E2e_ffi.child_on child "exit" (fun code ->
          let status =
            match Js.Types.classify code with
            | Js.Types.JSNumber n -> int_of_float n
            | _ -> 1
          in
          if status = 0 then
            let u = () in
            resolve u [@u]
          else
            reject
              (Failure
                 (String.concat " " args ^ " exited " ^ string_of_int status))
            [@u]))

let maybe_build () : unit Js.Promise.t =
  if E2e_ffi.env_get "SKIP_BUILD" = Some "1" then Js.Promise.resolve ()
  else
    Js.Promise.make (fun ~resolve ~reject ->
        try
          E2e_ffi.console_log "→ npm run build";
          E2e_ffi.run_or_throw "npm" [ "run"; "build" ] "npm run build";
          let u = () in
          resolve u [@u]
        with exn -> reject exn [@u])

let run () =
  let preview = ref None in
  let finish code =
    (match !preview with
    | Some child -> (
        (try E2e_ffi.child_kill child "SIGTERM" with _ -> ());
        match Js.Undefined.toOption (E2e_ffi.child_pid child) with
        | Some pid -> (
            try E2e_ffi.process_kill (-pid) "SIGKILL" with _ ->
              try E2e_ffi.child_kill child "SIGKILL" with _ -> ())
        | None -> ())
    | None -> ());
    E2e_ffi.set_exit_code code;
    E2e_ffi.schedule_exit ()
  in
  maybe_build ()
  |> Js.Promise.then_ (fun () ->
         E2e_ffi.console_log ("→ vite preview :" ^ port);
         preview := Some (E2e_ffi.start_preview port);
         E2e_ffi.wait_http (base ^ "/") 40)
  |> Js.Promise.then_ (fun () ->
         E2e_ffi.console_log "→ e2e/navigation";
         run_inherit
           [ E2e_ffi.self (); "navigation" ]
           (E2e_ffi.env_with "BASE_URL" base))
  |> Js.Promise.then_ (fun () ->
         E2e_ffi.console_log "→ e2e/keyboard";
         run_inherit
           [ E2e_ffi.self (); "keyboard" ]
           (E2e_ffi.env_with "BASE_URL" base))
  |> Js.Promise.then_ (fun () ->
         E2e_ffi.console_log "e2e/run PASS";
         finish 0;
         Js.Promise.resolve ())
  |> Js.Promise.catch (fun err ->
         E2e_ffi.console_error_any err;
         E2e_ffi.console_error ("e2e/run FAIL: " ^ E2e_ffi.error_to_string err);
         finish 1;
         Js.Promise.resolve ())
  |> ignore
