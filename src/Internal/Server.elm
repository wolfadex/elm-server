module Internal.Server exposing
    ( Certs
    , Config(..)
    , ConfigData
    , Context(..)
    , Request
    , RunnerResponse
    , Server(..)
    , Type(..)
    , runTask
    )

import Http
import Internal.Database exposing (DatabaseConnection)
import Json.Decode
import Json.Encode exposing (Value)
import Status exposing (Status(..))
import Task exposing (Task)


type alias RunnerResponse =
    { message : String
    , body : Value
    }


type alias Request =
    Value


type Context
    = Context ContextData


type alias ContextData =
    { request : Request
    , server : Server
    , requestId : String
    }


type Config
    = Config ConfigData


type alias ConfigData =
    { port_ : Int
    , type_ : Type
    , databaseConnection : Maybe DatabaseConnection
    , envPath : List String
    }


type Type
    = Basic
    | Secure Certs


type alias Certs =
    ()


type Server
    = NotYetStarted
    | Running


runTask : String -> Value -> Task String RunnerResponse
runTask name value =
    Http.task
        { method = "POST"
        , headers = []
        , url = "/runner"
        , body =
            [ ( "msg", Json.Encode.string name )
            , ( "args", value )
            ]
                |> Json.Encode.object
                |> Http.jsonBody
        , timeout = Nothing
        , resolver =
            (\response ->
                case response of
                    Http.BadUrl_ url ->
                        "Javscript Error: Bad Url: "
                            ++ url
                            |> Err

                    Http.Timeout_ ->
                        Err "Javascript took too long to respond"

                    Http.NetworkError_ ->
                        Err "Unknown javascript error resulted in a 'Network Error'"

                    Http.BadStatus_ _ body ->
                        Err body

                    Http.GoodStatus_ { statusText } body ->
                        Json.Decode.decodeString Json.Decode.value body
                            |> Result.map (\bodyJson -> { message = statusText, body = bodyJson })
                            |> Result.mapError Json.Decode.errorToString
            )
                |> Http.stringResolver
        }
