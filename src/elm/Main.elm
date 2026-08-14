module Main exposing (main)

import Buffers exposing (Buffer)
import Browser
import Browser.Events
import Fuzzy
import Html exposing (..)
import Html.Attributes as A exposing (class, id)
import Html.Events as E
import Http
import Json.Decode as Decode
import Ports
import Process
import Resume
import Task
import Views


-- MODEL


type Mode
    = Normal
    | Command
    | Search


type alias PaletteItem =
    { label : String
    , desc : String
    , actionId : String
    }


type alias Flags =
    { isMobile : Bool
    }


type alias Model =
    { resume : Maybe Resume.View
    , loadError : Maybe String
    , mode : Mode
    , focusIdx : Int
    , activeId : String
    , msg : String
    , msgKind : String
    , gPending : Bool
    , buffersCollapsed : Bool
    , paletteOpen : Bool
    , paletteMode : String
    , paletteQuery : String
    , paletteFocus : Int
    , termLines : List String
    , termFocused : Bool
    , focusReturn : String
    , isMobile : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { resume = Nothing
      , loadError = Nothing
      , mode = Normal
      , focusIdx = 0
      , activeId = "README.md"
      , msg = "Press : for commands · / to search · ? for help"
      , msgKind = ""
      , gPending = False
      , buffersCollapsed = flags.isMobile
      , paletteOpen = False
      , paletteMode = "command"
      , paletteQuery = ""
      , paletteFocus = 0
      , termLines =
            [ "scull7.com interactive shell — type help"
            , "try: help | whoami | ls | open experience | clear"
            ]
      , termFocused = False
      , focusReturn = "buffer-list"
      , isMobile = flags.isMobile
      }
    , Http.get
        { url = "/resume.json"
        , expect = Http.expectJson GotResume Resume.decoder
        }
    )


-- UPDATE


type Msg
    = GotResume (Result Http.Error Resume.Doc)
    | KeyDown KeyInfo
    | ClickBuffer Int String
    | ToggleBuffers
    | PaletteInput String
    | PaletteClick Int
    | TermSubmit String
    | TermFocus
    | TermBlur
    | GTimeout
    | NoOp


type alias KeyInfo =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , alt : Bool
    , shift : Bool
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotResume (Ok doc) ->
            ( { model | resume = Just (Resume.mapResume doc) }, Cmd.none )

        GotResume (Err _) ->
            ( { model | loadError = Just "Failed to load resume.json" }, Cmd.none )

        ToggleBuffers ->
            ( { model | buffersCollapsed = not model.buffersCollapsed }, Cmd.none )

        ClickBuffer idx bufId ->
            openBuffer bufId False { model | focusIdx = idx }

        PaletteInput q ->
            ( { model | paletteQuery = q, paletteFocus = 0 }, Cmd.none )

        PaletteClick idx ->
            acceptPalette { model | paletteFocus = idx }

        TermFocus ->
            ( { model | termFocused = True }, Cmd.none )

        TermBlur ->
            ( { model | termFocused = False }, Cmd.none )

        TermSubmit raw ->
            handleTerm raw model

        GTimeout ->
            ( { model | gPending = False }, Cmd.none )

        KeyDown info ->
            handleKey info model

        NoOp ->
            ( model, Cmd.none )


setMsg : String -> String -> Model -> Model
setMsg text kind model =
    { model | msg = text, msgKind = kind }


clearG : Model -> Model
clearG model =
    { model | gPending = False }


armG : Model -> ( Model, Cmd Msg )
armG model =
    ( { model | gPending = True }
    , Process.sleep 600 |> Task.perform (\_ -> GTimeout)
    )


activeBuf : Model -> Buffer
activeBuf model =
    let
        buffers =
            bufferList model
    in
    Buffers.find buffers model.activeId
        |> Maybe.withDefault (List.head buffers |> Maybe.withDefault dummyBuf)


dummyBuf : Buffer
dummyBuf =
    { id = "README.md", icon = "📄", kind = Buffers.Home, label = "README.md", badge = "home", sample = "" }


bufferList : Model -> List Buffer
bufferList model =
    case model.resume of
        Just data ->
            Buffers.catalog data

        Nothing ->
            Buffers.core


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


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onKeyDown keyDecoder


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


view : Model -> Html Msg
view model =
    case model.loadError of
        Just err ->
            div [ id "vim-root" ] [ div [ class "buffer-body" ] [ text err ] ]

        Nothing ->
            case model.resume of
                Nothing ->
                    div [ id "vim-root" ]
                        [ div [ class "galaxy", A.attribute "aria-hidden" "true" ] []
                        , div [ class "buffer-body" ] [ text "Loading resume…" ]
                        ]

                Just data ->
                    viewShell model data


viewShell : Model -> Resume.View -> Html Msg
viewShell model data =
    let
        buf =
            activeBuf model

        items =
            paletteItems model

        modeLabel =
            case model.mode of
                Normal ->
                    "NORMAL"

                Command ->
                    "COMMAND"

                Search ->
                    "SEARCH"

        modeCls =
            case model.mode of
                Normal ->
                    "mode"

                Command ->
                    "mode command"

                Search ->
                    "mode search"

        listCls =
            if model.buffersCollapsed then
                "buffer-list glass is-collapsed"

            else
                "buffer-list glass"

        paletteCls =
            if model.paletteOpen then
                "palette open"

            else
                "palette"

        cmdlineText =
            if model.paletteOpen then
                let
                    pfx =
                        if model.paletteMode == "search" then
                            "/"

                        else
                            ":"
                in
                pfx ++ model.paletteQuery

            else
                model.msg

        cmdlineCls =
            if model.paletteOpen then
                "msg cmdline-echo"

            else if String.isEmpty model.msgKind then
                "msg"

            else
                "msg " ++ model.msgKind
    in
    div [ id "vim-root" ]
        [ div [ class "galaxy", A.attribute "aria-hidden" "true" ] []
        , div [ class "workspace" ]
            [ aside
                [ class listCls
                , id "buffer-list"
                , A.tabindex 0
                , A.attribute "aria-label" "Buffer sidebar"
                ]
                [ button
                    [ class "buffer-list-header"
                    , id "buffer-toggle"
                    , A.attribute "aria-controls" "buffer-items"
                    , E.onClick ToggleBuffers
                    ]
                    [ span [ class "title" ]
                        [ span [ class "chevron", A.attribute "aria-hidden" "true" ] [ text "▾" ]
                        , text " buffers"
                        ]
                    , span [ class "hint" ] [ text ":ls" ]
                    ]
                , ul
                    [ class "buffer-items"
                    , id "buffer-items"
                    , A.attribute "role" "listbox"
                    , A.attribute "aria-label" "Buffers"
                    ]
                    (List.indexedMap (viewBufferItem model) (bufferList model))
                ]
            , section [ class "buffer-pane glass-strong" ]
                [ div [ class "buffer-tabbar" ]
                    [ div [ class "buffer-tab active" ]
                        [ text (buf.icon ++ " " ++ buf.label) ]
                    ]
                , div
                    [ class "buffer-body"
                    , id "buffer-body"
                    , A.tabindex 0
                    , A.attribute "role" "region"
                    , A.attribute "aria-label" "Buffer content"
                    ]
                    [ Views.bufferBody data buf model.termLines TermSubmit TermFocus TermBlur ]
                ]
            ]
        , div [ class "bottom-chrome" ]
            [ footer [ class "statusline" ]
                [ span [ class modeCls ] [ text modeLabel ]
                , span [ class "file" ] [ text buf.label ]
                , span [ class "spacer" ] []
                , span [ class "meta" ]
                    [ span [] [ text data.profile.location ]
                    , span [] [ text (String.fromInt (model.focusIdx + 1) ++ ":1") ]
                    , span [] [ text "utf-8" ]
                    ]
                ]
            , div [ class "cmdline" ]
                [ span
                    [ class cmdlineCls
                    , A.attribute "role" "status"
                    , A.attribute "aria-live" "polite"
                    , A.attribute "aria-atomic" "true"
                    ]
                    [ text cmdlineText ]
                ]
            ]
        , div
            [ class paletteCls
            , id "palette"
            , A.attribute "role" "dialog"
            , A.attribute "aria-modal" "true"
            , A.attribute "aria-label" "Command palette"
            , A.attribute "aria-hidden"
                (if model.paletteOpen then
                    "false"

                 else
                    "true"
                )
            ]
            [ div [ class "palette-panel glass-strong" ]
                [ div [ class "palette-input-row" ]
                    [ span [ class "pfx", A.attribute "aria-hidden" "true" ]
                        [ text
                            (if model.paletteMode == "search" then
                                "/"

                             else
                                ":"
                            )
                        ]
                    , input
                        [ id "palette-input"
                        , A.attribute "autocomplete" "off"
                        , A.spellcheck False
                        , A.attribute "aria-label" "Command or search"
                        , A.attribute "role" "searchbox"
                        , A.tabindex
                            (if model.paletteOpen then
                                0

                             else
                                -1
                            )
                        , A.disabled (not model.paletteOpen)
                        , A.value model.paletteQuery
                        , E.onInput PaletteInput
                        , E.preventDefaultOn "keydown" paletteInputKeyDecoder
                        ]
                        []
                    ]
                , ul
                    [ class "palette-results"
                    , A.attribute "role" "listbox"
                    , A.attribute "aria-label" "Palette results"
                    ]
                    (List.indexedMap (viewPaletteItem model) items)
                ]
            ]
        ]


viewBufferItem : Model -> Int -> Buffer -> Html Msg
viewBufferItem model index buf =
    let
        cls =
            String.join " "
                ([ "buffer-item" ]
                    ++ (if index == model.focusIdx then
                            [ "focused" ]

                        else
                            []
                       )
                    ++ (if buf.id == model.activeId then
                            [ "active" ]

                        else
                            []
                       )
                )
    in
    li
        [ class cls
        , A.attribute "role" "option"
        , A.tabindex -1
        , A.attribute "aria-selected"
            (if index == model.focusIdx then
                "true"

             else
                "false"
            )
        , E.onClick (ClickBuffer index buf.id)
        ]
        [ span [ class "icon", A.attribute "aria-hidden" "true" ] [ text buf.icon ]
        , span [ class "name" ] [ text buf.label ]
        , span [ class "badge" ] [ text buf.badge ]
        ]


viewPaletteItem : Model -> Int -> PaletteItem -> Html Msg
viewPaletteItem model index item =
    li
        [ class
            (if index == model.paletteFocus then
                "focused"

             else
                ""
            )
        , A.attribute "role" "option"
        , A.tabindex -1
        , A.attribute "aria-selected"
            (if index == model.paletteFocus then
                "true"

             else
                "false"
            )
        , E.onClick (PaletteClick index)
        ]
        [ span [] [ text item.label ]
        , span [ class "desc" ] [ text item.desc ]
        ]


-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
