(* JSON Resume slice used for the crawlable fragment. Pure decode. *)

type job = {
  name : string;
  position : string;
  url : string;
  start_date : string;
  end_date : string;
  highlights : string list;
}

type basics = {
  name : string;
  label : string;
  summary : string;
  email : string;
  url : string;
  profile_urls : string list;
}

type t = { basics : basics; work : job list }

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
  | _ -> ""

let field dict key =
  match Js.Dict.get dict key with
  | Some json -> json
  | None -> Js.Json.null

let string_field dict key = as_string (field dict key)

let object_field dict key =
  match as_object (field dict key) with
  | Some inner -> inner
  | None -> Js.Dict.empty ()

let string_list json =
  as_array json
  |> Array.to_list
  |> List.map as_string
  |> List.filter (fun s -> s <> "")

let present s = String.trim s <> ""

let decode_profile json =
  match as_object json with
  | None -> ""
  | Some dict -> String.trim (string_field dict "url")

let decode_job json =
  match as_object json with
  | None ->
      {
        name = "";
        position = "";
        url = "";
        start_date = "";
        end_date = "";
        highlights = [];
      }
  | Some dict ->
      {
        name = string_field dict "name";
        position = string_field dict "position";
        url = String.trim (string_field dict "url");
        start_date = String.trim (string_field dict "startDate");
        end_date = String.trim (string_field dict "endDate");
        highlights = string_list (field dict "highlights");
      }

let decode_basics dict =
  let profiles = as_array (field dict "profiles") in
  {
    name = string_field dict "name";
    label = string_field dict "label";
    summary = string_field dict "summary";
    email = String.trim (string_field dict "email");
    url = String.trim (string_field dict "url");
    profile_urls =
      profiles |> Array.to_list |> List.map decode_profile
      |> List.filter present;
  }

let of_json json =
  match as_object json with
  | None -> { basics = decode_basics (Js.Dict.empty ()); work = [] }
  | Some dict ->
      let work =
        as_array (field dict "work")
        |> Array.to_list
        |> List.map decode_job
      in
      { basics = decode_basics (object_field dict "basics"); work }
