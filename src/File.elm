module File exposing (load)

import Internal.Server exposing (Context(..), runTask)
import Json.Encode
import Server exposing (ReadyContext)


load : String -> ReadyContext
load path =
    runTask "FILE_SYSTEM_READ" (Json.Encode.string path)
