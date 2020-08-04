port module Server exposing
    ( Config
    , Context
    , Flags
    , Method(..)
    , Path
    , Program
    , ReadyContext
    , andThen
    , baseConfig
    , envAtPath
    , getBody
    , getMethod
    , getPath
    , makeSecure
    , map
    , mapError
    , matchPath
    , onError
    , onSuccess
    , program
    , respond
    , resultToContext
    , withPort
    )

import ContentType
import Internal.Response exposing (InternalResponse(..))
import Internal.Server exposing (Certs, Config(..), Context, Server(..), Type(..), runTask)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Platform
import Result.Extra
import Status
import Task exposing (Task)


type alias Program =
    Platform.Program Flags Server Msg


type alias Flags =
    { environment : Value
    , arguments : Value
    }


type alias Context =
    Internal.Server.Context


type alias ReadyContext =
    Task String Value


type alias Config =
    Internal.Server.Config


type alias Path =
    List String


baseConfig : Config
baseConfig =
    Config
        { port_ = 1234
        , type_ = Internal.Server.Basic
        , databaseConnection = Nothing
        , envPath = []
        }


makeSecure : Certs -> Config -> Config
makeSecure certs (Config config) =
    Config { config | type_ = Secure certs }


withPort : Int -> Config -> Config
withPort port_ (Config config) =
    Config { config | port_ = port_ }


envAtPath : List String -> Config -> Config
envAtPath envPath (Config config) =
    Config { config | envPath = envPath }


type Msg
    = IncomingRequest IncomingRequestData
    | RunnerMessage RunnerMsg
    | Continuation (Result String Value)


type alias IncomingRequestData =
    { req : Value
    , id : String
    }


type alias RunnerMsg =
    { message : String
    , value : Value
    }


port requestPort : (IncomingRequestData -> msg) -> Sub msg


port runnerMsg : (RunnerMsg -> msg) -> Sub msg


program : { init : Flags -> Config, handler : Context -> ReadyContext } -> Program
program { init, handler } =
    Platform.worker
        { init =
            \flags ->
                let
                    (Config { port_, type_, databaseConnection }) =
                        init flags

                    finalPort =
                        Json.Decode.decodeValue (decodeEnv "port" Json.Decode.int) flags.arguments
                            |> Result.Extra.orElseLazy (\() -> Json.Decode.decodeValue (decodeEnv "PORT" Json.Decode.int) flags.environment)
                            |> Result.toMaybe
                            |> Maybe.withDefault port_
                in
                if finalPort < 1 || finalPort > 65535 then
                    ( NotYetStarted
                    , "Error: Invalid port: "
                        ++ String.fromInt finalPort
                        ++ ", must be between 1 and 65,535."
                        |> Json.Encode.string
                        |> runTask "PRINT"
                        |> executeTasks
                    )

                else
                    let
                        startupConfig =
                            Json.Encode.object
                                [ ( "port", Json.Encode.int finalPort )
                                , ( "databaseConnection"
                                  , case databaseConnection of
                                        Nothing ->
                                            Json.Encode.null

                                        Just connectionData ->
                                            Json.Encode.object
                                                [ ( "hostname", Json.Encode.string connectionData.hostname )
                                                , ( "port", Json.Encode.int connectionData.port_ )
                                                , ( "user", Json.Encode.string connectionData.user )
                                                , ( "password", Json.Encode.string connectionData.password )
                                                , ( "database", Json.Encode.string connectionData.database )
                                                ]
                                  )
                                , ( "certs"
                                  , case type_ of
                                        Basic ->
                                            Json.Encode.null

                                        Secure { certificatePath, keyPath } ->
                                            Json.Encode.object
                                                [ ( "certificatePath", Json.Encode.string certificatePath )
                                                , ( "keyPath", Json.Encode.string keyPath )
                                                ]
                                  )
                                ]
                    in
                    ( NotYetStarted
                    , runTask "SERVE" startupConfig
                        |> onError (\err -> runTask "PRINT" (Json.Encode.string ("Failed to start server with error: " ++ err)))
                        |> onSuccess (\_ -> runTask "PRINT" (Json.Encode.string ("Server running on port: " ++ String.fromInt finalPort)))
                        |> executeTasks
                    )
        , subscriptions = subscriptions
        , update = update handler
        }


decodeEnv : String -> Decoder a -> Decoder a
decodeEnv key valDecoder =
    Json.Decode.field key valDecoder


subscriptions : Server -> Sub Msg
subscriptions _ =
    Sub.batch
        [ requestPort IncomingRequest
        , runnerMsg RunnerMessage
        ]


executeTasks : Task String Value -> Cmd Msg
executeTasks =
    Task.attempt Continuation


update : (Context -> ReadyContext) -> Msg -> Server -> ( Server, Cmd Msg )
update handler msg model =
    case msg of
        IncomingRequest request ->
            case model of
                NotYetStarted ->
                    ( model, Cmd.none )

                Running ->
                    ( model
                    , { request = request.req
                      , server = Running
                      , requestId = request.id
                      }
                        |> Internal.Server.Context
                        |> handler
                        |> executeTasks
                    )

        RunnerMessage { message } ->
            case message of
                "SERVED" ->
                    ( Running, Cmd.none )

                "CLOSED" ->
                    ( NotYetStarted, Cmd.none )

                _ ->
                    Debug.todo ("Handle unknown runner message: " ++ message)

        Continuation result ->
            case result of
                Err err ->
                    -- This happens when the user doesn't handle `Server.onError`
                    -- respond (Response.error err) context
                    Debug.todo "handle the user not handling errors, probably need to pass context around"

                Ok body ->
                    ( model, Cmd.none )


getPath : Context -> Result String String
getPath (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString


matchPath : Context -> Result String (List String)
matchPath (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString
        |> Result.map (String.split "/" >> List.filter (not << String.isEmpty))


getMethod : Context -> Result String Method
getMethod (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "method" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString
        |> Result.andThen methodFromString


getBody : Context -> Result String String
getBody (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "elmBody" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString


methodFromString : String -> Result String Method
methodFromString method =
    case method of
        "GET" ->
            Ok Get

        "POST" ->
            Ok Post

        "PUT" ->
            Ok Put

        "DELETE" ->
            Ok Delete

        _ ->
            Err ("Unknown method: " ++ method)


type Method
    = Get
    | Post
    | Put
    | Delete


respond : InternalResponse -> Context -> Task String Value
respond (InternalResponse { status, body, contentType }) (Internal.Server.Context context) =
    [ ( "options"
      , Json.Encode.object
            [ ( "status"
              , status
                    |> Status.toCode
                    |> Json.Encode.int
              )
            , ( "body"
              , Json.Encode.string body
              )
            , ( "headers"
              , [ [ Json.Encode.string "Content-Type"
                  , contentType
                        |> ContentType.toString
                        |> Json.Encode.string
                  ]
                ]
                    |> List.map (Json.Encode.list identity)
                    |> Json.Encode.list identity
              )
            ]
      )
    , ( "id", Json.Encode.string context.requestId )
    ]
        |> Json.Encode.object
        |> runTask "RESPOND"


andThen : (Value -> ReadyContext) -> ReadyContext -> ReadyContext
andThen =
    Task.andThen


map : (Value -> Value) -> ReadyContext -> ReadyContext
map =
    Task.map


mapError : (String -> String) -> ReadyContext -> ReadyContext
mapError =
    Task.mapError


onError : (String -> ReadyContext) -> ReadyContext -> ReadyContext
onError =
    Task.onError


onSuccess : (Value -> ReadyContext) -> ReadyContext -> ReadyContext
onSuccess =
    Task.andThen


resultToContext : Result String Value -> ReadyContext
resultToContext result =
    case result of
        Ok val ->
            Task.succeed val

        Err err ->
            Task.fail err
