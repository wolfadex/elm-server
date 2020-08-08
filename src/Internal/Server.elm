module Internal.Server exposing
    ( Certs
    , Config(..)
    , ConfigData
    , Query(..)
    , RequestData
    , Type(..)
    , query
    , runTask
    )

import Error exposing (Error(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Process
import Task exposing (Task)


type alias RequestData =
    Value


type Config
    = Config ConfigData


type alias ConfigData =
    { port_ : Int
    , type_ : Type
    , databaseConnection : Maybe DatabaseConnection
    , envPath : List String
    }


type alias DatabaseConnection =
    { hostname : String
    , port_ : Int
    , user : String
    , password : String
    , database : String
    }


type Type
    = Basic
    | Secure Certs


type alias Certs =
    { certificatePath : String
    , keyPath : String
    }


runTask : String -> Value -> Task Error Value
runTask message args =
    -- Http.task
    --     { method = "POST"
    --     , headers = []
    --     , url = "internal:/runner"
    --     , body =
    --         [ ( "msg", Json.Encode.string name )
    --         , ( "args", value )
    --         ]
    --             |> Json.Encode.object
    --             |> Http.jsonBody
    --     , timeout = Nothing
    --     , resolver =
    --         (\response ->
    --             case response of
    --                 Http.BadUrl_ url ->
    --                     "Javscript Error: Bad Url: "
    --                         ++ url
    --                         |> Err
    --                 Http.Timeout_ ->
    --                     Err "Javascript took too long to respond"
    --                 Http.NetworkError_ ->
    --                     Err "Unknown javascript error resulted in a 'Network Error'"
    --                 Http.BadStatus_ _ body ->
    --                     Err body
    --                 Http.GoodStatus_ _ body ->
    --                     Json.Decode.decodeString Json.Decode.value body
    --                         |> Result.mapError Json.Decode.errorToString
    --         )
    --             |> Http.stringResolver
    --     }
    evalAsync message args Json.Decode.value


type Query
    = Query String


query : Query -> Task Error Value
query (Query qry) =
    qry
        |> Json.Encode.string
        |> runTask "DATABASE_QUERY"


type alias Interop =
    Value


type alias Code =
    String



-- eval : List Value -> Code -> Decoder a -> Result Error a
-- eval params code decoder =
--     Json.Encode.object [ ( "__elm_interop", Json.Encode.list identity (Json.Encode.string code :: params) ) ]
--         |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop" (decodeEvalResult decoder))
--         |> Result.mapError TypeError
--         |> Result.andThen identity


evalAsync : String -> Value -> Decoder a -> Task Error a
evalAsync message args decoder =
    let
        token =
            Json.Encode.object []
    in
    Task.succeed ()
        |> Task.andThen
            (\_ ->
                let
                    _ =
                        Json.Encode.object [ ( "__elm_interop_async", Json.Encode.list identity [ token, Json.Encode.string message, args ] ) ]
                in
                -- 69 108 109 == Elm
                Process.sleep -69108109
            )
        |> Task.andThen
            (\_ ->
                case
                    Json.Encode.object [ ( "token", token ) ]
                        |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop_async" (decodeEvalResult decoder))
                        |> Result.mapError TypeError
                        |> Result.andThen identity
                of
                    Ok result ->
                        Task.succeed result

                    Err error ->
                        Task.fail error
            )


decodeEvalResult : Decoder a -> Decoder (Result Error a)
decodeEvalResult decodeResult =
    Json.Decode.field "tag" Json.Decode.string
        |> Json.Decode.andThen
            (\tag ->
                case tag of
                    "Ok" ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.decodeValue (Json.Decode.field "result" decodeResult) value
                                        |> Result.mapError TypeError
                                        |> Json.Decode.succeed
                                )

                    "Error" ->
                        Json.Decode.field "error" decodeRuntimeError
                            |> Json.Decode.map Err

                    _ ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.succeed
                                        (Json.Decode.Failure ("`tag` field must be one of Ok/Error, instead found `" ++ tag ++ "`") value
                                            |> TypeError
                                            |> Err
                                        )
                                )
            )


decodeRuntimeError : Decoder Error
decodeRuntimeError =
    Json.Decode.field "message" Json.Decode.string |> Json.Decode.map RuntimeError
