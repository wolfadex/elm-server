module MyDb exposing (database)

import Database.Sqlite exposing (DefaultType(..), Path(..))
import Dict


database : Database.Sqlite.Database
database =
    { path = InMemory
    , tables =
        Dict.fromList
            [ ( "Users", users )
            ]
    }


users : Database.Sqlite.Table
users =
    { primaryKey = [ "email" ]
    , columns =
        Dict.fromList
            [ ( "name"
              , { type_ = Text (Just "")
                , isUnique = False
                }
              )
            , ( "age"
              , { type_ = Integer (Just 0)
                , isUnique = False
                }
              )
            , ( "email"
              , { type_ = Text Nothing
                , isUnique = True
                }
              )
            ]
    }
