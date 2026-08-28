module Shell.Keyboard exposing
    ( handleKey
    , isEscape
    , keyDecoder
    , paletteInputKeyDecoder
    )

{-| Key routing: normal-mode motions, the palette input, and Escape. -}

import Json.Decode as Decode
import Ports
import Shell.Buffer as Buffer exposing (moveFocus, openBuffer)
import Shell.Model as Model exposing (KeyInfo, Mode(..), Model, Msg(..), armG, bufferList, clearG, setMsg)
import Shell.Palette as Palette exposing (acceptPalette, closePalette, openPalette, paletteMove)

isEscape : KeyInfo -> Bool
isEscape info =
    info.key == "Escape" || (info.ctrl && (info.key == "[" || info.key == "c"))


handleKey : KeyInfo -> Model -> ( Model, Cmd Msg )
handleKey info model =
    -- Escape always wins: close palette even if focus/mode got out of sync.
    if isEscape info && model.paletteOpen then
        closePalette model

    else if model.paletteOpen then
        if info.meta || (info.ctrl && info.key /= "[" && info.key /= "c") then
            ( model, Cmd.none )

        else
            case info.key of
                "Tab" ->
                    ( model, Ports.focus "palette-input" )

                "ArrowDown" ->
                    paletteMove 1 model

                "j" ->
                    paletteMove 1 model

                "ArrowUp" ->
                    paletteMove -1 model

                "k" ->
                    paletteMove -1 model

                "Enter" ->
                    acceptPalette model

                _ ->
                    ( model, Cmd.none )

    else if model.termFocused then
        if isEscape info then
            ( { model | mode = Normal, termFocused = False }
            , Ports.focus "buffer-body"
            )

        else
            -- Let the terminal <input> handle typing; ignore shell nav.
            ( model, Cmd.none )

    else if info.ctrl && (info.key == "f" || info.key == "F") then
        ( clearG { model | mode = Normal }, Ports.scrollBuffer { action = "page", dir = 1 } )

    else if info.ctrl && (info.key == "b" || info.key == "B") then
        ( clearG { model | mode = Normal }, Ports.scrollBuffer { action = "page", dir = -1 } )

    else if isEscape info then
        ( clearG (setMsg "" "" { model | mode = Normal }), Cmd.none )

    else
        -- Force Normal when palette is closed so Command/Search cannot stick.
        let
            m =
                clearG { model | mode = Normal }
        in
        case info.key of
            ":" ->
                openPalette "command" m

            "/" ->
                openPalette "search" m

            "?" ->
                openBuffer "help.txt" False m

            "j" ->
                ( moveFocus 1 m, Cmd.none )

            "ArrowDown" ->
                ( moveFocus 1 m, Cmd.none )

            "k" ->
                ( moveFocus -1 m, Cmd.none )

            "ArrowUp" ->
                ( moveFocus -1 m, Cmd.none )

            "Enter" ->
                openFocused m

            "l" ->
                openFocused m

            "ArrowRight" ->
                openFocused m

            "g" ->
                if m.gPending then
                    ( setMsg "gg → top" "" { m | gPending = False, focusIdx = 0 }, Cmd.none )

                else
                    armG m

            "G" ->
                ( setMsg "G → bottom" "" { m | focusIdx = List.length (bufferList m) - 1 }
                , Cmd.none
                )

            "z" ->
                ( setMsg "z → center" "" m
                , Ports.scrollBuffer { action = "center", dir = 0 }
                )

            _ ->
                if m.gPending && not (List.member info.key [ "Shift", "Control", "Alt", "Meta" ]) then
                    ( { m | gPending = False }, Cmd.none )

                else
                    ( m, Cmd.none )


openFocused : Model -> ( Model, Cmd Msg )
openFocused model =
    case List.drop model.focusIdx (bufferList model) |> List.head of
        Just b ->
            openBuffer b.id False model

        Nothing ->
            ( model, Cmd.none )


keyDecoder : Decode.Decoder Msg
keyDecoder =
    Decode.map5 KeyInfo
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        |> Decode.map KeyDown


{-| Keys handled while the palette input is focused — stopDefault so Esc/Enter
reach Elm reliably and do not leave the field sticky.
-}


paletteInputKeyDecoder : Decode.Decoder ( Msg, Bool )
paletteInputKeyDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        |> Decode.andThen
            (\( key, ctrl ) ->
                let
                    info =
                        { key = key
                        , ctrl = ctrl
                        , meta = False
                        , alt = False
                        , shift = False
                        }

                    handled =
                        key
                            == "Escape"
                            || key
                            == "Enter"
                            || key
                            == "Tab"
                            || key
                            == "ArrowDown"
                            || key
                            == "ArrowUp"
                            || key
                            == "j"
                            || key
                            == "k"
                            || (ctrl && (key == "[" || key == "c"))
                in
                if handled then
                    Decode.succeed ( KeyDown info, True )

                else
                    Decode.fail "pass to input"
            )


-- VIEW
