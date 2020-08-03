module MyDb exposing (main)

import Database.Postgres as Postgres exposing (ColumnType(..))


main : Postgres.Database
main =
    Postgres.databaseSetup
        { sourceDirectory = "examples/temp"
        , enums = []
        , tables =
            [ { name = "persons"
              , columns =
                    [ Postgres.createColumn
                        { name = "name"
                        , type_ = CTText
                        }
                    , Postgres.createColumn
                        { name = "age"
                        , type_ = CTInteger
                        }
                    , { name = "email"
                      , type_ = CTText
                      }
                        |> Postgres.createColumn
                        |> Postgres.isUnique
                    ]
              }
                |> Postgres.createTable
                |> Postgres.createTableIfDoesntExist
            ]
        }
