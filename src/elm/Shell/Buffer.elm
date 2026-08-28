module Shell.Buffer exposing (moveFocus, openBuffer, openByQuery)

{-| Opening buffers and moving the sidebar selection. -}

import Buffers
import Ports
import Shell.Model as Model exposing (Mode(..), Model, Msg(..), bufferList, setMsg)

openBuffer : String -> Bool -> Model -> ( Model, Cmd Msg )
openBuffer id silent model =
    case Buffers.find (bufferList model) id of
        Nothing ->
            ( setMsg ("E94: No matching buffer for " ++ id) "error" model, Cmd.none )

        Just buf ->
            let
                isTerm =
                    buf.kind == Buffers.Terminal

                m1 =
                    { model
                        | activeId = id
                        , focusIdx = Buffers.indexOf (bufferList model) id
                        , termFocused = isTerm
                        , mode = Normal
                        , paletteOpen = False
                        , buffersCollapsed =
                            if not silent && model.isMobile then
                                True

                            else
                                model.buffersCollapsed
                    }

                m2 =
                    if silent then
                        m1

                    else
                        setMsg ("\"" ++ buf.label ++ "\" opened") "ok" m1

                focusCmd =
                    if isTerm then
                        Ports.focus "terminal-input"

                    else
                        Cmd.none
            in
            ( m2, focusCmd )


openByQuery : String -> Model -> ( Model, Bool )
openByQuery q model =
    if String.isEmpty q then
        ( setMsg "E32: No file name" "error" model, False )

    else
        case Buffers.findByQuery (bufferList model) q of
            Nothing ->
                ( setMsg ("E94: No matching buffer for " ++ q) "error" model, False )

            Just b ->
                let
                    ( m, _ ) =
                        openBuffer b.id False model
                in
                ( m, True )


moveFocus : Int -> Model -> Model
moveFocus delta model =
    let
        n =
            List.length (bufferList model)

        next =
            modBy n (model.focusIdx + delta + n)
    in
    { model | focusIdx = next }
