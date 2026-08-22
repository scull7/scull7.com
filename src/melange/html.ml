(* Pure HTML helpers. *)

let escape text =
  let buf = Buffer.create (String.length text) in
  String.iter
    (function
      | '&' -> Buffer.add_string buf "&amp;"
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '"' -> Buffer.add_string buf "&quot;"
      | '\'' -> Buffer.add_string buf "&#39;"
      | c -> Buffer.add_char buf c)
    text;
  Buffer.contents buf

let nonempty parts = List.filter (fun s -> s <> "") parts

let join_lines parts = String.concat "\n" (nonempty parts)

let wrap tag inner = "<" ^ tag ^ ">" ^ inner ^ "</" ^ tag ^ ">"

let el tag inner =
  if inner = "" then "" else wrap tag (escape inner)

let anchor href text =
  if href = "" then ""
  else
    "<a href=\"" ^ escape href ^ "\">" ^ escape text ^ "</a>"
