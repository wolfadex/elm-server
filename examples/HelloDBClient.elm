module HelloDBClient exposing (main)

import Browser exposing (Document)
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Http
import Internal.Server exposing (Request)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { persons : Request (List Person)
    }


type Request d
    = NotYetRequested
    | Loading
    | Success d
    | Failure Http.Error


decodePersons : Decoder (List Person)
decodePersons =
    Json.Decode.list decodePerson


decodePerson : Decoder Person
decodePerson =
    Json.Decode.map3 Person
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "age" Json.Decode.int)


encodePerson : Person -> Value
encodePerson { id, name, age } =
    Json.Encode.object
        [ ( "id", Json.Encode.int id )
        , ( "name", Json.Encode.string name )
        , ( "age", Json.Encode.int age )
        ]


type alias Person =
    { id : Int
    , name : String
    , age : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { persons = Loading }
    , Http.get
        { url = "/persons"
        , expect = Http.expectJson GotPersons decodePersons
        }
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type Msg
    = NoOp
    | GotPersons (Result Http.Error (List Person))
    | DeletePerson Int
    | PersonDeleted (Result Http.Error Int)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotPersons response ->
            case response of
                Ok persons ->
                    ( { model | persons = Success persons }, Cmd.none )

                Err err ->
                    ( { model | persons = Failure err }, Cmd.none )

        DeletePerson id ->
            ( model
            , Http.request
                { method = "DELETE"
                , headers = []
                , url = "/persons/" ++ String.fromInt id
                , body = Http.emptyBody
                , expect = Http.expectWhatever (Result.map (\() -> id) >> PersonDeleted)
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        PersonDeleted response ->
            case ( model.persons, response ) of
                ( Success persons, Ok deletedId ) ->
                    ( { model
                        | persons =
                            persons
                                |> List.filter (.id >> (/=) deletedId)
                                |> Success
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )


view : Model -> Document Msg
view model =
    { title = "Hello DB Client"
    , body = [ layout [ width fill, height fill ] (viewBody model) ]
    }


viewBody : Model -> Element Msg
viewBody { persons } =
    column [ centerX, spacing 16, padding 16 ]
        [ el [ Font.size 32, Font.underline ] <|
            text "PERSONS"
        , column [ spacing 16, centerX ] <|
            case persons of
                NotYetRequested ->
                    [ text "You should load the persons" ]

                Loading ->
                    [ text "Loading Persons..." ]

                Failure err ->
                    [ text ("Failed to load the persons: " ++ Debug.toString err) ]

                Success people ->
                    List.map viewPerson people
        ]


viewPerson : Person -> Element Msg
viewPerson { id, name, age } =
    column []
        [ text ("Name: " ++ name)
        , text ("Age: " ++ String.fromInt age)
        , Input.button []
            { label = text "Delete"
            , onPress = Just (DeletePerson id)
            }
        ]
