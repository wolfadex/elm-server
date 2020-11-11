port module Server exposing
    ( Config
    , Flags
    , Method(..)
    , Path
    , Program
    , Request
    , Response
    , andThen
    , baseConfig
    , decodeBody
    , envAtPath
    , getBody
    , getMethod
    , getPath
    , getQueryParams
    , makeSecure
    , map
    , mapError
    , methodToString
    , onError
    , onSuccess
    , program
    , query
    , respond
    , resultToResponse
    , withPort
    )

import ContentType
import Error exposing (Error(..))
import Html.Attributes exposing (value)
import Internal.Response exposing (InternalResponse(..))
import Internal.Server exposing (Certs, Config(..), Query, Type(..), runTask)
import Json.Decode exposing (Decoder)
import Json.Decode.Extra
import Json.Encode exposing (Value)
import Platform
import Response
import Result.Extra
import Status
import Task exposing (Task, onError)


type alias Program =
    Platform.Program Flags () Msg


type alias Flags =
    { environment : Value
    , arguments : Value
    }


type Request
    = Request InternalRequest


type alias InternalRequest =
    { body : Value
    , path : Path
    , method : Method
    , queryParams : List QueryParam
    , actualRequest : Value
    }


type alias QueryParam =
    ( String, Maybe String )


getBody : Request -> Value
getBody (Request { body }) =
    body


decodeBody : Decoder a -> Request -> Result Json.Decode.Error a
decodeBody decoder (Request { body }) =
    Json.Decode.decodeValue (Json.Decode.Extra.doubleEncoded decoder) body


getPath : Request -> Path
getPath (Request { path }) =
    path


getMethod : Request -> Method
getMethod (Request { method }) =
    method


getQueryParams : Request -> List QueryParam
getQueryParams (Request { queryParams }) =
    queryParams


type alias IncomingRequest =
    Value


type alias Response =
    Task Error Value


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


envAtPath : Path -> Config -> Config
envAtPath envPath (Config config) =
    Config { config | envPath = envPath }


type Msg
    = IncomingRequest Value
    | Continuation (Result Error Value)


port requestPort : (Value -> msg) -> Sub msg


program : { init : Flags -> Config, handler : Request -> Response } -> Program
program { init, handler } =
    Platform.worker
        { init =
            \flags ->
                let
                    (Config { port_, type_, databaseConnection }) =
                        init flags

                    initialTasks =
                        if port_ < 1 || port_ > 65535 then
                            "Error: Invalid port: "
                                ++ String.fromInt port_
                                ++ ", must be between 1 and 65,535."
                                |> Json.Encode.string
                                |> runTask "PRINT"

                        else
                            let
                                startupConfig =
                                    Json.Encode.object
                                        [ ( "port", Json.Encode.int port_ )
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
                            runTask "SERVE" startupConfig
                in
                ( (), executeTasks initialTasks )
        , subscriptions = subscriptions
        , update = update handler
        }


subscriptions : () -> Sub Msg
subscriptions () =
    requestPort IncomingRequest


executeTasks : Task Error Value -> Cmd Msg
executeTasks =
    Task.attempt Continuation


update : (Request -> Response) -> Msg -> () -> ( (), Cmd Msg )
update handler msg () =
    ( ()
    , case msg of
        IncomingRequest request ->
            request
                |> parseRequest
                |> Result.mapError
                    (Error.toString
                        >> Response.error
                        >> respond
                            (Request
                                { body = Json.Encode.null
                                , path = []
                                , method = Get
                                , queryParams = []
                                , actualRequest = request
                                }
                            )
                    )
                |> Result.map handler
                |> Result.Extra.merge
                |> executeTasks

        Continuation result ->
            case result of
                Err err ->
                    -- This happens when the user doesn't handle `Server.onError`
                    -- respond (Response.error err) context
                    err
                        |> Error.toString
                        |> Json.Encode.string
                        |> runTask "PRINT"
                        |> executeTasks

                Ok _ ->
                    -- Should something happen here?
                    Cmd.none
    )


parseRequest : IncomingRequest -> Result Error Request
parseRequest request =
    parsePath request
        |> Result.andThen
            (\( path, queryParams ) ->
                parseMethod request
                    |> Result.andThen
                        (\method ->
                            parseBody request
                                |> Result.map
                                    (\body ->
                                        Request
                                            { body = body
                                            , path = path
                                            , method = method
                                            , queryParams = queryParams
                                            , actualRequest = request
                                            }
                                    )
                        )
            )


parsePath : IncomingRequest -> Result Error ( Path, List QueryParam )
parsePath request =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.mapError TypeError
        |> Result.andThen
            (\pathStr ->
                case String.split "?" pathStr of
                    [ pathOnly ] ->
                        Ok
                            ( buildPath pathOnly
                            , []
                            )

                    [ path, paramsStr ] ->
                        Ok
                            ( buildPath path
                            , paramsStr
                                |> String.split "&"
                                |> List.map buildQueryParam
                            )

                    _ ->
                        Err (RuntimeError "Malformed request url")
            )


buildPath : String -> Path
buildPath =
    String.split "/" >> List.filter (not << String.isEmpty)


buildQueryParam : String -> QueryParam
buildQueryParam str =
    case String.split "=" str of
        [ key, value ] ->
            ( key, Just value )

        [ key ] ->
            ( key, Nothing )

        _ ->
            ( str, Nothing )


parseMethod : IncomingRequest -> Result Error Method
parseMethod request =
    Json.Decode.decodeValue (Json.Decode.field "method" Json.Decode.string) request
        |> Result.mapError TypeError
        |> Result.map methodFromString


parseBody : IncomingRequest -> Result Error Value
parseBody request =
    Json.Decode.decodeValue (Json.Decode.field "elmBody" Json.Decode.value) request
        |> Result.mapError TypeError


methodFromString : String -> Method
methodFromString method =
    case method of
        "GET" ->
            Get

        "POST" ->
            Post

        "PUT" ->
            Put

        "DELETE" ->
            Delete

        "OPTION" ->
            Option

        "HEAD" ->
            Head

        "CONNECT" ->
            Connect

        "OPTIONS" ->
            Options

        "TRACE" ->
            Trace

        "PATCH" ->
            Patch

        _ ->
            Unofficial method


type Method
    = Get
    | Post
    | Put
    | Delete
    | Option
    | Head
    | Connect
    | Options
    | Trace
    | Patch
    | Unofficial String


methodToString : Method -> String
methodToString method =
    case method of
        Get ->
            "Get"

        Post ->
            "Post"

        Put ->
            "Put"

        Delete ->
            "Delete"

        Option ->
            "Option"

        Head ->
            "Head"

        Connect ->
            "Connect"

        Options ->
            "Options"

        Trace ->
            "Trace"

        Patch ->
            "Patch"

        Unofficial m ->
            m


respond : Request -> InternalResponse -> Response
respond (Request request) (InternalResponse { status, body, contentType }) =
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
    , ( "request", request.actualRequest )
    ]
        |> Json.Encode.object
        |> runTask "RESPOND"


andThen : (Value -> Response) -> Response -> Response
andThen =
    Task.andThen


map : (Value -> Value) -> Response -> Response
map =
    Task.map


mapError : (Error -> Error) -> Response -> Response
mapError =
    Task.mapError


onError : (Error -> Response) -> Response -> Response
onError =
    Task.onError


onSuccess : (Value -> Response) -> Response -> Response
onSuccess =
    Task.andThen


resultToResponse : Result String Value -> Response
resultToResponse result =
    case result of
        Ok val ->
            Task.succeed val

        Err err ->
            Task.fail (RuntimeError err)


query : Query -> Task Error Value
query =
    Internal.Server.query
