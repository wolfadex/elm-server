module IO.Http exposing (..)


import Dict
import Error exposing (Error(..))
import Internal.IO exposing (IO)
import Json.Decode
import Json.Encode exposing (Value)
import Process
import Set
import Task exposing (Task)


type Listener = Listener Value


listen : Int -> IO Listener
listen port_ =
    Internal.IO.evalAsync "listen" 
        (Json.Encode.object [ ( "port", Json.Encode.int port_ ) ])
        (Json.Decode.map Listener Json.Decode.value)


type Connection = Connection Value


acceptConnection : Listener -> (Connection -> IO ()) -> IO Process.Id
acceptConnection (Listener listener) connectionHandler =
    Process.spawn
        (getNextConnection listener connectionHandler)
        |> savePid "connection__???"


getNextConnection : Value -> (Connection -> IO ()) -> IO Process.Id
getNextConnection listener connectionHandler =
    Internal.IO.evalAsync "acceptConnection" 
        listener
        (Json.Decode.map Connection Json.Decode.value)
        |> Internal.IO.andThen connectionHandler
        |> Internal.IO.andThen (\_ -> Process.spawn (getNextConnection listener connectionHandler) |> savePid "connection__???")


savePid : String -> Task Error Process.Id -> IO Process.Id
savePid key =
    Task.map
        (\pid ->
            ( ( Dict.singleton key pid
                , Set.empty
                )
            , pid
            )
        )


type Request = Request Value


serve : Connection -> (Request -> IO ()) -> IO ()
serve (Connection connection) requestHandler =
    Process.spawn
        (getNextRequest connection requestHandler)
        |> Task.map (\_ -> ( Internal.IO.noProcesses, () ))


getNextRequest : Value -> (Request -> IO ()) -> IO ()
getNextRequest connection requestHandler =
    Internal.IO.evalAsync "serveHttp"
        connection
        (Json.Decode.map Request Json.Decode.value)
        |> Internal.IO.andThen requestHandler
        |> Internal.IO.andThen (\_ -> Process.spawn (getNextRequest connection requestHandler) |> Task.map (\_ -> ( Internal.IO.noProcesses, () )))


getUrl : Request -> Result Error String
getUrl (Request request) =
    Internal.IO.evalSync "withRequest"
        [ request, Json.Encode.string "getUrl" ]
        Json.Decode.string


respondWith : String -> Request -> IO ()
respondWith body (Request request) =
    Internal.IO.evalAsync "withRequest"
        (Json.Encode.object
            [ ( "request", request )
            , ( "action", Json.Encode.string "respond" )
            , ( "body", Json.Encode.string body )
            ]
        )
        (Json.Decode.succeed ())



-- parseMethod : IncomingRequest -> Result Error Method
-- parseMethod request =
--     Json.Decode.decodeValue (Json.Decode.field "method" Json.Decode.string) request
--         |> Result.mapError TypeError
--         |> Result.map methodFromString


-- parseBody : IncomingRequest -> Result Error Value
-- parseBody request =
--     Json.Decode.decodeValue (Json.Decode.field "elmBody" Json.Decode.value) request
--         |> Result.mapError TypeError


-- methodFromString : String -> Method
-- methodFromString method =
--     case method of
--         "GET" ->
--             Get

--         "POST" ->
--             Post

--         "PUT" ->
--             Put

--         "DELETE" ->
--             Delete

--         "OPTION" ->
--             Option

--         "HEAD" ->
--             Head

--         "CONNECT" ->
--             Connect

--         "OPTIONS" ->
--             Options

--         "TRACE" ->
--             Trace

--         "PATCH" ->
--             Patch

--         _ ->
--             Unofficial method


-- type Method
--     = Get
--     | Post
--     | Put
--     | Delete
--     | Option
--     | Head
--     | Connect
--     | Options
--     | Trace
--     | Patch
--     | Unofficial String