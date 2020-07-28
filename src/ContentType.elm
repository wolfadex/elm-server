module ContentType exposing (ContentType(..), fromString, toString)


type ContentType
    = Text_Html


toString : ContentType -> String
toString type_ =
    case type_ of
        Text_Html ->
            "text/html"


fromString : String -> Maybe ContentType
fromString maybeType =
    case maybeType of
        "text/html" ->
            Just Text_Html

        _ ->
            Nothing
