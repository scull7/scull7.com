module FuzzyTests exposing (suite)

import Expect
import Fuzzy
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Fuzzy"
        [ test "an exact match scores 0" <|
            \_ -> Fuzzy.score "abc" "abc" |> Expect.equal (Just 0)
        , test "a prefix match scores 10" <|
            \_ -> Fuzzy.score "a" "abc" |> Expect.equal (Just 10)
        , test "an empty query scores 0" <|
            \_ -> Fuzzy.score "" "abc" |> Expect.equal (Just 0)
        , test "no match is Nothing" <|
            \_ -> Fuzzy.score "zzz" "abc" |> Expect.equal Nothing
        ]
