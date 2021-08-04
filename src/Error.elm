module Error exposing (Error(..), toString, fromString)

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
            "Runtime Error: " ++ err


fromString : String -> Error
fromString =
    RuntimeError
