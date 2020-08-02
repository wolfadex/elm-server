module SecureWorld exposing (main)

import Response
import Server exposing (Config, Context, Flags, ReadyContext)
import Status exposing (Status(..))


main : Server.Program
main =
    Server.program
        { init = init
        , handler = handler
        }


init : Flags -> Config
init _ =
    Server.baseConfig
        |> Server.makeSecure
            { certificatePath = "./examples/cert.pem"
            , keyPath = "./examples/private.pem"
            }


handler : Context -> ReadyContext
handler context =
    case Server.matchPath context of
        Result.Ok [] ->
            Server.respond (Response.default |> Response.setBody "Hello, HTTPS") context

        Result.Ok _ ->
            Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context
