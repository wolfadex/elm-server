module HelloDBClient exposing (main)

import Browser exposing (Document)
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Http exposing (Error(..), Response(..))
import Json.Encode
import Person exposing (Person)


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


init : () -> ( Model, Cmd Msg )
init _ =
    ( { persons = Loading }
    , getPeople
    )


getPeople : Cmd Msg
getPeople =
    Http.get
        { url = "/persons"
        , expect = Http.expectJson GotPersons Person.decodeMany
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


type Msg
    = NoOp
    | GotPersons (Result Http.Error (List Person))
    | DeletePerson Person
    | PersonDeleted (Result Http.Error Person)
    | CreatePerson
    | NewPersonAdded (Result Http.Error ())


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

        DeletePerson person ->
            ( model
            , Http.request
                { method = "DELETE"
                , headers = []
                , url =
                    person
                        |> Person.getId
                        |> String.fromInt
                        |> (++) "/persons/"
                , body = Http.emptyBody
                , expect = Http.expectWhatever (Result.map (\() -> person) >> PersonDeleted)
                , timeout = Nothing
                , tracker = Nothing
                }
            )

        PersonDeleted response ->
            case ( model.persons, response ) of
                ( Success persons, Ok deletedPerson ) ->
                    ( { model
                        | persons =
                            persons
                                |> List.filter (Person.getId >> (/=) (Person.getId deletedPerson))
                                |> Success
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        NewPersonAdded response ->
            case response of
                Ok () ->
                    ( { model | persons = Loading }, getPeople )

                Err _ ->
                    ( model, Cmd.none )

        CreatePerson ->
            ( model
            , Http.post
                { url = "/persons"
                , body =
                    [ ( "name", Json.Encode.string "Barl" )
                    , ( "age", Json.Encode.int 55 )
                    ]
                        |> Json.Encode.object
                        |> Http.jsonBody
                , expect = Http.expectWhatever NewPersonAdded
                }
            )


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
        , Input.button []
            { label = text "Create"
            , onPress = Just CreatePerson
            }
        ]


viewPerson : Person -> Element Msg
viewPerson person =
    column []
        [ text ("Name: " ++ Person.getName person)
        , person
            |> Person.getAge
            |> String.fromInt
            |> (++) "Age: "
            |> text
        , Input.button []
            { label = text "Delete"
            , onPress = Just (DeletePerson person)
            }
        ]
