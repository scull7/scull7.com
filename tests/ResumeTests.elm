module ResumeTests exposing (suite)

import Expect
import Json.Decode as D
import Resume
import Test exposing (Test, describe, test)


{-| Minimal fixture: the smallest JSON the decoder accepts, not a copy of
public/resume.json. Only `basics` is required; `work` is optional.
-}
minimalJson : String -> String
minimalJson work =
    """
    { "basics":
        { "name": "Ada Lovelace"
        , "label": "Mathematician"
        , "email": "ada@example.com"
        , "url": "https://example.com"
        , "summary": "Wrote the first algorithm."
        , "location": { "city": "London", "region": "", "countryCode": "GB" }
        , "profiles": []
        }
    , "work": """ ++ work ++ """
    }
    """


oneJob : String
oneJob =
    """[ { "name": "Analytical Engine"
         , "position": "Programmer"
         , "startDate": "1843-01"
         } ]"""


mapped : String -> Result D.Error Resume.View
mapped work =
    D.decodeString Resume.decoder (minimalJson work)
        |> Result.map Resume.mapResume


suite : Test
suite =
    describe "Resume.mapResume"
        [ test "carries the profile name through" <|
            \_ ->
                mapped oneJob
                    |> Result.map (.profile >> .name)
                    |> Expect.equal (Ok "Ada Lovelace")
        , test "maps exactly the jobs given" <|
            \_ ->
                mapped oneJob
                    |> Result.map (.experience >> List.length)
                    |> Expect.equal (Ok 1)
        , test "keeps the company name" <|
            \_ ->
                mapped oneJob
                    |> Result.map
                        (.experience
                            >> List.head
                            >> Maybe.map (.company >> String.contains "Analytical Engine")
                            >> Maybe.withDefault False
                        )
                    |> Expect.equal (Ok True)
        , test "keeps the role" <|
            \_ ->
                mapped oneJob
                    |> Result.map
                        (.experience
                            >> List.head
                            >> Maybe.map .role
                            >> Maybe.withDefault ""
                        )
                    |> Expect.equal (Ok "Programmer")
        , test "empty work invents no jobs" <|
            \_ ->
                mapped "[]"
                    |> Result.map .experience
                    |> Expect.equal (Ok [])
        ]
