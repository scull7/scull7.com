module HighlightTests exposing (suite)

import Expect
import Highlight
import Test exposing (Test, describe, test)


hasToken : String -> String -> List Highlight.Token -> Bool
hasToken cls text tokens =
    List.any (\t -> t.cls == cls && t.text == text) tokens


hasClass : String -> List Highlight.Token -> Bool
hasClass cls tokens =
    List.any (\t -> t.cls == cls) tokens


suite : Test
suite =
    describe "Highlight"
        [ test "empty source yields no tokens" <|
            \_ -> Highlight.tokenize "" |> Expect.equal []
        , test "fn is a keyword token" <|
            \_ ->
                Highlight.tokenize "fn x"
                    |> hasToken "kw" "fn"
                    |> Expect.equal True
        , test "a line comment is a comment token" <|
            \_ ->
                Highlight.tokenize "//c"
                    |> hasClass "cm"
                    |> Expect.equal True
        , test "a quoted literal is a string token" <|
            \_ ->
                Highlight.tokenize "\"ab\""
                    |> hasClass "st"
                    |> Expect.equal True
        ]
