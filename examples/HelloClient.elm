module HelloClient exposing (main)

import Html exposing (Html, div, h1, p, text)
import Html.Attributes exposing (style)


main : Html Never
main =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "align-items" "center"
        ]
        [ h1 [] [ text "Sample Elm Client" ]
        , p []
            [ text """This is an example of loading and sending some HTML from the server.""" ]
        ]
