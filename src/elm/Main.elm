module Main exposing (main)

{-| Wiring only: boot, dispatch, subscriptions. The shell itself lives in
Shell.* — see Shell.Model for the state every other module shares.
-}

import Browser
import Browser.Events
import Http
import Resume
import Shell.Buffer as Buffer exposing (openBuffer)
import Shell.Commands as Commands exposing (handleTerm)
import Shell.Keyboard as Keyboard exposing (handleKey, keyDecoder)
import Shell.Model as Model exposing (Flags, Mode(..), Model, Msg(..))
import Shell.Palette as Palette exposing (acceptPalette)
import Shell.View as View exposing (view)

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


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onKeyDown keyDecoder


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
