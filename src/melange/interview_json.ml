(* Small JSON helpers. Pure reads of immutable JSON values. *)

external json_parse : string -> Js.Json.t = "parse" [@@mel.scope "JSON"]
external json_stringify : Js.Json.t -> string = "stringify" [@@mel.scope "JSON"]

external json_stringify_pretty : Js.Json.t -> 'a Js.null -> int -> string
  = "stringify"
[@@mel.scope "JSON"]

let classify = Js.Json.classify

let as_object json =
  match classify json with
  | JSONObject dict -> Some dict
  | _ -> None

let as_array json =
  match classify json with
  | JSONArray items -> items
  | _ -> [||]

let as_string json =
  match classify json with
  | JSONString s -> s
  | JSONNumber n ->
      if n = floor n then string_of_int (int_of_float n) else string_of_float n
  | JSONTrue -> "true"
  | JSONFalse -> "false"
  | _ -> ""

let as_bool json =
  match classify json with
  | JSONTrue -> true
  | JSONFalse -> false
  | JSONNumber n -> n <> 0.
  | JSONString s ->
      let t = String.lowercase_ascii (String.trim s) in
      t = "true" || t = "1" || t = "yes"
  | _ -> false

let field dict key =
  match Js.Dict.get dict key with
  | Some json -> json
  | None -> Js.Json.null

let string_field dict key = as_string (field dict key)

let opt_string_field dict key =
  match Js.Dict.get dict key with
  | None -> None
  | Some json -> (
      match classify json with
      | JSONNull -> None
      | _ ->
          let s = String.trim (as_string json) in
          if s = "" then None else Some s)

let object_field dict key =
  match as_object (field dict key) with
  | Some inner -> inner
  | None -> Js.Dict.empty ()

let str s = Js.Json.string s
let num n = Js.Json.number n
let bool b = Js.Json.boolean b
let null = Js.Json.null
let arr xs = Js.Json.array (Array.of_list xs)

let obj pairs =
  let d = Js.Dict.empty () in
  List.iter (fun (k, v) -> Js.Dict.set d k v) pairs;
  Js.Json.object_ d

let parse_object text =
  try as_object (json_parse text) with _ -> None

let pretty json = json_stringify_pretty json Js.null 2

let string_list json =
  as_array json |> Array.to_list |> List.map as_string
  |> List.filter (fun s -> String.trim s <> "")
