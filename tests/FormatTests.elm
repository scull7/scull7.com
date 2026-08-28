module FormatTests exposing (suite)

import Expect
import Format
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Format"
        [ test "formatDate names the month" <|
            \_ -> Format.formatDate "2024-04" |> Expect.equal "April 2024"
        , test "formatDate of empty is empty" <|
            \_ -> Format.formatDate "" |> Expect.equal ""
        , test "formatDate keeps the year when the month is out of range" <|
            \_ -> Format.formatDate "2024-13" |> Expect.equal "2024"
        , test "formatDate keeps the year when the month is not an int" <|
            \_ -> Format.formatDate "2024-xx" |> Expect.equal "2024"
        , test "formatDateRange with no end reads Present, en-dash" <|
            \_ ->
                Format.formatDateRange "2024-04" ""
                    |> Expect.equal "April 2024 – Present"
        ]
