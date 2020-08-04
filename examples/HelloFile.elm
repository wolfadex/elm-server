module HelloFile exposing (main)

import File
import Json.Decode
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


handler : Context -> ReadyContext
handler context =
    case Server.matchPath context of
        Result.Ok [] ->
            File.load "./examples/hello.html"
                |> Server.onSuccess
                    (\body ->
                        case Json.Decode.decodeValue Json.Decode.string body of
                            Result.Ok file ->
                                Server.respond
                                    (Response.default |> Response.setBody file)
                                    context

                            Err err ->
                                Server.respond
                                    (err
                                        |> Json.Decode.errorToString
                                        |> Response.error
                                    )
                                    context
                    )
                |> Server.onError (\err -> Server.respond (Response.error err) context)

        Result.Ok _ ->
            Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context
