module Shell.Commands exposing (handleTerm, runCommand, termOpen)

{-| The `:` command line and the in-buffer terminal. -}

import Ports
import Shell.Buffer as Buffer exposing (openBuffer, openByQuery)
import Shell.Model as Model exposing (Model, Msg(..), bufferList, setMsg)

runCommand : String -> Model -> ( Model, Cmd Msg )
runCommand raw model =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        ( model, Cmd.none )

    else
        let
            parts =
                String.words trimmed

            head =
                List.head parts |> Maybe.map String.toLower |> Maybe.withDefault ""

            arg =
                parts |> List.drop 1 |> String.join " "
        in
        case head of
            "help" ->
                openBuffer "help.txt" False model

            "ls" ->
                let
                    m0 =
                        if model.isMobile then
                            { model | buffersCollapsed = False }

                        else
                            model

                    list =
                        bufferList m0
                            |> List.indexedMap
                                (\i b ->
                                    let
                                        mark =
                                            if i == m0.focusIdx then
                                                "%"

                                            else
                                                " "
                                    in
                                    mark ++ " " ++ b.label
                                )
                            |> String.join "  "
                in
                ( setMsg list "" m0, Cmd.none )

            "reload" ->
                ( setMsg "Reloading /resume.json…" "" model, Model.fetchResume )

            "q" ->
                openBuffer "README.md" False model

            "mail" ->
                let
                    email =
                        model.resume
                            |> Maybe.map (\r -> String.trim r.profile.email)
                            |> Maybe.withDefault ""
                in
                if String.isEmpty email then
                    ( setMsg "error: no email in resume" "error" model, Cmd.none )

                else
                    ( model, Ports.openUrl ("mailto:" ++ email ++ "?subject=scull7.com") )

            "quit" ->
                openBuffer "README.md" False model

            "home" ->
                openBuffer "README.md" False model

            "experience" ->
                openBuffer "experience.md" False model

            "skills" ->
                openBuffer "skills.md" False model

            "oss" ->
                openBuffer "opensource.md" False model

            "terminal" ->
                openBuffer "terminal" False model

            "relay" ->
                openBuffer "relay-viz" False model

            "e" ->
                let
                    ( m, _ ) =
                        openByQuery arg model
                in
                ( m, Cmd.none )

            "open" ->
                let
                    ( m, _ ) =
                        openByQuery arg model
                in
                ( m, Cmd.none )

            _ ->
                let
                    ( m, ok ) =
                        openByQuery trimmed model
                in
                if ok then
                    ( m, Cmd.none )

                else
                    ( setMsg ("E492: Not an editor command: " ++ trimmed) "error" m, Cmd.none )


handleTerm : String -> Model -> ( Model, Cmd Msg )
handleTerm raw model =
    let
        m1 =
            { model | termLines = model.termLines ++ [ "scull7@resume:~$ " ++ raw ] }

        trimmed =
            String.trim raw

        parts =
            String.words trimmed

        cmd =
            List.head parts |> Maybe.map String.toLower |> Maybe.withDefault ""

        arg =
            parts |> List.drop 1 |> String.join " "

        reply =
            case cmd of
                "" ->
                    ""

                "help" ->
                    "commands: help whoami ls open cat clear skills contact fortune"

                "whoami" ->
                    case model.resume of
                        Just r ->
                            r.profile.name ++ " — " ++ r.profile.tagline

                        Nothing ->
                            "loading…"

                "ls" ->
                    bufferList model |> List.map .label |> String.join "  "

                "open" ->
                    termOpen arg m1

                "e" ->
                    termOpen arg m1

                "cat" ->
                    termOpen arg m1

                "clear" ->
                    "CLEAR"

                "skills" ->
                    case model.resume of
                        Just r ->
                            String.join ", " r.skills.languagesActive

                        Nothing ->
                            ""

                "contact" ->
                    case model.resume of
                        Just r ->
                            r.profile.email ++ "  " ++ r.profile.github ++ "  " ++ r.profile.linkedin

                        Nothing ->
                            ""

                "fortune" ->
                    "Talk is cheap. Show me the code. — Linus"

                "pwd" ->
                    "~/scull7.com"

                "echo" ->
                    arg

                _ ->
                    "command not found: " ++ cmd
    in
    case reply of
        "CLEAR" ->
            ( { m1 | termLines = [] }, Cmd.none )

        "" ->
            if cmd == "open" || cmd == "e" || cmd == "cat" then
                let
                    target =
                        if String.isEmpty arg then
                            "README.md"

                        else
                            arg

                    ( m2, ok ) =
                        openByQuery target m1

                    line =
                        if ok then
                            "opened " ++ target

                        else
                            "no such buffer: " ++ target
                in
                ( { m2 | termLines = m2.termLines ++ [ line ] }, Cmd.none )

            else
                ( m1, Cmd.none )

        _ ->
            ( { m1 | termLines = m1.termLines ++ [ reply ] }, Cmd.none )


termOpen : String -> Model -> String
termOpen _ _ =
    -- handled specially above
    ""


-- SUBSCRIPTIONS
