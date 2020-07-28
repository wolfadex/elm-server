
-- module Database exposing (Column(..), fromTable, query, select, withRestrictions)

-- import Json.Encode exposing (Value)
-- import Server.Internal exposing (Command, CommandCmd, Request(..), Server(..))


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
