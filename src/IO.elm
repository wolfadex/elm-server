port module IO exposing ( ..)


import Dict exposing (Dict)
import Error exposing (Error(..))
import Internal.IO exposing (ProcessChanges)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Platform
import Set exposing (Set)
import Task exposing (Task)
import Process


---- EXTERNAL

-- TYPES


type alias Program =
    Platform.Program Flags Model Msg


type alias IO a =
    Internal.IO.IO a


type PermissionSpecificity
    = Any
    | Only String


type Permission
    = RunPermission PermissionSpecificity -- url
    | ReadPermission PermissionSpecificity -- path
    | WritePermission PermissionSpecificity -- path
    | NetPermission PermissionSpecificity -- host
    | EnvPermission PermissionSpecificity -- variable
    | FfiPermission
    | HrtimePermission


enableAllPermissions : List Permission
enableAllPermissions =
    [ RunPermission Any
    , ReadPermission Any -- path
    , WritePermission Any -- path
    , NetPermission Any -- host
    , EnvPermission Any -- variable
    , FfiPermission
    , HrtimePermission
    ]


-- CORE IO


program :List Permission -> IO () -> Program
program permissions io =
    Platform.worker
        { init = \_ ->
            ( Dict.empty
            , Task.attempt Next (requestPermissions permissions |> andThen (\_ -> io))
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
map =
    Internal.IO.map
            


recover : (Error -> IO a) -> IO a -> IO a
recover =
    Internal.IO.recover


pure : a -> IO a
pure =
    Internal.IO.pure


fail : String -> IO a
fail =
    Internal.IO.fail


-- sequence : List (IO a) -> IO b -> IO (List a)
-- sequence =
--     Task.map Task.sequence


sleep : Float -> IO ()
sleep =
    Internal.IO.sleep


-- PERMISSIONS


requestPermissions : List Permission -> IO ()
requestPermissions permissions =
    Internal.IO.evalAsync "requestPermissions"
        (Json.Encode.list encodePermission permissions)
        (Json.Decode.succeed ())


revokePermissions : List Permission -> IO ()
revokePermissions permissions =
    Internal.IO.evalAsync "revokePermissions"
        (Json.Encode.list encodePermission permissions)
        (Json.Decode.succeed ())




---- IMPLEMENTATION


encodePermission : Permission -> Value
encodePermission permission =
    Json.Encode.object <|
        case permission of
            RunPermission specificity ->
                ( "name", Json.Encode.string "run" )
                    :: case specificity of
                        Any -> []
                        Only command -> [ ( "command", Json.Encode.string command ) ]

            ReadPermission specificity ->
                ( "name", Json.Encode.string "read" )
                    :: case specificity of
                        Any -> []
                        Only path -> [ ( "path", Json.Encode.string path ) ]

            WritePermission specificity ->
                ( "name", Json.Encode.string "write" )
                    :: case specificity of
                        Any -> []
                        Only path -> [ ( "path", Json.Encode.string path ) ]

            NetPermission specificity ->
                ( "name", Json.Encode.string "net" )
                    :: case specificity of
                        Any -> []
                        Only host -> [ ( "host", Json.Encode.string host ) ]

            EnvPermission specificity ->
                ( "name", Json.Encode.string "env" )
                    :: case specificity of
                        Any -> []
                        Only variable -> [ ( "variable", Json.Encode.string variable ) ]

            FfiPermission ->
                [ ( "name", Json.Encode.string "ffi" ) ]

            HrtimePermission ->
                [ ( "name", Json.Encode.string "hrtime" ) ]


initialState : ( ProcessChanges, () )
initialState =
    ( Internal.IO.noProcesses, () )


type alias Model =
    Dict String Process.Id


type alias Flags =
    { arguments : List String
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