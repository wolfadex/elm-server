module HelloWorld exposing (main)

import Database.Postgres as Database
import Html.String as Html
import Html.String.Attributes as Attr
import Json.Encode
import Logger as Log
import Response
import Server exposing (Config, Context, Flags)
import Status exposing (Status(..))


main : Server.Program
main =
    Server.program
        { init = init
        , handler = handler
        }


init : Flags -> Config
init _ =
    Server.baseConfig
        |> Server.envAtPath [ "examples" ]
        |> Database.connect
            { hostname = "localhost"
            , port_ = 5432
            , database = "postgres"
            , user = "postgres"
            , password = "postgres"
            }


handler : Context -> Context
handler context =
    case Server.matchPath context of
        Result.Ok [] ->
            context
                |> Response.setBody indexPage
                |> Response.send
                |> Log.toConsole "index page requested"

        Result.Ok [ "hello", name ] ->
            context
                |> Response.setBody ("Hello, " ++ name ++ "!")
                |> Response.send

        Result.Ok [ "person", name, ageStr ] ->
            case String.toInt ageStr of
                Nothing ->
                    context
                        |> Response.setStatus NotAcceptable
                        |> Response.setBody "Age should be an Int"
                        |> Response.send

                Just age ->
                    context
                        |> Database.query
                            { text = "INSERT INTO persons VALUES(DEFAULT, '" ++ name ++ "', " ++ ageStr ++ ");"
                            , args = []
                            }
                            (\continueContext result ->
                                case result of
                                    Result.Ok person ->
                                        continueContext
                                            |> Response.setStatus Status.Ok
                                            |> Response.setBody
                                                ([ ( "name", Json.Encode.string name )
                                                 , ( "age", Json.Encode.int age )
                                                 ]
                                                    |> Json.Encode.object
                                                    |> Json.Encode.encode 0
                                                )
                                            |> Response.send

                                    Err err ->
                                        continueContext
                                            |> Response.setStatus InternalServerError
                                            |> Response.setBody ("Couldn't create person: " ++ err)
                                            |> Response.send
                            )

        Result.Ok _ ->
            context
                |> Response.notFound
                |> Response.send

        Err err ->
            context
                |> Response.error err
                |> Response.send


indexPage : String
indexPage =
    Html.div
        []
        [ Html.h1 [] [ Html.text "Howdy, Partner" ]
        , Html.nav
            []
            [ Html.a
                [ Attr.href "" ]
                [ Html.text "Home" ]
            , Html.a
                [ Attr.href "hello/carl" ]
                [ Html.text "Say Hello" ]
            ]
        ]
        |> Html.toString 2
        |> (++) "<!DOCTYPE html><html><head><title>Fun With Elm</title></head><body>"
        |> (\html ->
                html
                    ++ "</body></html>"
           )



-- import Database.Sqlite exposing (Column(..))
-- Ok [ "person" ] ->
--     case Server.method context of
--         Get ->
--             Database.Sqlite.select AllColumns
--                 |> Database.Sqlite.fromTable "People"
--                 |> Database.Sqlite.query
--                 |> Server.andThen
--                     (\result ->
--                         case result of
--                             Ok people ->
--                                 Response.Json.ok context people
--                             Err err ->
--                                 Response.error context err
--                     )
--     [ ( "name", Json.Encode.string "Carl" )
--     , ( "age", Json.Encode.int 25 )
--     ]
-- |> Response.Json.ok context
-- Post ->
--     [ ( "name", Json.Encode.string "Carl" )
--     , ( "age", Json.Encode.int 43 )
--     ]
--         |> Json.Encode.object
--         |> Database.create
--         |> Server.andThen
--             (\result ->
--                 case result of
--                     Ok _ ->
--                         Response.Text.ok context "Carl created"
--                     Err err ->
--                         Response.error context err
--             )
-- _ ->
--     Response.methodNotAllowed context
