module ContentType exposing (ContentType(..), fromString, toString)


type ContentType
    = Text_Html
    | Application_Json
    | Other String


toString : ContentType -> String
toString type_ =
    case type_ of
        Text_Html ->
            "text/html"

        Application_Json ->
            "application/json"

        Other str ->
            str


fromString : String -> ContentType
fromString type_ =
    case type_ of
        "text/html" ->
            Text_Html

        "application/json" ->
            Application_Json

        _ ->
            Other type_
