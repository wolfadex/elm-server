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
import Internal.Server exposing (Context(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Response
import Server exposing (Method(..), Path, ReadyContext)


tableName : String
tableName =
    "persons"


create : PartialPerson -> ReadyContext
create (PartialPerson _ { name, age }) =
    if String.isEmpty name then
        Server.resultToContext (Err "Must have a name")

    else if age < 0 then
        Server.resultToContext (Err "Age must be a positive number")

    else
        { tableName = tableName
        , columnValues = [ Database.Postgres.wrapString name, String.fromInt age ]
        }
            |> Database.Postgres.insertQuery
            |> Database.Postgres.query


get : WhereCondition -> ReadyContext
get where_ =
    { tableName = tableName
    , where_ = where_
    }
        |> Database.Postgres.selectQuery
        |> Database.Postgres.query
        |> Server.andThen (reencode >> Server.resultToContext)


delete : Int -> ReadyContext
delete id =
    { tableName = tableName
    , where_ = Equal "id" (String.fromInt id)
    }
        |> Database.Postgres.deleteQuery
        |> Database.Postgres.query


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


handler : Path -> Context -> ReadyContext
handler path context =
    case path of
        [] ->
            case Server.getMethod context of
                Ok Get ->
                    get NoCondition
                        |> Server.onError (\err -> Server.respond (Response.error err) context)
                        |> Server.onSuccess (\persons -> Server.respond (Response.json persons) context)

                Ok Post ->
                    case Server.getBody context |> Result.andThen (Json.Decode.decodeString decodePartial >> Result.mapError Json.Decode.errorToString) of
                        Ok partialPerson ->
                            create partialPerson
                                |> Server.onError (\err -> Server.respond (Response.error err) context)
                                |> Server.onSuccess (\id -> Server.respond (Response.json id) context)

                        Err err ->
                            Server.respond (Response.error err) context

                Ok _ ->
                    Server.respond Response.methodNotAllowed context

                Err err ->
                    Server.respond (Response.error err) context

        [ maybeId ] ->
            case ( Server.getMethod context, String.toInt maybeId ) of
                ( Ok Delete, Just id ) ->
                    delete id
                        |> Server.onError (\err -> Server.respond (Response.error err) context)
                        |> Server.onSuccess (\persons -> Server.respond (Response.json persons) context)

                ( Ok _, Just _ ) ->
                    Server.respond Response.methodNotAllowed context

                ( Ok _, Nothing ) ->
                    Server.respond (Response.error "Expected a valid id") context

                ( Err err, _ ) ->
                    Server.respond (Response.error err) context

        _ ->
            Server.respond Response.notFound context
