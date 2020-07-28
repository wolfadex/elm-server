port module Server exposing
    ( Command
    , Config
    , Context
    , Flags
    , Program
    , baseConfig
    , envAtPath
    , getPath
    , matchPath
    , program
    , withPort
    )

import Internal.Database exposing (DatabaseConnection)
import Internal.Response
import Internal.Server exposing (Certs, CommandCmd, Config(..), Server(..), Type(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Platform
import Result.Extra


type alias Program =
    Platform.Program Flags Server Msg


type alias Flags =
    { environment : Value
    , arguments : Value
    }


type alias Command =
    Internal.Server.Command


type alias Context =
    Internal.Server.Context


type alias Config =
    Internal.Server.Config


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
    = Incoming CommandCmd


port command : CommandCmd -> Cmd msg


port respond : (CommandCmd -> msg) -> Sub msg


program : { init : Flags -> Config, handler : Context -> Context } -> Program
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
                    , command
                        { msg = "PRINT"
                        , args =
                            "Error: Invalid port: "
                                ++ String.fromInt finalPort
                                ++ ", must be between 1 and 65,535."
                                |> Json.Encode.string
                        }
                    )

                else
                    ( NotYetStarted
                      -- TODO: Send DB connection info here too
                    , [ { msg =
                            case type_ of
                                Basic ->
                                    "SERVE"

                                Secure certs ->
                                    "SERVE_SECURE"
                        , args =
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
                                ]
                        }
                      , { msg = "PRINT"
                        , args = Json.Encode.string ("Server starting on port: " ++ String.fromInt finalPort)
                        }
                      ]
                        |> List.map command
                        |> Cmd.batch
                    )
        , subscriptions = subscriptions
        , update = update handler
        }


decodeEnv : String -> Decoder a -> Decoder a
decodeEnv key valDecoder =
    Json.Decode.field key valDecoder


subscriptions : Server -> Sub Msg
subscriptions _ =
    respond Incoming


update : (Context -> Context) -> Msg -> Server -> ( Server, Cmd Msg )
update handler msg model =
    case msg of
        Incoming incoming ->
            case ( model, incoming.msg ) of
                ( NotYetStarted, "SERVED" ) ->
                    ( Internal.Server.initContinuations incoming.args
                    , command
                        { msg = "PRINT"
                        , args = Json.Encode.string "Server running..."
                        }
                    )

                ( Running server, "REQUEST" ) ->
                    let
                        (Internal.Server.Context response) =
                            { request = incoming.args
                            , server = Running server
                            , commands = []
                            , response = Internal.Response.default
                            }
                                |> Internal.Server.Context
                                |> handler
                    in
                    ( response.server
                    , response.commands
                        |> List.map command
                        |> Cmd.batch
                    )

                ( Running server, "CONTINUE" ) ->
                    case Json.Decode.decodeValue decodeContinue incoming.args of
                        Err err ->
                            ( Running server, Cmd.none )

                        Ok { id, result } ->
                            let
                                ( nextServer, maybeContinuation ) =
                                    Internal.Server.getContinuation id server
                            in
                            case maybeContinuation of
                                Nothing ->
                                    ( Running nextServer, Cmd.none )

                                Just continuation ->
                                    let
                                        (Internal.Server.Context response) =
                                            continuation result
                                    in
                                    ( response.server
                                    , response.commands
                                        |> List.map command
                                        |> Cmd.batch
                                    )

                _ ->
                    ( model
                    , command
                        { msg = "PRINT"
                        , args = Json.Encode.string "Handle unknown state"
                        }
                    )


decodeContinue : Decoder { id : Int, result : Result String Value }
decodeContinue =
    Json.Decode.map2 (\id result -> { id = id, result = result })
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "result" decodeContinueResult)


decodeContinueResult : Decoder (Result String Value)
decodeContinueResult =
    -- Json.Decode.field "ok" Json.Decode.bool
    --     |> Json.Decode.andThen
    --         (\ok ->
    --             Json.Decode.field "value" <|
    --                 if ok then
    --                     Json.Decode.map Ok Json.Decode.value
    --                 else
    --                     Json.Decode.map Err Json.Decode.string
    --         )
    Json.Decode.map Ok Json.Decode.value


getPath : Context -> Result String String
getPath (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString


matchPath : Context -> Result String (List String)
matchPath (Internal.Server.Context { request }) =
    Json.Decode.decodeValue (Json.Decode.field "url" Json.Decode.string) request
        |> Result.mapError Json.Decode.errorToString
        |> Result.map (String.split "/" >> List.filter (not << String.isEmpty))
