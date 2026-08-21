module Views exposing (bufferBody, pills)

import Buffers exposing (Buffer, BufferKind(..), codeSample)
import Highlight
import Html exposing (..)
import Html.Attributes as A exposing (class, href, id, rel, style, target)
import Html.Events as E
import Json.Decode as Decode
import Resume exposing (View)


pills : List String -> Bool -> List (Html msg)
pills items hot =
    let
        cls =
            if hot then
                "pill hot"

            else
                "pill"
    in
    List.map (\s -> span [ class cls ] [ text s ]) items


splitParagraphs : String -> List String
splitParagraphs s =
    String.split "\n" s
        |> List.map String.trim
        |> List.filter (not << String.isEmpty)


bufferBody : View -> Buffer -> List String -> (String -> msg) -> msg -> msg -> Html msg
bufferBody data buf termLines onTermSubmit onTermFocus onTermBlur =
    case buf.kind of
        Home ->
            viewHome data

        Experience ->
            viewExperience data

        Highlights ->
            viewHighlights data

        Skills ->
            viewSkills data

        OpenSource ->
            viewOpenSource data

        CrossrSkills ->
            viewCrossrSkills data

        Code ->
            viewCode buf

        Relay ->
            viewRelay

        Terminal ->
            viewTerminal termLines onTermSubmit onTermFocus onTermBlur

        Help ->
            viewHelp


viewHome : View -> Html msg
viewHome data =
    div []
        [ div [ class "hero" ]
            [ div [ class "hero-kicker" ] [ text "~/scull7.com" ]
            , h1 [] [ text data.profile.name ]
            , p [ class "tagline" ] [ text data.profile.tagline ]
            , div [ class "hero-links" ]
                [ a [ href ("mailto:" ++ data.profile.email) ] [ text data.profile.email ]
                , a [ href data.profile.linkedin, target "_blank", rel "noopener" ] [ text "linkedin/in/scull7" ]
                , a [ href data.profile.github, target "_blank", rel "noopener" ] [ text "github.com/scull7" ]
                ]
            ]
        , h2 [ class "section-title" ] [ text "summary" ]
        , div [] (List.map (\para -> p [ class "summary" ] [ text para ]) (splitParagraphs data.summary))
        , div [ class "competency-grid" ] (pills data.competencies True)
        , div [ class "help-strip" ]
            [ span [] [ text ": command · / search · j/k buffers · Enter open · gg/G · ? help" ]
            ]
        ]


viewExperience : View -> Html msg
viewExperience data =
    div []
        (h2 [ class "section-title" ] [ text "work experience" ]
            :: List.map
                (\job ->
                    div [ class "job", id ("job-" ++ job.id) ]
                        [ div [ class "job-head" ]
                            [ div [ class "job-title" ]
                                [ text (job.role ++ " · ")
                                , span [ class "company" ] [ text job.company ]
                                ]
                            , div [ class "job-meta" ] [ text (job.dates ++ " · " ++ job.location) ]
                            ]
                        , ul [] (List.map (\b -> li [] [ text b ]) job.bullets)
                        ]
                )
                data.experience
        )


viewHighlights : View -> Html msg
viewHighlights data =
    div []
        [ h2 [ class "section-title" ] [ text "career highlights" ]
        , ul [] (List.map (\h -> li [] [ text h ]) data.highlights)
        , h2 [ class "section-title", style "margin-top" "28px" ] [ text "education" ]
        , div []
            (List.map
                (\e ->
                    div [ class "job" ]
                        [ div [ class "job-head" ]
                            [ div [ class "job-title" ] [ text e.school ]
                            , div [ class "job-meta" ] [ text e.dates ]
                            ]
                        , p [ class "summary" ] [ text e.detail ]
                        ]
                )
                data.education
            )
        ]


viewSkills : View -> Html msg
viewSkills data =
    let
        section title items =
            if List.isEmpty items then
                text ""

            else
                div []
                    [ h2 [ class "section-title" ] [ text title ]
                    , div [ class "competency-grid", style "margin-bottom" "18px" ] (pills items False)
                    ]
    in
    div []
        [ section "languages (active)" data.skills.languagesActive
        , section "languages (prior)" data.skills.languagesPrior
        , section "web / ui" data.skills.web
        , section "data" data.skills.data
        , section "infrastructure" data.skills.infra
        , section "cloud" data.skills.cloud
        , section "ci / cd" data.skills.cicd
        ]


viewOpenSource : View -> Html msg
viewOpenSource data =
    div []
        (h2 [ class "section-title" ] [ text "open source" ]
            :: List.map
                (\o ->
                    div [ class "oss-card" ]
                        [ h2 [ class "section-title" ]
                            [ if String.isEmpty o.url then
                                text o.name

                              else
                                a [ href o.url, target "_blank", rel "noopener" ] [ text o.name ]
                            , text " "
                            , span [ class "pill" ] [ text o.lang ]
                            ]
                        , p [] [ text o.blurb ]
                        ]
                )
                data.openSource
        )


viewCrossrSkills : View -> Html msg
viewCrossrSkills data =
    case data.crossrSkills of
        Nothing ->
            text ""

        Just project ->
            let
                description =
                    if String.isEmpty project.description then
                        []

                    else
                        [ p [ class "summary" ] [ text project.description ] ]

                link url =
                    a [ href url, target "_blank", rel "noopener" ] [ text url ]

                links =
                    [ project.url, project.github ]
                        |> List.filter (not << String.isEmpty)
                        |> List.map link

                linkRow =
                    if List.isEmpty links then
                        []

                    else
                        [ div [ class "hero-links" ] links ]
            in
            div [ class "oss-card" ]
                (h2 [ class "section-title" ] [ text project.name ]
                    :: description
                    ++ linkRow
                )


viewCode : Buffer -> Html msg
viewCode buf =
    div []
        [ h2 [ class "section-title" ] [ text buf.label ]
        , Highlight.viewCode (codeSample buf.sample)
        , p [ class "code-caption" ] [ text "sample buffer · read-only · syntax tint" ]
        ]


viewRelay : Html msg
viewRelay =
    div [ class "relay-viz" ]
        [ h2 [ class "section-title" ] [ text "relay · gpu cloud control plane" ]
        , div
            [ class "relay-canvas"
            , A.attribute "role" "img"
            , A.attribute "aria-label" "Relay routes client workloads to the AMD GPU fleet via the Event API"
            ]
            [ div [ class "relay-node", style "left" "18%", style "top" "50%" ] [ text "clients" ]
            , div [ class "relay-node primary", style "left" "50%", style "top" "30%" ] [ text "Relay" ]
            , div [ class "relay-node", style "left" "50%", style "top" "70%" ] [ text "Event API" ]
            , div [ class "relay-node gpu", style "left" "82%", style "top" "50%" ] [ text "AMD GPU fleet" ]
            , div [ class "relay-packet", A.attribute "aria-hidden" "true" ] []
            , div [ class "relay-packet b", A.attribute "aria-hidden" "true" ] []
            , div [ class "relay-packet c", A.attribute "aria-hidden" "true" ] []
            ]
        , p [ class "relay-caption" ] [ text "clients → Relay → Event API → AMD GPU fleet" ]
        , div [ class "relay-stats" ]
            [ stat "Role" "Dir Eng · IC"
            , stat "Domain" "GPU clouds"
            , stat "Impact" "Record delivery"
            , stat "Stack" "Rust · distributed"
            ]
        , p [ class "summary", style "font-size" "14px", style "color" "var(--text-dim)" ]
            [ text "At TensorWave, Relay turns workload intent into scheduled GPU capacity. As Director of Engineering and primary IC, I architected and shipped the service that unlocked the largest AMD-based GPU clouds under aggressive timelines."
            ]
        ]


stat : String -> String -> Html msg
stat label value =
    div [ class "relay-stat" ]
        [ div [ class "label" ] [ text label ]
        , div [ class "value", style "font-size" "15px" ] [ text value ]
        ]


viewTerminal : List String -> (String -> msg) -> msg -> msg -> Html msg
viewTerminal lines onSubmit onFocus onBlur =
    div []
        [ h2 [ class "section-title" ] [ text "live terminal" ]
        , div [ class "terminal glass" ]
            [ div [ class "terminal-output" ]
                (List.map (\line -> div [] [ text line ]) lines)
            , div [ class "terminal-input-row" ]
                [ span [ class "terminal-prompt" ] [ text "scull7@resume:~$" ]
                , input
                    [ class "terminal-input"
                    , id "terminal-input"
                    , A.attribute "autocomplete" "off"
                    , A.spellcheck False
                    , E.onFocus onFocus
                    , E.onBlur onBlur
                    , E.on "keydown" (termKeyDecoder onSubmit)
                    ]
                    []
                ]
            ]
        ]


termKeyDecoder : (String -> msg) -> Decode.Decoder msg
termKeyDecoder onSubmit =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.at [ "target", "value" ] Decode.string)
        |> Decode.andThen
            (\( key, value ) ->
                if key == "Enter" then
                    Decode.succeed (onSubmit value)

                else
                    Decode.fail "not enter"
            )


viewHelp : Html msg
viewHelp =
    let
        rows =
            [ ( ":  /  Esc", "Command palette · search · cancel" )
            , ( "Ctrl-[  Ctrl-c", "Esc synonyms (palette / cancel)" )
            , ( ":help  :ls  :q  :mail", "Help · list buffers · home · email" )
            , ( ":e / :open {name}", "Open buffer by name" )
            , ( "j k  ↑ ↓", "Move buffer focus" )
            , ( "Enter  l", "Open focused buffer" )
            , ( "gg  G", "Top / bottom of buffer list" )
            , ( "Ctrl-f  Ctrl-b", "Page buffer body down / up" )
            , ( "z", "Center buffer body scroll" )
            , ( "?", "Open this help" )
            ]

        grid =
            List.concatMap
                (\( cmd, desc ) ->
                    [ div [ class "cmd" ] [ text cmd ]
                    , div [ class "desc" ] [ text desc ]
                    ]
                )
                rows
    in
    div []
        [ h2 [ class "section-title" ] [ text "help.txt" ]
        , p [ class "summary", style "margin-bottom" "12px" ]
            [ text "Vim-inspired navigation. Palette-primary commands (Option B). Elm + ReScript ports." ]
        , pre [ class "code-block help-modes" ]
            [ text """modes
  NORMAL  -- : -->  COMMAND (palette)  -- Esc -->  NORMAL
  NORMAL  -- / -->  SEARCH  (palette)  -- Esc -->  NORMAL
  NORMAL  -- ? -->  help.txt

rules
  · Bottom cmdline echoes :query / /query while palette is open
  · g pending auto-clears after ~600ms (gg still works)
  · Terminal input focused → shell keys ignored (Esc blurs)
  · Insert mode is unused — stay in NORMAL + palette"""
            ]
        , h2 [ class "section-title", style "margin-top" "20px" ] [ text "keys" ]
        , div [ class "help-grid" ] grid
        ]
