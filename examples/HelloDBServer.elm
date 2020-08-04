module HelloDBServer exposing (main)

import Database.Postgres as Database exposing (WhereCondition(..))
import File
import Json.Decode
import Person
import Response
import Server exposing (Config, Context, Flags, Method(..), ReadyContext)
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
        |> Database.connect
            { hostname = "localhost"
            , port_ = 5432
            , database = "postgres"
            , user = "postgres"
            , password = "postgres"
            }


handler : Context -> ReadyContext
handler context =
    case Server.matchPath context of
        Result.Ok path ->
            case path of
                [] ->
                    File.load "./examples/hello-db-client.html"
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

                "persons" :: rest ->
                    Person.handler rest context

                _ ->
                    Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context
