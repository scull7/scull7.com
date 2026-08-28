module Shell.View exposing (view)

{-| The shell chrome: sidebar, buffer body, palette, statusline. -}

import Html exposing (..)
import Html.Attributes as A exposing (class, id)
import Html.Events as E
import Resume
import Shell.Items as Items exposing (updatedMeta, viewBufferItem, viewPaletteItem)
import Shell.Keyboard as Keyboard exposing (paletteInputKeyDecoder)
import Shell.Model as Model exposing (Mode(..), Model, Msg(..), PaletteItem, activeBuf, bufferList)
import Shell.Palette as Palette exposing (paletteItems)
import Views

view : Model -> Html Msg
view model =
    case model.loadError of
        Just err ->
            viewLoadFailure model err

        Nothing ->
            case model.resume of
                Nothing ->
                    div [ id "vim-root" ]
                        [ div [ class "galaxy", A.attribute "aria-hidden" "true" ] []
                        , div [ class "buffer-body" ] [ text "Loading resume…" ]
                        ]

                Just data ->
                    viewShell model data


{-| A failed resume fetch keeps the shell up. The terminal is the product,
so the failure is reported in-buffer with the retry command spelled out,
rather than collapsing to a bare message or a marketing error page. No
resume data is rendered, so nothing stale can leak through.
-}
viewLoadFailure : Model -> String -> Html Msg
viewLoadFailure model err =
    div [ id "vim-root" ]
        [ div [ class "galaxy", A.attribute "aria-hidden" "true" ] []
        , div [ class "shell" ]
            [ div
                [ class "buffer-body"
                , id "buffer-body"
                , A.tabindex 0
                ]
                [ div [ class "load-error" ]
                    [ p [ class "load-error-line" ] [ text err ]
                    , p [ class "load-error-line" ]
                        [ text "The resume buffer could not be read." ]
                    , p [ class "load-error-hint" ]
                        [ text "Type "
                        , span [ class "kw" ] [ text ":reload" ]
                        , text " to try again."
                        ]
                    ]
                ]
            ]
        , div [ class "bottom-chrome" ]
            [ footer [ class "statusline" ]
                [ span [ class "mode error" ] [ text "NORMAL" ]
                , span [ class "file" ] [ text "resume.json" ]
                , span [ class "spacer" ] []
                , span [ class "meta" ] [ span [] [ text "load failed" ] ]
                ]
            , div [ class "cmdline" ]
                [ span [ class "msg error" ] [ text (err ++ " — :reload to retry") ]
                ]
            ]
        , viewPalette model (paletteItems model)
        ]

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
                    ([ span [] [ text data.profile.location ]
                     , span [] [ text (String.fromInt (model.focusIdx + 1) ++ ":1") ]
                     ]
                        ++ updatedMeta data.lastUpdated
                        ++ [ span [] [ text "utf-8" ] ]
                    )
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
        , viewPalette model items
        ]



{-| The command palette. The shell and the load-failure screen both
    render it, so `:reload` is reachable even when no resume loaded.
-}
viewPalette : Model -> List PaletteItem -> Html Msg
viewPalette model items =
    let
        paletteCls =
            if model.paletteOpen then
                "palette open"

            else
                "palette"
    in
    div
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