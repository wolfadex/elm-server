module HelloWorld exposing (main)

import Error
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
    case Server.getPath request of
        [] ->
            Response.ok
                |> Response.setBody indexPage
                |> Server.respond request
                |> Server.andThen (\_ -> Log.toConsole "index page requested")

        [ "hello" ] ->
            let
                maybeName =
                    Server.getQueryParams request
                        |> listFind (\( key, _ ) -> key == "name")
            in
            case maybeName of
                Just ( _, Just name ) ->
                    Log.toConsole ("Saying hello to " ++ name)
                        |> Server.andThen
                            (\_ ->
                                Response.ok
                                    |> Response.setBody ("Hello, " ++ name ++ "!")
                                    |> Server.respond request
                            )

                _ ->
                    Response.ok
                        |> Response.setBody "What is your name?"
                        |> Server.respond request

        _ ->
            Response.notFound
                |> Server.respond request


listFind : (a -> Bool) -> List a -> Maybe a
listFind predicate list =
    case list of
        [] ->
            Nothing

        next :: rest ->
            if predicate next then
                Just next

            else
                listFind predicate rest


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
                [ Attr.href "hello?name=carl" ]
                [ Html.text "Say Hello" ]
            ]
        ]
        |> Html.toString 2
        |> (++) "<!DOCTYPE html><html><head><title>Fun With Elm</title></head><body>"
        |> (\html ->
                html
                    ++ "</body></html>"
           )
