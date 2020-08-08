module HelloWorld exposing (main)

import Html.String as Html
import Html.String.Attributes as Attr
import Logger as Log
import Response
import Server exposing (Config, Flags, Request, Response)


main : Server.Program
main =
    Server.program
        { init = init
        , handler = handler
        }


init : Flags -> Config
init _ =
    Server.baseConfig


handler : Request -> Response
handler request =
    case Server.matchPath request of
        Ok [] ->
            Server.respond request (Response.default |> Response.setBody indexPage)
                |> Server.andThen (\_ -> Log.toConsole "index page requested")

        Ok [ "hello", name ] ->
            Log.toConsole ("Saying hello to " ++ name)
                |> Server.andThen
                    (\_ ->
                        Response.default
                            |> Response.setBody ("Hello, " ++ name ++ "!")
                            |> Server.respond request
                    )

        Ok _ ->
            Server.respond request Response.notFound

        Err err ->
            Server.respond request (Response.error err)


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
