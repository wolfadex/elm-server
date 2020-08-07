module Database.Postgres exposing
    ( WhereCondition(..)
    , connect
    , deleteQuery
    , insertQuery
    , selectQuery
    , wrapString
    )

import Internal.Server exposing (Config(..), Query(..))


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


insertQuery : { tableName : String, columnValues : List String } -> Query
insertQuery { tableName, columnValues } =
    "INSERT INTO " ++ tableName ++ " VALUES(DEFAULT, " ++ String.join ", " columnValues ++ ");" |> Query


selectQuery : { tableName : String, where_ : WhereCondition } -> Query
selectQuery { tableName, where_ } =
    "SELECT * FROM " ++ tableName ++ addWhereClause where_ ++ ";" |> Query


deleteQuery : { tableName : String, where_ : WhereCondition } -> Query
deleteQuery { tableName, where_ } =
    "DELETE FROM " ++ tableName ++ addWhereClause where_ ++ ";" |> Query


addWhereClause : WhereCondition -> String
addWhereClause condition =
    let
        result =
            addWhereClauseHelper condition
    in
    if String.isEmpty result then
        result

    else
        " WHERE " ++ result


addWhereClauseHelper : WhereCondition -> String
addWhereClauseHelper condition =
    case condition of
        NoCondition ->
            ""

        And a b ->
            addWhereClause a ++ " AND " ++ addWhereClause b

        Or a b ->
            addWhereClause a ++ " OR " ++ addWhereClause b

        Equal name val ->
            name ++ " = " ++ val

        GreaterThan name val ->
            name ++ " > " ++ val

        LessThan name val ->
            name ++ " < " ++ val

        GreaterThanOrEqual name val ->
            name ++ " >= " ++ val

        LessThanOrEqual name val ->
            name ++ " <= " ++ val

        NotEqual name val ->
            name ++ " != " ++ val

        InList name items ->
            name ++ " IN (" ++ String.join "," items ++ ")"

        InQuery name (Query qry) ->
            name ++ " IN (" ++ String.dropRight 1 qry ++ ")"

        Like name pattern ->
            name ++ " LIKE " ++ pattern

        IsNull name ->
            name ++ " = NULL"

        NotCondition cond ->
            "NOT " ++ addWhereClauseHelper cond


type WhereCondition
    = NoCondition
    | Equal String String
    | GreaterThan String String
    | LessThan String String
    | GreaterThanOrEqual String String
    | LessThanOrEqual String String
    | NotEqual String String
    | And WhereCondition WhereCondition
    | Or WhereCondition WhereCondition
    | InList String (List String)
    | InQuery String Query
    | Like String String
    | IsNull String
    | NotCondition WhereCondition


wrapString : String -> String
wrapString str =
    "'" ++ str ++ "'"
