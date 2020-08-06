module HelloFile exposing (main)

import File
import Json.Decode
import Response
import Result.Extra
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


handler : Request -> Response
handler request =
    case Server.matchPath request of
        Result.Ok [] ->
            File.load "./examples/hello.html"
                |> Server.onSuccess
                    (Json.Decode.decodeValue Json.Decode.string
                        >> Result.map
                            (\file ->
                                Response.default
                                    |> Response.setBody file
                                    |> Server.respond request
                            )
                        >> Result.mapError
                            (Json.Decode.errorToString >> Response.error >> Server.respond request)
                        >> Result.Extra.merge
                    )
                |> Server.onError (Response.error >> Server.respond request)

        Result.Ok _ ->
            Server.respond request Response.notFound

        Err err ->
            Server.respond request (Response.error err)
