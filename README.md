This was a fun experiment, and I learned a lot from it, especially a lot about [Deno](https://deno.land/). I definitely still love the idea of an Elm like language for back end development. I found breaking out of the handler into nested branches to be really easy to work with. I really love having Elm's type system as it allows me to use types to both describe and limit what's going on, while not being overly complicated like those of TypeScript, Rust, or Haskell; they're, _for me_, a nicely balanced type system.

In the end though, working inside the sandbox of a JS environment for a server just seems wrong. Most notably I found it interesting that Deno is a layer on top of Rust, with a huge influence from Go. Both of those languages are purpose built for back end work, more specifically Go is written for building servers. Deno (aka Javascript) doesn't have the performance benefits of Go or Rust (per the Deno devs), nor does it have what I would consider to be the better ergonomics of either. This isn't to say "don't use Deno". I've been very happy in my use of it in-place of where I hace typically used Node. I would say though that Elm on the back end would most definitely benefit from, as Evan has said before, not compiling to JS. (I can't speak to compiling to C, BEAM, or anything else as I don't know anything about compiling to those.)

----

# elm-server

Loosely based off of [ianmackenzie/elm-script](https://github.com/ianmackenzie/elm-script), [F#'s giraffe](https://github.com/giraffe-fsharp/Giraffe), and [Haskell's Servant](https://www.servant.dev/).

## WARNING THIS IS JUST FOR FUN NOT FOR PRODUCTION

## Basic Example:

```Elm
module HelloWorld exposing (main)

import Error
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
    case Server.matchPath request of
        Ok [] ->
            Server.respond request (Response.default |> Response.setBody "Hello, Elm Server!")
                |> Server.andThen (\_ -> Log.toConsole "index page requested")

        Ok [ "hello", name ] ->
            Log.toConsole ("Saying hello to " ++ name)
                |> Server.andThen
                    (\_ ->
                        Response.default
                            |> Response.setBody ("Hello, " ++ name ++ "!")
                            |> Server.respond request
                    )

        Ok _ ->
            Server.respond request Response.notFound

        Err err ->
            Server.respond request (Response.error (Error.toString err))
```

## Other Examples:

- [Hello World](./examples/HelloWorld.elm)
  - Your most basic examples
- [HTTPS](./examples/SecureWorld.elm) (You'll need to create your own certs if you want to try this one out.)
  - Extension of Hello World to show HTTPS
- [Load a file](./examples/HelloFile.elm), pairs with [HelloClient.elm](./examples/HelloClient.elm)
  - Shows loading a file from a local directory and returning the contents to the user
- [Database (Postgres)](./examples/HelloDBServer.elm), pairs with [Person.elm](./examples-db/Person.elm) and [HelloDBClient.elm](./examples/HelloDBClient.elm)
  - A simple client and server written in Elm. Only supports basic GET, POST, DELETE
  - Shows off sharing code between front and back end

All examples (listed and otherwise) can be found in [examples](./examples).

## Try it out:

1. clone this repo
1. install [Deno](https://deno.land/)
1. from the cloned repo run `./build.sh`
   - this compiles the js glue code which creates a command called `elm-server`
1. run `elm-server start path/to/YourServer.elm`
   - this starts your server

## Docs:

Too unstable to start writing docs.
