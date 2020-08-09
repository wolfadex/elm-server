module Error exposing (Error(..), toString)

import Json.Decode


type Error
    = TypeError Json.Decode.Error
    | RuntimeError String


toString : Error -> String
toString error =
    case error of
        TypeError err ->
            "Type Error: " ++ Json.Decode.errorToString err

        RuntimeError err ->
            "Runtime Error" ++ err
