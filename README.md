# elm-server

Loosely based off of [ianmackenzie/elm-script](https://github.com/ianmackenzie/elm-script), [F#'s giraffe](https://github.com/giraffe-fsharp/Giraffe), and [Haskell's Servant](https://www.servant.dev/).

## WARNING THIS IS JUST FOR FUN NOT FOR PRODUCTION

See [examples/HelloWorld.elm](./examples/Hello) for a brief example of the basics.

The bare minimum server file is:

```Elm
module HelloWorld exposing (main)

import Response
import Server exposing (Config, Context, Flags)

main : Server.Program
main =
    Server.program
        { init = init
        , handler = handler
        }


init : Flags -> Config
init _ =
    Server.baseConfig

handler : Context -> Context
handler context =
    case Server.matchPath context of
        Ok [] ->
            context
                |> Server.respond (Response.default |> Response.setBody indexPage)

        Ok [ "hello", name ] ->
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

        -- Basic DB query and response.
        -- The query will definitely change but the handling of the response will most
        -- likely stay very similar
        Result.Ok [ "persons" ] ->
            Database.query "SELECT * FROM persons;"
                |> Server.onError (\err -> Server.respond (Response.error err) context)
                |> Server.onSuccess (\{ body } -> Server.respond (Response.json body) context)

        Ok _ ->
            Server.respond Response.notFound context

        Err err ->
            Server.respond (Response.error err) context
```

To try it out:

- clone this repo
- install [Deno](https://deno.land/)
- from the cloned repo run `./build.sh`
  - this compiles the js glue code which creates a command called `elm-server`
- run `elm-server start path/to/YourServer.elm`
  - this starts your server

## Docs

Too unstable to start writing docs.
