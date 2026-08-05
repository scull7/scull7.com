module Format exposing
    ( companyLabel
    , formatDate
    , formatDateRange
    , locationLabel
    , profileUrl
    , slugify
    )


months : List String
months =
    [ "January"
    , "February"
    , "March"
    , "April"
    , "May"
    , "June"
    , "July"
    , "August"
    , "September"
    , "October"
    , "November"
    , "December"
    ]


formatDate : String -> String
formatDate iso =
    if String.isEmpty iso then
        ""

    else
        case String.split "-" iso of
            y :: m :: _ ->
                case String.toInt m of
                    Just n ->
                        if n >= 1 && n <= 12 then
                            Maybe.withDefault y (List.drop (n - 1) months |> List.head)
                                ++ " "
                                ++ y

                        else
                            y

                    Nothing ->
                        y

            [ y ] ->
                y

            _ ->
                iso


formatDateRange : String -> String -> String
formatDateRange startDate endDate =
    let
        start =
            formatDate startDate
    in
    if String.isEmpty start then
        ""

    else if String.isEmpty endDate then
        start ++ " – Present"

    else
        start ++ " – " ++ formatDate endDate


slugify : String -> String
slugify text =
    let
        lower =
            String.toLower text

        step ch ( out, prevDash ) =
            let
                c =
                    Char.toCode ch

                isAz =
                    c >= 97 && c <= 122

                isDigit =
                    c >= 48 && c <= 57
            in
            if isAz || isDigit then
                ( out ++ String.fromChar ch, False )

            else if not prevDash && not (String.isEmpty out) then
                ( out ++ "-", True )

            else
                ( out, prevDash )

        ( raw, _ ) =
            String.foldl step ( "", False ) lower

        trimmed =
            if String.endsWith "-" raw then
                String.dropRight 1 raw

            else
                raw
    in
    String.left 48 trimmed


locationLabel : String -> String -> String
locationLabel city region =
    if not (String.isEmpty city) && not (String.isEmpty region) then
        city ++ ", " ++ region

    else if not (String.isEmpty city) then
        city

    else
        region


companyLabel : String -> String -> String
companyLabel name description =
    if String.isEmpty description then
        name

    else
        name ++ " (" ++ description ++ ")"


profileUrl : List { a | network : String, url : String } -> String -> String
profileUrl profiles network =
    let
        target =
            String.toLower network
    in
    profiles
        |> List.filter (\p -> String.toLower p.network == target)
        |> List.head
        |> Maybe.map .url
        |> Maybe.withDefault ""
