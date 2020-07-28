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
                |> Response.setBody indexPage
                |> Response.send

        Ok [ "hello", name ] ->
            context
                |> Response.setBody ("Hello, " ++ name ++ "!")
                |> Response.send

        Ok _ ->
            context
                |> Response.notFound
                |> Response.send

        Err err ->
            context
                |> Response.error err
                |> Response.send
```

To try it out:

- clone this repo
- install [Deno](https://deno.land/)
- from the cloned repo run `deno install -A -f elm-server ./src/main.js`
  - this compiles the js glue code creates a command called `elm-server`
- run `elm-server start path/to/your/server.elm`
  - this starts your server

## Docs

Too unstable to start writing docs.