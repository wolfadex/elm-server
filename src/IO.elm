port module IO exposing ( ..)


import Dict exposing (Dict)
import Error exposing (Error(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Platform
import Set exposing (Set)
import Task exposing (Task)
import Process
import Internal.IO exposing (ProcessChanges)


---- EXTERNAL

-- TYPES


type alias Program =
    Platform.Program Flags Model Msg


type alias IO a =
    Internal.IO.IO a


-- CORE IO


program : IO () -> Program
program io =
    Platform.worker
        { init = \_ ->
            ( Dict.empty
            , Task.attempt Next io
            )
        , update = update
        , subscriptions = \_ -> jsEvent JsEvent
        }


readLine : IO String
readLine =
    Internal.IO.evalAsync "stdin" Json.Encode.null Json.Decode.string


print : String -> IO ()
print content =
    Internal.IO.evalAsync "stdout" (Json.Encode.string content) (Json.Decode.succeed ())
        


printLine : String -> IO ()
printLine content =
    print (content ++ "\n")



-- HELPERS


andThen : (a -> IO b) -> IO a -> IO b
andThen =
    Internal.IO.andThen


thenDo : IO b -> IO a -> IO b
thenDo ioB =
    andThen (\_ -> ioB)


-- andMap : IO a -> IO (a -> b) -> IO b
-- andMap =
--     Task.map2 (|>)


map : (a -> b) -> IO a -> IO b
map fn =
    Task.map (Tuple.mapSecond fn)
            


-- recover : (Error -> IO a) -> IO a -> IO a
-- recover =
--     Task.onError


pure : a -> IO a
pure a =
    Task.succeed ( Internal.IO.noProcesses, a )


fail : String -> IO a
fail =
    RuntimeError >> Task.fail


-- sequence : List (IO a) -> IO b -> IO (List a)
-- sequence =
--     Task.map Task.sequence


sleep : Float -> IO ()
sleep =
    Process.sleep
        >> Task.map (Tuple.pair Internal.IO.noProcesses)


-- HTTP




---- IMPLEMENTATION


initialState : ( ProcessChanges, () )
initialState =
    ( Internal.IO.noProcesses, () )


type alias Model =
    Dict String Process.Id


type alias Flags =
    { environment : Value
    , arguments : List String
    }


type Msg
    = Next (Result Error ( ProcessChanges, () ))
    | JsEvent Value


port jsEvent : (Value -> msg) -> Sub msg
port finished : Int -> Cmd msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Next result ->
            case result of
                Ok ( ( newProcesses, processesToRemove ), () ) ->
                    let
                        remainingProcesses =
                            Set.foldl Dict.remove
                                (Dict.union model newProcesses)
                                processesToRemove
                    in
                    ( remainingProcesses, if Dict.isEmpty remainingProcesses then finished 0 else Cmd.none )

                Err err ->
                    let
                        _ =
                            Debug.log "Error" err
                    in
                    ( model, finished 1 )

        JsEvent _ ->
            ( model, Cmd.none )