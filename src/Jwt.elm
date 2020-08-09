module Jwt exposing (Header, Key, Payload, Token, make, validate)

import Internal.Server exposing (runTask)
import Json.Encode
import Server exposing (Response)


type alias Header =
    { algorithm : String
    , typ : String
    }


type alias Token =
    String


type alias Payload =
    { iss : String
    , expiration : Int
    }


type alias Key =
    String


make : { header : Header, payload : Payload, key : Key } -> Response
make args =
    [ ( "header"
      , Json.Encode.object
            [ ( "alg", Json.Encode.string args.header.algorithm )
            , ( "typ", Json.Encode.string args.header.typ )
            ]
      )
    , ( "payload"
      , Json.Encode.object
            [ ( "iss", Json.Encode.string args.payload.iss )
            , ( "exp", Json.Encode.int args.payload.expiration )
            ]
      )
    , ( "key", Json.Encode.string args.key )
    ]
        |> Json.Encode.object
        |> runTask "JWT_GENERATE"


validate : { token : Token, key : Key, algorithm : String } -> Response
validate args =
    [ ( "jwt", Json.Encode.string args.token )
    , ( "key", Json.Encode.string args.key )
    , ( "algorithm", Json.Encode.string args.algorithm )
    ]
        |> Json.Encode.object
        |> runTask "JWT_VALIDATE"
