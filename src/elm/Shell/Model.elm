module Shell.Model exposing
    ( Flags
    , KeyInfo
    , Mode(..)
    , Model
    , Msg(..)
    , PaletteItem
    , activeBuf
    , armG
    , bufferList
    , clearG
    , dummyBuf
    , fetchResume
    , setMsg
    )

{-| The shell's state and the handful of one-liners that every other Shell
module needs. Kept dependency-free so nothing below it has to import upward.
-}

import Buffers exposing (Buffer)
import Http
import Process
import Resume
import Task

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


{-| The one place that asks for the resume, so boot and `:reload` cannot
drift apart.
-}
fetchResume : Cmd Msg
fetchResume =
    Http.get
        { url = "/resume.json"
        , expect = Http.expectJson GotResume Resume.decoder
        }
