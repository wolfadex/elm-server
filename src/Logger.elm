module Logger exposing (toConsole)

import Internal.Server exposing (runTask)
import Json.Encode
import Server exposing (Response)


toConsole : String -> Response
toConsole message =
    runTask "PRINT" (Json.Encode.string message)
