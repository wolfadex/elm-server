module Database.Postgres exposing (connect, query)

import Internal.Server exposing (Config(..), Context(..), Server(..), TaskResponse, runTask)
import Json.Encode
import Task exposing (Task)


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


query : String -> Task String TaskResponse
query =
    Json.Encode.string >> runTask "DATABASE_QUERY"
