module Logger exposing (toConsole)

import Internal.Server exposing (Context(..))
import Json.Encode


toConsole : String -> Context -> Context
toConsole message (Context context) =
    Context
        { context
            | commands =
                { msg = "PRINT"
                , args = Json.Encode.string message
                }
                    :: context.commands
        }
