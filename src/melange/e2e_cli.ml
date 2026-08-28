(* Dispatcher for Melange-compiled e2e runners. *)

let usage () =
  Js.Console.error
    "usage: e2e_cli.cjs <agentic|navigation|keyboard|resume|run|t13|interview>";
  Node.Process.exit 1

let () =
  let argv = Node.Process.argv in
  let cmd = if Array.length argv > 2 then argv.(2) else "" in
  match cmd with
  | "agentic" -> E2e_agentic.run ()
  | "navigation" -> E2e_navigation.run ()
  | "keyboard" -> E2e_keyboard.run ()
  | "resume" -> E2e_resume.run ()
  | "run" -> E2e_run.run ()
  | "t13" -> E2e_t13.run ()
  | "interview" -> E2e_interview.run ()
  | _ -> usage ()
