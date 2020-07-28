module Database.Postgres exposing (connect, query)

import Internal.Server exposing (Config(..), Context(..), Continuation, Server(..))
import Json.Encode


connect :
    { hostname : String
    , port_ : Int
    , user : String
    , password : String
    , database : String
    }
    -> Config
    -> Config
connect { hostname, port_, user, password, database } (Config config) =
    Config
        { config
            | databaseConnection =
                Just
                    { hostname = hostname
                    , port_ = port_
                    , user = user
                    , password = password
                    , database = database
                    }
        }


query : { text : String, args : List String } -> (Context -> Continuation) -> Context -> Context
query { text, args } continuation (Context context) =
    case context.server of
        NotYetStarted ->
            Context context

        Running server ->
            let
                ( nextServer, continuationKey ) =
                    Internal.Server.insertContinuation (continuation (Context context)) server
            in
            Context
                { context
                    | server = Running nextServer
                    , commands =
                        { msg = "DATABASE_QUERY"
                        , args =
                            Json.Encode.object
                                [ ( "actual", server.actual )
                                , ( "query"
                                  , Json.Encode.object
                                        [ ( "text", Json.Encode.string text )
                                        , ( "args", Json.Encode.list Json.Encode.string args )
                                        ]
                                  )
                                , ( "continuationKey", Json.Encode.int continuationKey )
                                ]
                        }
                            :: context.commands
                }



-- let
--     ( nextServer, continuationKey ) =
--         Server.Internal.insertContinuation continuation server
-- in
-- ( nextServer
-- , { msg = "DATABASE"
--   , args =
--         Json.Encode.object
--             [ ( "query", encodeQuery qry )
--             , ( "continuationKey", Json.Encode.int continuationKey )
--             ]
--   }
-- )
