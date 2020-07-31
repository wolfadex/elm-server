module HelloWorld exposing (main)

import Database.Postgres as Database
import Html.String as Html
import Html.String.Attributes as Attr
import Json.Encode
import Logger as Log
import Response
import Server exposing (Config, Context, Flags, ReadyContext)
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
        |> Database.connect
            { hostname = "localhost"
            , port_ = 5432
            , database = "postgres"
            , user = "postgres"
            , password = "postgres"
            }


handler : Context -> ReadyContext
handler context =
    case Server.matchPath context of
        Result.Ok [] ->
            context
                |> Server.respond (Response.default |> Response.setBody indexPage)
                |> Server.andThen (\_ -> Log.toConsole "index page requested")

        Result.Ok [ "hello", name ] ->
            Log.toConsole ("Saying hello to " ++ name)
                |> Server.andThen
                    (\_ ->
                        let
                            body =
                                "Hello, " ++ name ++ "!"

                            response =
                                Response.setBody body Response.default
                        in
                        Server.respond response context
                    )

        Result.Ok [ "persons" ] ->
            Database.query "SELECT * FROM persons;"
                |> Server.onError (\err -> Server.respond (Response.error err) context)
                |> Server.onSuccess (\{ body } -> Server.respond (Response.json body) context)

        -- Result.Ok [ "persons", name, ageStr ] ->
        --     case String.toInt ageStr of
        --         Nothing ->
        --             context
        --                 |> Server.respond
        --                     { status = NotAcceptable
        --                     , body = "Age should be an Int"
        --                     }
        --         Just age ->
        --             context
        --                 |> Database.query
        --                     { text = "INSERT INTO persons VALUES(DEFAULT, '" ++ name ++ "', " ++ ageStr ++ ");"
        --                     , args = []
        --                     }
        --                     (\continueContext result ->
        --                         case result of
        --                             Result.Ok person ->
        --                                 continueContext
        --                                     |> Server.respond
        --                                         { status = Status.Ok
        --                                         , body =
        --                                             [ ( "name", Json.Encode.string name )
        --                                             , ( "age", Json.Encode.int age )
        --                                             ]
        --                                                 |> Json.Encode.object
        --                                                 |> Json.Encode.encode 0
        --                                         }
        --                             Err err ->
        --                                 continueContext
        --                                     |> Response.error ("Couldn't create person: " ++ err)
        --                     )
        Result.Ok _ ->
            Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context


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
