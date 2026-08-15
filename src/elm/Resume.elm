module Resume exposing
    ( Doc
    , EduView
    , JobView
    , OssView
    , Profile
    , ProjectLink
    , SkillsView
    , View
    , ViewProfile
    , decoder
    , mapResume
    )

import Format exposing
    ( companyLabel
    , formatDate
    , formatDateRange
    , locationLabel
    , profileUrl
    , slugify
    )
import Json.Decode as D exposing (Decoder)


type alias Profile =
    { network : String
    , username : String
    , url : String
    }


type alias Location =
    { city : String
    , region : String
    , countryCode : String
    }


type alias Basics =
    { name : String
    , label : String
    , email : String
    , url : String
    , summary : String
    , location : Location
    , profiles : List Profile
    }


type alias Work =
    { name : String
    , position : String
    , location : String
    , startDate : String
    , endDate : String
    , url : String
    , description : String
    , summary : String
    , highlights : List String
    }


type alias Education =
    { institution : String
    , area : String
    , studyType : String
    , startDate : String
    , endDate : String
    }


type alias Skill =
    { name : String
    , level : String
    , keywords : List String
    }


type alias Project =
    { name : String
    , description : String
    , url : String
    , github : String
    , keywords : List String
    , entity : String
    }


type alias Interest =
    { name : String
    , keywords : List String
    }


type alias Doc =
    { basics : Basics
    , work : List Work
    , education : List Education
    , skills : List Skill
    , projects : List Project
    , interests : List Interest
    , philosophy : String
    }


type alias ViewProfile =
    { name : String
    , tagline : String
    , location : String
    , email : String
    , linkedin : String
    , github : String
    , crates : String
    , site : String
    }


type alias JobView =
    { id : String
    , company : String
    , role : String
    , location : String
    , dates : String
    , bullets : List String
    }


type alias OssView =
    { name : String
    , lang : String
    , url : String
    , blurb : String
    }


type alias EduView =
    { school : String
    , detail : String
    , dates : String
    }


type alias SkillsView =
    { languagesActive : List String
    , languagesPrior : List String
    , web : List String
    , data : List String
    , infra : List String
    , cloud : List String
    , cicd : List String
    }


type alias ProjectLink =
    { name : String
    , description : String
    , url : String
    , github : String
    }


type alias View =
    { profile : ViewProfile
    , summary : String
    , competencies : List String
    , highlights : List String
    , experience : List JobView
    , openSource : List OssView
    , skills : SkillsView
    , education : List EduView
    , crossrSkills : Maybe ProjectLink
    , philosophy : String
    }


str : Decoder String
str =
    D.oneOf [ D.string, D.null "" ]


profileDecoder : Decoder Profile
profileDecoder =
    D.map3 Profile
        (D.field "network" str)
        (D.field "username" str)
        (D.field "url" str)


locationDecoder : Decoder Location
locationDecoder =
    D.map3 Location
        (D.field "city" str)
        (D.field "region" str)
        (D.field "countryCode" str)


basicsDecoder : Decoder Basics
basicsDecoder =
    D.map7 Basics
        (D.field "name" str)
        (D.field "label" str)
        (D.field "email" str)
        (D.field "url" str)
        (D.field "summary" str)
        (D.field "location" locationDecoder)
        (D.field "profiles" (D.list profileDecoder))


workDecoder : Decoder Work
workDecoder =
    D.map7
        (\name position location startDate endDate url description ->
            { name = name
            , position = position
            , location = location
            , startDate = startDate
            , endDate = endDate
            , url = url
            , description = description
            , summary = ""
            , highlights = []
            }
        )
        (D.field "name" str)
        (D.field "position" str)
        (D.oneOf [ D.field "location" str, D.succeed "" ])
        (D.oneOf [ D.field "startDate" str, D.succeed "" ])
        (D.oneOf [ D.field "endDate" str, D.succeed "" ])
        (D.oneOf [ D.field "url" str, D.succeed "" ])
        (D.oneOf [ D.field "description" str, D.succeed "" ])
        |> D.andThen
            (\base ->
                D.map2
                    (\summary highlights ->
                        { base | summary = summary, highlights = highlights }
                    )
                    (D.oneOf [ D.field "summary" str, D.succeed "" ])
                    (D.oneOf [ D.field "highlights" (D.list str), D.succeed [] ])
            )


eduDecoder : Decoder Education
eduDecoder =
    D.map5 Education
        (D.field "institution" str)
        (D.oneOf [ D.field "area" str, D.succeed "" ])
        (D.oneOf [ D.field "studyType" str, D.succeed "" ])
        (D.oneOf [ D.field "startDate" str, D.succeed "" ])
        (D.oneOf [ D.field "endDate" str, D.succeed "" ])


skillDecoder : Decoder Skill
skillDecoder =
    D.map3 Skill
        (D.field "name" str)
        (D.oneOf [ D.field "level" str, D.succeed "" ])
        (D.oneOf [ D.field "keywords" (D.list str), D.succeed [] ])


projectDecoder : Decoder Project
projectDecoder =
    D.map6 Project
        (D.field "name" str)
        (D.oneOf [ D.field "description" str, D.succeed "" ])
        (D.oneOf [ D.field "url" str, D.succeed "" ])
        (D.oneOf [ D.field "github" str, D.succeed "" ])
        (D.oneOf [ D.field "keywords" (D.list str), D.succeed [] ])
        (D.oneOf [ D.field "entity" str, D.succeed "" ])


interestDecoder : Decoder Interest
interestDecoder =
    D.map2 Interest
        (D.field "name" str)
        (D.oneOf [ D.field "keywords" (D.list str), D.succeed [] ])


decoder : Decoder Doc
decoder =
    D.map7 Doc
        (D.field "basics" basicsDecoder)
        (D.oneOf [ D.field "work" (D.list workDecoder), D.succeed [] ])
        (D.oneOf [ D.field "education" (D.list eduDecoder), D.succeed [] ])
        (D.oneOf [ D.field "skills" (D.list skillDecoder), D.succeed [] ])
        (D.oneOf [ D.field "projects" (D.list projectDecoder), D.succeed [] ])
        (D.oneOf [ D.field "interests" (D.list interestDecoder), D.succeed [] ])
        (D.oneOf [ D.field "philosophy" str, D.succeed "" ])


skillKeywords : List Skill -> String -> List String
skillKeywords skills name =
    skills
        |> List.filter (\s -> s.name == name)
        |> List.head
        |> Maybe.map .keywords
        |> Maybe.withDefault []


isOssProject : Project -> Bool
isOssProject p =
    let
        hasOss =
            List.any (\k -> String.contains "open-source" (String.toLower k)) p.keywords

        n =
            String.toLower p.name
    in
    hasOss || String.startsWith "cents" n || String.startsWith "bs-" n


projectLang : Project -> String
projectLang p =
    let
        langs =
            [ "Rust", "ReasonML", "OCaml", "JavaScript", "Haskell" ]

        match =
            List.filterMap
                (\k ->
                    List.filter (\l -> String.toLower k == String.toLower l) langs
                        |> List.head
                )
                p.keywords
                |> List.head
    in
    case match of
        Just l ->
            l

        Nothing ->
            List.head p.keywords |> Maybe.withDefault ""


mapResume : Doc -> View
mapResume doc =
    let
        basics =
            doc.basics

        profiles =
            basics.profiles

        profile : ViewProfile
        profile =
            { name = basics.name
            , tagline = basics.label
            , location = locationLabel basics.location.city basics.location.region
            , email = basics.email
            , linkedin = profileUrl profiles "LinkedIn"
            , github = profileUrl profiles "GitHub"
            , crates = profileUrl profiles "Crates.io"
            , site = basics.url
            }

        competencies =
            case
                List.filter
                    (\i -> String.contains "core competencies" (String.toLower i.name))
                    doc.interests
                    |> List.head
            of
                Just i ->
                    i.keywords

                Nothing ->
                    doc.skills
                        |> List.concatMap .keywords
                        |> List.take 8

        highlights =
            doc.work
                |> List.concatMap .highlights
                |> List.filter (not << String.isEmpty)
                |> unique
                |> List.take 12

        experience =
            List.map
                (\job ->
                    let
                        idBase =
                            slugify job.name

                        id =
                            if String.isEmpty idBase then
                                let
                                    p =
                                        slugify job.position
                                in
                                if String.isEmpty p then
                                    "role"

                                else
                                    p

                            else
                                idBase
                    in
                    { id = id
                    , company = companyLabel job.name job.description
                    , role = job.position
                    , location = job.location
                    , dates = formatDateRange job.startDate job.endDate
                    , bullets = job.highlights
                    }
                )
                doc.work

        openSource =
            doc.projects
                |> List.filter isOssProject
                |> List.map
                    (\p ->
                        { name = p.name
                        , lang = projectLang p
                        , url = p.url
                        , blurb = p.description
                        }
                    )

        skillsView =
            { languagesActive = skillKeywords doc.skills "Languages (active)"
            , languagesPrior = skillKeywords doc.skills "Languages (prior)"
            , web = skillKeywords doc.skills "Web / UI"
            , data = skillKeywords doc.skills "Data"
            , infra = skillKeywords doc.skills "Infrastructure"
            , cloud = skillKeywords doc.skills "Cloud"
            , cicd = skillKeywords doc.skills "CI / CD"
            }

        eduView =
            List.map
                (\e ->
                    let
                        start =
                            formatDate e.startDate

                        end =
                            formatDate e.endDate

                        dates =
                            if not (String.isEmpty start) && not (String.isEmpty end) && start /= end then
                                start ++ " – " ++ end

                            else if not (String.isEmpty end) then
                                end

                            else
                                start

                        detail =
                            if not (String.isEmpty e.studyType) && not (String.isEmpty e.area) then
                                e.studyType ++ " · " ++ e.area

                            else if not (String.isEmpty e.studyType) then
                                e.studyType

                            else
                                e.area
                    in
                    { school = e.institution
                    , detail = detail
                    , dates = dates
                    }
                )
                doc.education

        crossrSkills =
            projectByName "crossr-skills" doc.projects
                |> Maybe.map toProjectLink
    in
    { profile = profile
    , summary = basics.summary
    , competencies = competencies
    , highlights = highlights
    , experience = experience
    , openSource = openSource
    , skills = skillsView
    , education = eduView
    , crossrSkills = crossrSkills
    , philosophy = doc.philosophy
    }


projectByName : String -> List Project -> Maybe Project
projectByName name projects =
    let
        needle =
            String.toLower name
    in
    projects
        |> List.filter (\p -> String.toLower p.name == needle)
        |> List.head


toProjectLink : Project -> ProjectLink
toProjectLink p =
    { name = p.name
    , description = p.description
    , url = p.url
    , github = p.github
    }


unique : List String -> List String
unique xs =
    List.foldl
        (\x acc ->
            if List.member x acc then
                acc

            else
                acc ++ [ x ]
        )
        []
        xs
