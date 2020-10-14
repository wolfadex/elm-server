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
    case Server.getPath request of
        [] ->
            Server.respond request (Response.ok |> Response.setBody "Hello, HTTPS")

        _ ->
            Server.respond request Response.notFound
