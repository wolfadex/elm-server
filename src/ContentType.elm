module ContentType exposing (ContentType(..), fromString, toString)


type ContentType
    = Text_Html
    | Application_Json


toString : ContentType -> String
toString type_ =
    case type_ of
        Text_Html ->
            "text/html"

        Application_Json ->
            "application/json"


fromString : String -> Maybe ContentType
fromString maybeType =
    case maybeType of
        "text/html" ->
            Just Text_Html

        "application/json" ->
            Just Application_Json

        _ ->
            Nothing
