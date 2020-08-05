module Database.Postgres exposing
    ( ColumnType(..)
    , Query
    , WhereCondition(..)
    , allowNull
    , connect
    , createColumn
    , createEnum
    , deleteQuery
    , disallowNull
    , doesCheck
    , doesntCheck
    , exclusionComparisonDisabled
    , exclusionComparisonEnabled
    , insertQuery
    , isForeignKey
    , isNotForeignKey
    , isNotPrimaryKey
    , isNotUnique
    , isPrimaryKey
    , isUnique
    , query
    , selectQuery
    , wrapString
    )

import Internal.Server exposing (Config(..), runTask)
import Json.Encode exposing (Value)
import Task exposing (Task)


type alias TableConfig =
    { name : String
    , columns : List Column
    , createIfExists : Bool
    }


type alias ColumnConfig =
    { name : String
    , type_ : ColumnType
    , constraints : Constraints
    }


type Column
    = Column ColumnConfig


createColumn : { name : String, type_ : ColumnType } -> Column
createColumn { name, type_ } =
    Column { name = name, type_ = type_, constraints = defaultConstraints }


disallowNull : Column -> Column
disallowNull (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | allowNull = False } }


allowNull : Column -> Column
allowNull (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | allowNull = True } }


isNotUnique : Column -> Column
isNotUnique (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isUnique = False } }


isUnique : Column -> Column
isUnique (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isUnique = True } }


isNotPrimaryKey : Column -> Column
isNotPrimaryKey (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isPrimaryKey = False } }


isPrimaryKey : Column -> Column
isPrimaryKey (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isPrimaryKey = True } }


isNotForeignKey : Column -> Column
isNotForeignKey (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isForeignKey = False } }


isForeignKey : Column -> Column
isForeignKey (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | isForeignKey = True } }


doesntCheck : Column -> Column
doesntCheck (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | doesCheck = False } }


doesCheck : Column -> Column
doesCheck (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | doesCheck = True } }


exclusionComparisonDisabled : Column -> Column
exclusionComparisonDisabled (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | exclusionComparison = False } }


exclusionComparisonEnabled : Column -> Column
exclusionComparisonEnabled (Column column) =
    let
        constraints =
            column.constraints
    in
    Column { column | constraints = { constraints | exclusionComparison = True } }


type alias Constraints =
    { allowNull : Bool
    , isUnique : Bool
    , isPrimaryKey : Bool
    , isForeignKey : Bool
    , doesCheck : Bool
    , exclusionComparison : Bool
    }


defaultConstraints : Constraints
defaultConstraints =
    { allowNull = False
    , isUnique = False
    , isPrimaryKey = False
    , isForeignKey = False
    , doesCheck = False
    , exclusionComparison = False
    }



{- TODO: Add missing types
   Geometry
   Network Address
   Bit String
   Text Search
   UUID
   XML
   JSON
   Array
   Composite
   Range
   Object Identifier
   Pseudo
-}


type ColumnType
    = CTSmallInt
    | CTInteger
    | CTBigInt
    | CTDecimal
    | CTNumeric
    | CTReal
    | CTDoublePrecision
    | CTSmallSerial
    | CTSerial
    | CTBigSerial
    | CTMoney
    | CTCharVarying Int
    | CTCharFixed Int
    | CTText
    | CTByteA
    | CTTimestamp
    | CTTimestampTZ
    | CTDate
    | CTTime
    | CTTimeTZ
    | CTInterval
    | CTBool
    | CTEnum EnumInternal


type alias EnumInternal =
    { name : String
    , variants : List String
    }


type Enum
    = Enum EnumInternal


createEnum : { name : String, variants : List String } -> Enum
createEnum { name, variants } =
    Enum { name = name, variants = variants }


sqlCreateTable : TableConfig -> String
sqlCreateTable { name, columns } =
    "CREATE TABLE "
        ++ name
        ++ "(\n  "
        ++ (columns
                |> List.map columnCreateFormat
                |> String.join ",\n  "
           )
        ++ "\n);"


columnCreateFormat : Column -> String
columnCreateFormat (Column { name, type_, constraints }) =
    name
        ++ " "
        ++ columnTypeToSQLName type_
        ++ " "
        ++ (if constraints.isPrimaryKey then
                "PRIMARY KEY "

            else
                ""
           )


columnTypeToSQLName : ColumnType -> String
columnTypeToSQLName type_ =
    case type_ of
        CTSmallInt ->
            "SMALLINT"

        CTInteger ->
            "INT"

        CTBigInt ->
            "BIGINT"

        CTDecimal ->
            "DECIMAL"

        CTNumeric ->
            "???"

        CTReal ->
            "REAL"

        CTDoublePrecision ->
            "???"

        CTSmallSerial ->
            "???"

        CTSerial ->
            "???"

        CTBigSerial ->
            "???"

        CTMoney ->
            "???"

        CTCharVarying limit ->
            "VARCHAR(" ++ String.fromInt limit ++ ")"

        CTCharFixed limit ->
            "CHAR(" ++ String.fromInt limit ++ ")"

        CTText ->
            "TEXT"

        CTByteA ->
            "???"

        CTTimestamp ->
            "???"

        CTTimestampTZ ->
            "???"

        CTDate ->
            "???"

        CTTime ->
            "???"

        CTTimeTZ ->
            "???"

        CTInterval ->
            "???"

        CTBool ->
            "BOOL"

        CTEnum options ->
            "???"


columnTypeToElmType : ColumnType -> String
columnTypeToElmType type_ =
    case type_ of
        CTSmallInt ->
            "__"

        CTInteger ->
            "Int"

        CTBigInt ->
            "__"

        CTDecimal ->
            "__"

        CTNumeric ->
            "__"

        CTReal ->
            "__"

        CTDoublePrecision ->
            "__"

        CTSmallSerial ->
            "__"

        CTSerial ->
            "__"

        CTBigSerial ->
            "__"

        CTMoney ->
            "__"

        CTCharVarying limit ->
            "__"

        CTCharFixed limit ->
            "__"

        CTText ->
            "String"

        CTByteA ->
            "__"

        CTTimestamp ->
            "__"

        CTTimestampTZ ->
            "__"

        CTDate ->
            "__"

        CTTime ->
            "__"

        CTTimeTZ ->
            "__"

        CTInterval ->
            "__"

        CTBool ->
            "Bool"

        CTEnum options ->
            "__"


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


type Query
    = Query String


query : Query -> Task String Value
query (Query qry) =
    qry
        |> Debug.log "query"
        |> Json.Encode.string
        |> runTask "DATABASE_QUERY"


wrapString : String -> String
wrapString str =
    "'" ++ str ++ "'"
