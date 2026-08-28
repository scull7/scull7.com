module Shell.Items exposing (updatedMeta, viewBufferItem, viewPaletteItem)

{-| The sidebar and palette list rows. -}

import Buffers exposing (Buffer)
import Html exposing (..)
import Html.Attributes as A exposing (class)
import Html.Events as E
import Shell.Model as Model exposing (Mode(..), Model, Msg(..), PaletteItem)

updatedMeta : Maybe String -> List (Html msg)
updatedMeta lastUpdated =
    case lastUpdated of
        Just date ->
            [ span [] [ text ("updated " ++ date) ] ]

        Nothing ->
            []


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
