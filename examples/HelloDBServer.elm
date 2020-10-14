module HelloDBServer exposing (main)

import Database.Postgres exposing (WhereCondition(..))
import Error
import File
import Json.Decode
import Person
import Response
import Result.Extra
import Server exposing (Config, Flags, Method(..), Request, Response)
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
        |> Database.Postgres.connect
            { hostname = "localhost"
            , port_ = 5432
            , database = "postgres"
            , user = "postgres"
            , password = "postgres"
            }


handler : Request -> Response
handler request =
    case ( Server.getMethod request, Server.getPath request ) of
        ( Get, [] ) ->
            File.load "./examples/hello-db-client.html"
                |> Server.onSuccess
                    (Json.Decode.decodeValue Json.Decode.string
                        >> Result.map
                            (\file ->
                                Response.ok
                                    |> Response.setBody file
                                    |> Server.respond request
                            )
                        >> Result.mapError
                            (Json.Decode.errorToString >> Response.error >> Server.respond request)
                        >> Result.Extra.merge
                    )
                |> Server.onError (Error.toString >> Response.error >> Server.respond request)

        ( _, "persons" :: restOfPath ) ->
            Person.handler request restOfPath

        _ ->
            Server.respond request Response.notFound
