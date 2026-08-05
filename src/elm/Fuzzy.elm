module Fuzzy exposing (rankLabel, score)


score : String -> String -> Maybe Int
score query text =
    let
        q =
            String.toLower query

        t =
            String.toLower text
    in
    if String.isEmpty q then
        Just 0

    else if t == q then
        Just 0

    else if String.startsWith q t then
        Just 10

    else
        case findSubstr t q of
            Just idx ->
                Just (30 + idx)

            Nothing ->
                subsequenceScore q t


findSubstr : String -> String -> Maybe Int
findSubstr hay needle =
    let
        nlen =
            String.length needle

        hlen =
            String.length hay
    in
    if nlen == 0 then
        Just 0

    else if nlen > hlen then
        Nothing

    else
        List.range 0 (hlen - nlen)
            |> List.filter (\i -> String.slice i (i + nlen) hay == needle)
            |> List.head


subsequenceScore : String -> String -> Maybe Int
subsequenceScore q t =
    let
        qChars =
            String.toList q

        go remaining qs gaps =
            case qs of
                [] ->
                    Just (100 + gaps)

                c :: cs ->
                    case String.indexes (String.fromChar c) remaining of
                        [] ->
                            Nothing

                        i :: _ ->
                            let
                                after =
                                    String.dropLeft (i + 1) remaining
                            in
                            go after cs (gaps + i)
    in
    go t qChars 0


rankLabel : String -> String -> String -> Maybe Int
rankLabel query label desc =
    case ( score query label, score query desc ) of
        ( Just x, Just y ) ->
            Just (min x y)

        ( Just x, Nothing ) ->
            Just x

        ( Nothing, Just y ) ->
            Just (y + 5)

        ( Nothing, Nothing ) ->
            Nothing
