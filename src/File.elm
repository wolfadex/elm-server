module File exposing (load)

import Internal.Server exposing (runTask)
import Json.Encode
import Server exposing (Response)


load : String -> Response
load path =
    runTask "FILE_SYSTEM_READ" (Json.Encode.string path)
