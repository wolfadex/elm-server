module Internal.Database exposing (DatabaseConnection)


type alias DatabaseConnection =
    { hostname : String
    , port_ : Int
    , user : String
    , password : String
    , database : String
    }
