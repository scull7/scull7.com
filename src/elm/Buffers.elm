module Buffers exposing
    ( Buffer
    , BufferKind(..)
    , catalog
    , codeSample
    , core
    , find
    , findByQuery
    , indexOf
    )

import Resume exposing (View)


type BufferKind
    = Home
    | Experience
    | Highlights
    | Skills
    | OpenSource
    | CrossrSkills
    | Code
    | Relay
    | Terminal
    | Help


type alias Buffer =
    { id : String
    , icon : String
    , kind : BufferKind
    , label : String
    , badge : String
    , sample : String
    }


core : List Buffer
core =
    [ { id = "README.md", icon = "📄", kind = Home, label = "README.md", badge = "home", sample = "" }
    , { id = "experience.md", icon = "💼", kind = Experience, label = "experience.md", badge = "work", sample = "" }
    , { id = "highlights.md", icon = "✦", kind = Highlights, label = "highlights.md", badge = "proof", sample = "" }
    , { id = "skills.md", icon = "⚙", kind = Skills, label = "skills.md", badge = "stack", sample = "" }
    , { id = "opensource.md", icon = "⌘", kind = OpenSource, label = "opensource.md", badge = "oss", sample = "" }
    , { id = "cents.rs", icon = "🦀", kind = Code, label = "cents.rs", badge = "rust", sample = "cents" }
    , { id = "bs_result.re", icon = "λ", kind = Code, label = "bs_result.re", badge = "ocaml", sample = "result" }
    , { id = "relay.rs", icon = "⚡", kind = Code, label = "relay.rs", badge = "gpu", sample = "relay" }
    , { id = "relay-viz", icon = "◈", kind = Relay, label = "relay-viz", badge = "demo", sample = "" }
    , { id = "terminal", icon = ">_", kind = Terminal, label = "terminal", badge = "live", sample = "" }
    , { id = "help.txt", icon = "?", kind = Help, label = "help.txt", badge = "docs", sample = "" }
    ]


crossrSkillsBuffer : Buffer
crossrSkillsBuffer =
    { id = "crossr-skills.md"
    , icon = "◇"
    , kind = CrossrSkills
    , label = "crossr-skills.md"
    , badge = "oss"
    , sample = ""
    }


catalog : View -> List Buffer
catalog data =
    case data.crossrSkills of
        Nothing ->
            core

        Just _ ->
            insertAfter "opensource.md" crossrSkillsBuffer core


insertAfter : String -> Buffer -> List Buffer -> List Buffer
insertAfter afterId buf list =
    case list of
        [] ->
            [ buf ]

        x :: xs ->
            if x.id == afterId then
                x :: buf :: xs

            else
                x :: insertAfter afterId buf xs


find : List Buffer -> String -> Maybe Buffer
find buffers id =
    List.filter (\b -> b.id == id) buffers |> List.head


indexOf : List Buffer -> String -> Int
indexOf buffers id =
    buffers
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, b ) -> b.id == id)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0


findByQuery : List Buffer -> String -> Maybe Buffer
findByQuery buffers q =
    let
        needle =
            String.toLower q
    in
    List.filter
        (\b ->
            let
                id =
                    String.toLower b.id

                label =
                    String.toLower b.label
            in
            id == needle || label == needle || String.startsWith needle label || String.contains needle id
        )
        buffers
        |> List.head


codeSample : String -> String
codeSample key =
    case key of
        "cents" ->
            """// cents — monetary values as integer cents (Rust)
use cents::Cents;

fn transfer(from: &mut Cents, to: &mut Cents, amount: Cents) -> Result<()> {
    from.checked_sub(amount)?;
    to.checked_add(amount)?;
    Ok(())
}

let fee = Cents::from_dollars("1.50")?; // 150 cents"""

        "result" ->
            """(* bs-result — category-theory Result for ReasonML *)
open BsResult;

let parseUser = (json) =>
  json
  |> decodeField("id", Decode.int)
  |> flatMap(id =>
       decodeField("email", Decode.string, json)
       |> map(email => {id, email})
     );"""

        "relay" ->
            """// Relay (conceptual) — GPU cloud control plane
pub async fn route_event(
    evt: Event,
    bus: &EventBus,
    fleet: &GpuFleet,
) -> Result<Ack> {
    let plan = fleet.schedule(evt.workload())?;
    bus.publish(plan.as_control_msg()).await?;
    Ok(Ack::accepted(plan.id()))
}"""

        _ ->
            "// empty"
