module Database.Sqlite exposing (Database, DefaultType(..), Path(..), Table)

import Dict exposing (Dict)
import Html.Attributes exposing (name)
import Json.Encode exposing (Value)
import String.Extra


type Path
    = InMemory
    | Exact String


type alias Database =
    { tables : Dict Name Table
    , path : Path
    }


type alias Name =
    String


type alias Table =
    { columns : Dict Name Column
    , primaryKey : List Name
    }


type alias Column =
    { type_ : DefaultType
    , isUnique : Bool
    }


type DefaultType
    = Integer (Maybe Int)
    | Text (Maybe String)
    | Real (Maybe Float)
    | Blob (Maybe String)


query : String -> List Value -> Value
query qry values =
    Json.Encode.object
        [ ( "query", Json.Encode.string qry )
        , ( "values", Json.Encode.list identity values )
        ]


type alias File =
    String


type Error
    = MissingPath
    | NoTables


generateSqlite : Database -> Result Error (Dict String File)
generateSqlite database =
    -- validatePath database.path
    --     |> Result.map (\() -> generateTables database.tables)
    Err MissingPath


validatePath : Path -> Result Error ()
validatePath path =
    case path of
        Exact "" ->
            Err MissingPath

        _ ->
            Ok ()



-- generateTables : Dict Name Table -> Result Error (Dict String File)
-- generateTables tables =
--     if Dict.isEmpty tables then
--         Err NoTables
--     else
--         tables
--             |> Dict.toList
--             |> List.map generateTable
--             |> Dict.fromList


generateTable : ( Name, Table ) -> Result Error ( String, File )
generateTable ( name, table ) =
    "module Database.Table."
        ++ String.Extra.toTitleCase name
        ++ """ exposing (select, Column)

import Database.Sqlite exposing (Query)

type Column
    = """
        ++ (table.columns
                |> Dict.keys
                |> List.map String.Extra.toTitleCase
                |> String.join " | "
           )
        ++ """


columnToString : Column -> String
columnToString column =
    case column of
        """
        ++ (table.columns
                |> Dict.keys
                |> List.map (\col -> String.Extra.toTitleCase col ++ " -> " ++ col)
                |> String.join "\n        "
           )
        ++ """


type ColumnSelection
    = All
    | Distinct (List Column)

select : ColumnSelection -> Query
select columns =
    "SELECT "
        ++ (case columns of
                All -> "*"
                Distinct cols ->
                    cols
                        |> List.map columnToString
                        |> String.join ", "
                        |> (\\c -> "(" ++ c ++ ")")
            )
        ++ " FROM """
        ++ name
        ++ """
"""
        |> Tuple.pair ("Database/Table/" ++ String.Extra.toTitleCase name ++ ".elm")
        |> Ok



-- module Database.Sqlite exposing (Column(..), create, fromTable, query, select, withRestrictions)
-- import Json.Encode exposing (Value)
-- import Server.Internal exposing (Command, CommandCmd, Request(..), Server(..))
-- create : { name : String, columns : List ColumnDefinition } -> CommandCmd
-- create { name, columns } =
--     { msg = "DATABASE_CREATE"
--     , args =
--         Json.Encode.string <|
--             "CREAT TABLE "
--                 ++ name
--                 ++ " ("
--                 ++ (List.map createColumn columns |> String.join ", ")
--                 ++ ");"
--     }
-- createColumn : ColumnDefinition -> String
-- createColumn { name, type_, constraints } =
--     name ++ " " ++ typeToString type_ ++ constraintsToString constraints
-- type alias ColumnDefinition =
--     { name : String
--     , type_ : ColumnType
--     , constraints : List Constraint
--     }
-- type ColumnType
--     = Text
--     | Integer
-- typeToString : ColumnType -> String
-- typeToString colType =
--     case colType of
--         Text ->
--             "TEXT"
--         Integer ->
--             "INTEGER"
-- type Constraint
--     = PrimaryKey
--     | NotNull
--     | Unique
--     | ForeignKey
--     | Check
--     | None
-- constraintsToString : List Constraint -> String
-- constraintsToString constraints =
--     if List.member None constraints then
--         ""
--     else
--         List.map constraintToString constraints
--             |> String.join " "
--             |> (++) " "
-- constraintToString : Constraint -> String
-- constraintToString constraint =
--     case constraint of
--         PrimaryKey ->
--             "PRIMARY KEY"
--         NotNull ->
--             "NOT NULL"
--         Unique ->
--             "UNIQUE"
--         ForeignKey ->
--             "FOREIGN KEY"
--         Check ->
--             "CHECK"
--         None ->
--             ""
-- query : (Result String Value -> Command) -> Query -> Server -> ( Server, CommandCmd )
-- query continuation qry server =
--     let
--         ( nextServer, continuationKey ) =
--             Server.Internal.insertContinuation continuation server
--     in
--     ( nextServer
--     , { msg = "DATABASE"
--       , args =
--             Json.Encode.object
--                 [ ( "query", encodeQuery qry )
--                 , ( "continuationKey", Json.Encode.int continuationKey )
--                 ]
--       }
--     )
-- encodeQuery : Query -> Value
-- encodeQuery (Query qry) =
--     Json.Encode.string qry
-- select : Column -> Query
-- select column =
--     let
--         colName =
--             case column of
--                 AllColumns ->
--                     "*"
--                 Column name ->
--                     name
--     in
--     Query ("SELECT " ++ colName)
-- fromTable : String -> Query -> Query
-- fromTable name (Query qry) =
--     Query (qry ++ " FROM " ++ name)
-- withRestrictions : List Restriction -> Query -> Query
-- withRestrictions restrictions (Query qry) =
--     restrictions
--         |> List.map identity
--         |> String.join " "
--         |> (++) qry
--         |> Query
-- type alias Restriction =
--     String
-- type Query
--     = Query String
-- type Column
--     = AllColumns
--     | Column String
-- type alias Table =
--     String
