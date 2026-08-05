module Highlight exposing (Token, tokenize, viewCode)

import Html exposing (Html, pre, span, text)
import Html.Attributes exposing (class)


type alias Token =
    { cls : String
    , text : String
    }


viewCode : String -> Html msg
viewCode src =
    pre [ class "code-block" ]
        (List.map tokenView (tokenize src))


tokenView : Token -> Html msg
tokenView t =
    if String.isEmpty t.cls then
        text t.text

    else
        span [ class t.cls ] [ text t.text ]


tokenize : String -> List Token
tokenize src =
    let
        chars =
            String.toList src

        loop i acc =
            if i >= List.length chars then
                List.reverse acc

            else
                let
                    c =
                        nth i chars
                in
                if c == '/' && nth (i + 1) chars == '/' then
                    let
                        ( end, tok ) =
                            takeLineComment chars i
                    in
                    loop end (tok :: acc)

                else if c == '(' && nth (i + 1) chars == '*' then
                    let
                        ( end, tok ) =
                            takeBlockComment chars i
                    in
                    loop end (tok :: acc)

                else if c == '"' then
                    let
                        ( end, tok ) =
                            takeString chars i
                    in
                    loop end (tok :: acc)

                else if Char.isDigit c then
                    let
                        ( end, tok ) =
                            takeWhile chars i (\ch -> Char.isDigit ch || ch == '.' || ch == '_') "nu"
                    in
                    loop end (tok :: acc)

                else if Char.isAlpha c || c == '_' then
                    let
                        ( end, word ) =
                            takeIdent chars i

                        cls =
                            classify word chars end
                    in
                    loop end ({ cls = cls, text = word } :: acc)

                else
                    let
                        ( end, plain ) =
                            takePlain chars i
                    in
                    loop end ({ cls = "", text = plain } :: acc)
    in
    loop 0 []


nth : Int -> List Char -> Char
nth i xs =
    List.drop i xs |> List.head |> Maybe.withDefault ' '


takeLineComment : List Char -> Int -> ( Int, Token )
takeLineComment chars start =
    let
        rest =
            List.drop start chars

        body =
            takeUntilNewline rest

        n =
            String.length body
    in
    ( start + n, { cls = "cm", text = body } )


takeUntilNewline : List Char -> String
takeUntilNewline xs =
    case xs of
        [] ->
            ""

        c :: rest ->
            if c == '\n' then
                ""

            else
                String.fromChar c ++ takeUntilNewline rest


takeBlockComment : List Char -> Int -> ( Int, Token )
takeBlockComment chars start =
    let
        go i =
            if i + 1 >= List.length chars then
                List.length chars

            else if nth i chars == '*' && nth (i + 1) chars == ')' then
                i + 2

            else
                go (i + 1)

        end =
            go (start + 2)

        text_ =
            chars |> List.drop start |> List.take (end - start) |> String.fromList
    in
    ( end, { cls = "cm", text = text_ } )


takeString : List Char -> Int -> ( Int, Token )
takeString chars start =
    let
        go i =
            if i >= List.length chars then
                i

            else if nth i chars == '\\' then
                go (i + 2)

            else if nth i chars == '"' then
                i + 1

            else
                go (i + 1)

        end =
            go (start + 1)

        text_ =
            chars |> List.drop start |> List.take (end - start) |> String.fromList
    in
    ( end, { cls = "st", text = text_ } )


takeWhile : List Char -> Int -> (Char -> Bool) -> String -> ( Int, Token )
takeWhile chars start pred cls =
    let
        go i =
            if i >= List.length chars then
                i

            else if pred (nth i chars) then
                go (i + 1)

            else
                i

        end =
            go start

        text_ =
            chars |> List.drop start |> List.take (end - start) |> String.fromList
    in
    ( end, { cls = cls, text = text_ } )


takeIdent : List Char -> Int -> ( Int, String )
takeIdent chars start =
    let
        go i =
            if i >= List.length chars then
                i

            else
                let
                    c =
                        nth i chars
                in
                if Char.isAlphaNum c || c == '_' then
                    go (i + 1)

                else
                    i

        end =
            go start

        word =
            chars |> List.drop start |> List.take (end - start) |> String.fromList
    in
    ( end, word )


takePlain : List Char -> Int -> ( Int, String )
takePlain chars start =
    let
        stop c =
            c == '/' || c == '(' || c == '"' || Char.isDigit c || Char.isAlpha c || c == '_'

        go i =
            if i >= List.length chars then
                i

            else if stop (nth i chars) then
                i

            else
                go (i + 1)

        end =
            go (start + 1)

        text_ =
            chars |> List.drop start |> List.take (end - start) |> String.fromList
    in
    ( end, text_ )


classify : String -> List Char -> Int -> String
classify word chars end =
    if isKw word then
        "kw"

    else if isTy word then
        "ty"

    else
        let
            rest =
                List.drop end chars

            skipped =
                dropWhile (\c -> c == ' ' || c == '\t') rest
        in
        case skipped of
            '(' :: _ ->
                "fn"

            _ ->
                ""


dropWhile : (a -> Bool) -> List a -> List a
dropWhile pred xs =
    case xs of
        [] ->
            []

        h :: t ->
            if pred h then
                dropWhile pred t

            else
                xs


isKw : String -> Bool
isKw w =
    List.member w
        [ "fn"
        , "let"
        , "mut"
        , "use"
        , "pub"
        , "async"
        , "await"
        , "return"
        , "open"
        , "in"
        , "if"
        , "else"
        , "match"
        , "struct"
        , "impl"
        , "trait"
        , "const"
        , "type"
        , "mod"
        , "crate"
        , "self"
        , "Self"
        , "true"
        , "false"
        , "and"
        , "or"
        , "not"
        , "as"
        , "for"
        , "while"
        , "loop"
        , "break"
        , "continue"
        , "where"
        , "move"
        , "ref"
        , "static"
        , "unsafe"
        , "extern"
        , "super"
        , "dyn"
        , "box"
        ]


isTy : String -> Bool
isTy w =
    List.member w
        [ "Ok"
        , "Err"
        , "Some"
        , "None"
        , "Result"
        , "Option"
        , "String"
        , "str"
        , "bool"
        , "u8"
        , "u16"
        , "u32"
        , "u64"
        , "i8"
        , "i16"
        , "i32"
        , "i64"
        , "usize"
        , "isize"
        , "f32"
        , "f64"
        , "char"
        , "Vec"
        , "Box"
        , "Self"
        , "Cents"
        , "Event"
        , "EventBus"
        , "GpuFleet"
        , "Ack"
        , "Decode"
        , "BsResult"
        ]
        || (case String.uncons w of
                Just ( c, _ ) ->
                    Char.isUpper c

                Nothing ->
                    False
           )
