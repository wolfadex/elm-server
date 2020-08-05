module SecureWorld exposing (main)

import Response
import Server exposing (Config, Flags, Request, Response)
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


handler : Request -> Response
handler request =
    case Server.matchPath request of
        Result.Ok [] ->
            Server.respond request (Response.default |> Response.setBody "Hello, HTTPS")

        Result.Ok _ ->
            Server.respond request Response.notFound

        Err err ->
            Server.respond request (Response.error err)
