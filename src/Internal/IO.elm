module Internal.IO exposing (..)


import Dict exposing (Dict)
import Error exposing (Error(..))
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Process
import Set exposing (Set)
import Task exposing (Task)


type alias IO a =
    (Task Error ( ProcessChanges, a ))


type alias ProcessChanges =
    ( Dict String Process.Id, Set String )


evalSync : String -> List Value -> Decoder a -> Result Error a
evalSync jsFn args responseDecoder =
    Json.Encode.object [ ( "__elm_interop", Json.Encode.list identity (Json.Encode.string jsFn :: args) ) ]
        |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop" (decodeEvalResult responseDecoder))
        |> Result.mapError TypeError
        |> Result.andThen identity


evalAsync : String -> Value -> Decoder a -> IO a
evalAsync jsFn args responseDecoder =
    let
        token =
            Json.Encode.object []
    in
    Task.succeed ()
        |> Task.andThen
            (\_ ->
                let
                    _ =
                        Json.Encode.object
                            [ ( "__elm_interop_async"
                              , Json.Encode.list identity [ token, Json.Encode.string jsFn, args ]
                              )
                            ]
                in
                -- 69 108 109 == Elm
                Process.sleep -69108109
            )
        |> Task.andThen
            (\_ ->
                case
                    Json.Encode.object [ ( "token", token ) ]
                        |> Json.Decode.decodeValue (Json.Decode.field "__elm_interop_async" (decodeEvalResult responseDecoder))
                        |> Result.mapError TypeError
                        |> Result.andThen identity
                of
                    Ok result ->
                        Task.succeed ( noProcesses, result )

                    Err error ->
                        Task.fail error
            )


decodeEvalResult : Decoder a -> Decoder (Result Error a)
decodeEvalResult decodeResult =
    Json.Decode.field "tag" Json.Decode.string
        |> Json.Decode.andThen
            (\tag ->
                case tag of
                    "Ok" ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.decodeValue (Json.Decode.field "result" decodeResult) value
                                        |> Result.mapError TypeError
                                        |> Json.Decode.succeed
                                )

                    "Error" ->
                        Json.Decode.field "error" decodeRuntimeError
                            |> Json.Decode.map Err

                    _ ->
                        Json.Decode.value
                            |> Json.Decode.andThen
                                (\value ->
                                    Json.Decode.succeed
                                        (Json.Decode.Failure ("`tag` field must be one of Ok/Error, instead found `" ++ tag ++ "`") value
                                            |> TypeError
                                            |> Err
                                        )
                                )
            )


decodeRuntimeError : Decoder Error
decodeRuntimeError =
    Json.Decode.field "message" Json.Decode.string |> Json.Decode.map RuntimeError


andThen : (a -> IO b) -> IO a -> IO b
andThen fn =
    Task.andThen
        (\( processesA, a ) ->
            Task.map
                (Tuple.mapFirst (mergeProcessChanges processesA))
                 (fn a)
        )


map : (a -> b) -> IO a -> IO b
map fn =
    Task.map (Tuple.mapSecond fn)


pure : a -> IO a
pure a =
    Task.succeed ( noProcesses, a )


fail : String -> IO a
fail =
    RuntimeError >> Task.fail


recover : (Error -> IO a) -> IO a -> IO a
recover =
    Task.onError


sleep : Float -> IO ()
sleep =
    Process.sleep
        >> Task.map (Tuple.pair noProcesses)


---- HELPERS


loop : String -> IO a -> IO Process.Id
loop id toLoop =
    Process.spawn toLoop
        |> savePid id
        |> andThen (\_ -> Process.spawn toLoop |> savePid id)


savePid : String -> Task Error Process.Id -> IO Process.Id
savePid key =
    Task.map
        (\pid ->
            ( ( Dict.singleton key pid
                , Set.empty
                )
            , pid
            )
        )


noProcesses : ProcessChanges
noProcesses =
    ( Dict.empty, Set.empty )


mergeProcessChanges : ProcessChanges -> ProcessChanges -> ProcessChanges
mergeProcessChanges ( newProcessesA, toRemoveA ) ( newProcessesB, toRemoveB ) =
    ( Dict.union newProcessesA newProcessesB, Set.union toRemoveA toRemoveB )