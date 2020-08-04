module HelloDBServer exposing (main)

import Database.Postgres as Database exposing (WhereCondition(..))
import File
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Persons
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
        Result.Ok [] ->
            File.load "./examples/hello-db-client.html"
                |> Server.onSuccess
                    (\{ body } ->
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

        Result.Ok [ "persons" ] ->
            case Server.getMethod context of
                Result.Ok Get ->
                    Persons.select { where_ = NoCondition }
                        |> Server.onError
                            (\err -> Server.respond (Response.error err) context)
                        |> Server.onSuccess
                            (\{ body } ->
                                case reencodePersons body of
                                    Result.Ok persons ->
                                        Server.respond (Response.json persons) context

                                    Err err ->
                                        Server.respond (Response.error err) context
                            )

                Result.Ok Post ->
                    Debug.todo "handle post"

                Result.Ok _ ->
                    Server.respond Response.methodNotAllowed context

                Err err ->
                    Server.respond (Response.error err) context

        Result.Ok _ ->
            Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context


reencodePersons : Value -> Result String Value
reencodePersons value =
    Json.Decode.decodeValue decodePersons value
        |> Result.map (Json.Encode.list encodePerson)
        |> Result.mapError Json.Decode.errorToString


decodePersons : Decoder (List Person)
decodePersons =
    Json.Decode.list decodePerson


decodePerson : Decoder Person
decodePerson =
    Json.Decode.map3 Person
        (Json.Decode.index 0 Json.Decode.int)
        (Json.Decode.index 1 Json.Decode.string)
        (Json.Decode.index 2 Json.Decode.int)


encodePerson : Person -> Value
encodePerson { id, name, age } =
    Json.Encode.object
        [ ( "id", Json.Encode.int id )
        , ( "name", Json.Encode.string name )
        , ( "age", Json.Encode.int age )
        ]


type alias Person =
    { id : Int
    , name : String
    , age : Int
    }
