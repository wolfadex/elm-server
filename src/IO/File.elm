module IO.File exposing (readFile)

import Internal.IO exposing (IO)
import Json.Decode
import Json.Encode


readFile : String -> IO String
readFile path =
    Internal.IO.evalAsync "readFile"
        (Json.Encode.string path)
        Json.Decode.string
