port module Ports exposing (blur, focus, openUrl, scrollBuffer)


port focus : String -> Cmd msg


{-| Blur the active element if it matches id (or any if id is "").
-}
port blur : String -> Cmd msg


{-| Navigate the window to url (mailto:, https:, …). Action lives at the JS edge.
-}
port openUrl : String -> Cmd msg


{-| action: "page" | "center"; dir: 1 down, -1 up (for page)
-}
port scrollBuffer : { action : String, dir : Int } -> Cmd msg
