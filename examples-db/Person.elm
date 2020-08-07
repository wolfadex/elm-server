module Person exposing
    ( PartialPerson
    , Person
    , decode
    , decodeMany
    , encode
    , getAge
    , getId
    , getName
    , handler
    , new
    )

import Database.Postgres exposing (WhereCondition(..))
import Http exposing (Response)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Response
import Result.Extra
import Server exposing (Method(..), Path, Request, Response)


tableName : String
tableName =
    "persons"


create : PartialPerson -> Response
create (PartialPerson _ { name, age }) =
    if String.isEmpty name then
        Server.resultToResponse (Err "Must have a name")

    else if age < 0 then
        Server.resultToResponse (Err "Age must be a positive number")

    else
        { tableName = tableName
        , columnValues = [ Database.Postgres.wrapString name, String.fromInt age ]
        }
            |> Database.Postgres.insertQuery
            |> Server.query


get : WhereCondition -> Response
get where_ =
    { tableName = tableName
    , where_ = where_
    }
        |> Database.Postgres.selectQuery
        |> Server.query
        |> Server.andThen (reencode >> Server.resultToResponse)


delete : Int -> Response
delete id =
    { tableName = tableName
    , where_ = Equal "id" (String.fromInt id)
    }
        |> Database.Postgres.deleteQuery
        |> Server.query


reencode : Value -> Result String Value
reencode value =
    Json.Decode.decodeValue decodeSqlMany value
        |> Result.map (Json.Encode.list encode)
        |> Result.mapError Json.Decode.errorToString


decodeSqlMany : Decoder (List Person)
decodeSqlMany =
    Json.Decode.list decodeSql


decodeSql : Decoder Person
decodeSql =
    Json.Decode.map3 (\id name age -> Person { id = id, name = name, age = age })
        (Json.Decode.index 0 Json.Decode.int)
        (Json.Decode.index 1 Json.Decode.string)
        (Json.Decode.index 2 Json.Decode.int)


decodeMany : Decoder (List Person)
decodeMany =
    Json.Decode.list decode


decode : Decoder Person
decode =
    Json.Decode.map3 (\id name age -> Person { id = id, name = name, age = age })
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "age" Json.Decode.int)


encode : Person -> Value
encode (Person { id, name, age }) =
    Json.Encode.object
        [ ( "id", Json.Encode.int id )
        , ( "name", Json.Encode.string name )
        , ( "age", Json.Encode.int age )
        ]


type alias PersonInternal =
    { id : Int
    , name : String
    , age : Int
    }


type Person
    = Person PersonInternal


getName : Person -> String
getName (Person { name }) =
    name


getAge : Person -> Int
getAge (Person { age }) =
    age


getId : Person -> Int
getId (Person { id }) =
    id


type alias PartialPersonInternal =
    { name : String
    , age : Int
    }


type PartialPerson
    = PartialPerson (List Error) PartialPersonInternal


decodePartial : Decoder PartialPerson
decodePartial =
    Json.Decode.map2 (\name age -> PartialPerson [] { name = name, age = age })
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "age" Json.Decode.int)


type Error
    = NameRequired
    | InvalidAge


new : PartialPerson
new =
    PartialPerson
        []
        { name = ""
        , age = 0
        }


handler : Request -> Path -> Response
handler request path =
    case path of
        [] ->
            Server.getMethod request
                |> Result.mapError (Response.error >> Server.respond request)
                |> Result.map
                    (\method ->
                        case method of
                            Get ->
                                get NoCondition
                                    |> Server.onError (Response.error >> Server.respond request)
                                    |> Server.onSuccess (Response.json >> Server.respond request)

                            Post ->
                                Server.getBody request
                                    |> Result.andThen
                                        (Json.Decode.decodeString decodePartial
                                            >> Result.mapError Json.Decode.errorToString
                                        )
                                    |> Result.mapError (Response.error >> Server.respond request)
                                    |> Result.map
                                        (create
                                            >> Server.onError (Response.error >> Server.respond request)
                                            >> Server.onSuccess (Response.json >> Server.respond request)
                                        )
                                    |> Result.Extra.merge

                            _ ->
                                Server.respond request Response.methodNotAllowed
                    )
                |> Result.Extra.merge

        [ maybeId ] ->
            case ( Server.getMethod request, String.toInt maybeId ) of
                ( Ok Delete, Just id ) ->
                    delete id
                        |> Server.onError (Response.error >> Server.respond request)
                        |> Server.onSuccess (Response.json >> Server.respond request)

                ( Ok _, Just _ ) ->
                    Server.respond request Response.methodNotAllowed

                ( Ok _, Nothing ) ->
                    Server.respond request (Response.error "Expected a valid id")

                ( Err err, _ ) ->
                    Server.respond request (Response.error err)

        _ ->
            Server.respond request Response.notFound
