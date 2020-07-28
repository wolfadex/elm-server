module Internal.Server exposing
    ( Certs
    , Command
    , CommandCmd
    , Config(..)
    , ConfigData
    , Context(..)
    , Continuation
    , Request
    , RunningServer
    , Server(..)
    , Type(..)
    , getContinuation
    , initContinuations
    , insertContinuation
    )

import Dict exposing (Dict)
import Internal.Database exposing (DatabaseConnection)
import Internal.Response exposing (Response(..))
import Json.Encode exposing (Value)
import Status exposing (Status(..))


type alias Command =
    ( Server, CommandCmd )


type alias CommandCmd =
    { msg : String
    , args : Value
    }


type alias Request =
    Value


type Context
    = Context ContextData


type alias ContextData =
    { request : Request
    , server : Server
    , commands : List CommandCmd
    , response : Response
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



-- { msg = "RESPOND"
-- , args =
--     Json.Encode.object
--         [ ( "options"
--             , Json.Encode.object
--                 [ ( "status", Json.Encode.int 404 )
--                 , ( "body", Json.Encode.string "Not Found" )
--                 ]
--             )
--         , ( "req", context.request )
--         ]
-- }


type Server
    = NotYetStarted
    | Running RunningServer


type alias RunningServer =
    { actual : Value
    , nextContinuation : Int
    , continuations : Dict Int Continuation
    }


type alias Continuation =
    Result String Value -> Context


{-| The `actual` value is whatever is passed back from Deno
-}
initContinuations : Value -> Server
initContinuations actual =
    Running { actual = actual, nextContinuation = 0, continuations = Dict.empty }


insertContinuation : Continuation -> RunningServer -> ( RunningServer, Int )
insertContinuation continuation server =
    ( { server
        | nextContinuation = server.nextContinuation + 1
        , continuations = Dict.insert server.nextContinuation continuation server.continuations
      }
    , server.nextContinuation
    )


getContinuation : Int -> RunningServer -> ( RunningServer, Maybe Continuation )
getContinuation id server =
    ( { server | continuations = Dict.remove id server.continuations }
    , Dict.get id server.continuations
    )
