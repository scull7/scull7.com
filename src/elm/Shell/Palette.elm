module Shell.Palette exposing
    ( acceptPalette
    , closePalette
    , openPalette
    , paletteItems
    , paletteMove
    )

{-| The fuzzy command/search palette. -}

import Fuzzy
import Ports
import Shell.Buffer as Buffer exposing (openBuffer)
import Shell.Commands as Commands exposing (runCommand)
import Shell.Model as Model exposing (Mode(..), Model, Msg(..), PaletteItem, bufferList)

paletteItems : Model -> List PaletteItem
paletteItems model =
    let
        q =
            model.paletteQuery

        scoreItem label desc actionId i =
            case Fuzzy.rankLabel q label desc of
                Just s ->
                    Just ( s, i, { label = label, desc = desc, actionId = actionId } )

                Nothing ->
                    Nothing

        sortScored rows =
            rows
                |> List.sortBy (\( s, i, _ ) -> ( s, i ))
                |> List.map (\( _, _, item ) -> item )
    in
    if model.paletteMode == "search" then
        bufferList model
            |> List.indexedMap
                (\i b -> scoreItem b.label b.badge b.id i)
            |> List.filterMap identity
            |> sortScored

    else
        let
            cmds =
                [ ( ":help", "Show help", "cmd:help" )
                , ( ":ls", "List buffers", "cmd:ls" )
                , ( ":q", "Go home", "cmd:q" )
                , ( ":mail", "Open email", "cmd:mail" )
                , ( ":terminal", "Live terminal", "cmd:terminal" )
                , ( ":relay", "Relay viz", "cmd:relay" )
                ]

            cmdRows =
                List.indexedMap
                    (\i ( label, desc, aid ) -> scoreItem label desc aid i)
                    cmds
                    |> List.filterMap identity

            bufRows =
                bufferList model
                    |> List.indexedMap
                        (\i b ->
                            scoreItem (":e " ++ b.label) "open buffer" b.id (i + 100)
                        )
                    |> List.filterMap identity
        in
        sortScored (cmdRows ++ bufRows)


openPalette : String -> Model -> ( Model, Cmd Msg )
openPalette kind model =
    ( { model
        | paletteMode = kind
        , paletteQuery = ""
        , paletteFocus = 0
        , paletteOpen = True
        , mode =
            if kind == "search" then
                Search

            else
                Command
        , focusReturn =
            if model.termFocused then
                "terminal-input"

            else
                "buffer-body"
        , gPending = False
        , termFocused = False
      }
    , Ports.focus "palette-input"
    )


closePalette : Model -> ( Model, Cmd Msg )
closePalette model =
    let
        target =
            if String.isEmpty model.focusReturn then
                "buffer-body"

            else
                model.focusReturn
    in
    ( { model
        | paletteOpen = False
        , mode = Normal
        , gPending = False
        , paletteQuery = ""
        , paletteFocus = 0
      }
    , Cmd.batch
        [ Ports.blur "palette-input"
        , Ports.focus target
        ]
    )


acceptPalette : Model -> ( Model, Cmd Msg )
acceptPalette model =
    let
        items =
            paletteItems model
    in
    if List.isEmpty items then
        if model.paletteMode == "command" then
            let
                ( m1, cmd ) =
                    runCommand model.paletteQuery { model | paletteOpen = False, mode = Normal }
            in
            ( m1
            , Cmd.batch
                [ Ports.blur "palette-input"
                , cmd
                , Ports.focus "buffer-body"
                ]
            )

        else
            ( { model | paletteOpen = False, mode = Normal, paletteQuery = "" }
            , Cmd.batch [ Ports.blur "palette-input", Ports.focus "buffer-body" ]
            )

    else
        let
            safe =
                if model.paletteFocus < List.length items then
                    model.paletteFocus

                else
                    0

            item =
                List.drop safe items |> List.head |> Maybe.withDefault { label = "", desc = "", actionId = "" }

            m0 =
                { model | paletteOpen = False, mode = Normal, paletteQuery = "" }
        in
        if String.startsWith "cmd:" item.actionId then
            let
                ( m1, cmd ) =
                    runCommand (String.dropLeft 4 item.actionId) m0
            in
            ( m1
            , Cmd.batch
                [ Ports.blur "palette-input"
                , cmd
                , Ports.focus "buffer-body"
                ]
            )

        else
            let
                ( m1, cmd ) =
                    openBuffer item.actionId False m0
            in
            ( m1
            , Cmd.batch
                [ Ports.blur "palette-input"
                , cmd
                ]
            )


paletteMove : Int -> Model -> ( Model, Cmd Msg )
paletteMove delta model =
    let
        n =
            List.length (paletteItems model)
    in
    if n == 0 then
        ( model, Cmd.none )

    else
        ( { model | paletteFocus = modBy n (model.paletteFocus + delta + n) }, Cmd.none )
