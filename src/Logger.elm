module Logger exposing (toConsole)

import Internal.Server exposing (Context(..), runTask)
import Json.Encode
import Server exposing (ReadyContext)


toConsole : String -> ReadyContext
toConsole message =
    runTask "PRINT" (Json.Encode.string message)
