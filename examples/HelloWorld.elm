module HelloWorld exposing (main)

import IO exposing (IO, Permission(..), PermissionSpecificity(..))
import IO.Http exposing (Request)
import IO.File


main : IO.Program
main =
    IO.program
        -- [ NetPermission Any ]
        []
        (IO.pure 2222
            |> IO.andThen (\port_ -> IO.Http.listen port_ |> IO.map (Tuple.pair port_))
            |> IO.andThen
                (\( port_, listener ) ->
                    IO.Http.acceptConnection listener
                        (\connection ->
                            IO.Http.serve connection handleRequest
                                |> IO.andThen (\connectionPid -> IO.printLine "connecting")
                        )
                        |> IO.map (Tuple.pair port_)
                )
            |> IO.andThen (\( port_, listenerPid ) -> IO.printLine ("Server listening on port " ++ String.fromInt port_))
        )


handleRequest : Request -> IO ()
handleRequest request =
    case IO.Http.getUrl request of
        Ok url ->
            case String.replace "http://localhost:2222/" "" url |> String.toFloat of
                Nothing ->
                    IO.Http.respondWith ("Hello " ++ url) request

                Just sleepSeconds ->
                    IO.sleep (sleepSeconds * 1000)
                        |> IO.thenDo (IO.Http.respondWith ("Responding after " ++ String.fromFloat sleepSeconds ++ " seconds") request)

        Err err ->
            IO.fail "Error getting url"
