module Response exposing (error, methodNotAllowed, notFound, send, setBody, setContentType, setStatus)

import ContentType exposing (ContentType(..))
import Internal.Response exposing (Response(..))
import Internal.Server exposing (Context(..))
import Json.Encode
import Status exposing (Status(..))


send : Context -> Context
send (Context context) =
    case context.response of
        Sent ->
            Context context

        Building response ->
            Context
                { context
                    | commands =
                        { msg = "RESPOND"
                        , args =
                            Json.Encode.object
                                [ ( "options"
                                  , Json.Encode.object
                                        [ ( "status"
                                          , response.status
                                                |> Status.toCode
                                                |> Json.Encode.int
                                          )
                                        , ( "body"
                                          , Json.Encode.string response.body
                                          )
                                        , ( "contentType"
                                          , response.contentType
                                                |> ContentType.toString
                                                |> Json.Encode.string
                                          )
                                        ]
                                  )
                                , ( "req", context.request )
                                ]
                        }
                            :: context.commands
                    , response = Sent
                }


setStatus : Status -> Context -> Context
setStatus status (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | status = status })
                    context.response
        }


setBody : String -> Context -> Context
setBody body (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | body = body })
                    context.response
        }


setContentType : ContentType -> Context -> Context
setContentType contentType (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | contentType = contentType })
                    context.response
        }


notFound : Context -> Context
notFound (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | status = NotFound, body = "Not Found", contentType = Text_Html })
                    context.response
        }


error : String -> Context -> Context
error body (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | status = InternalServerError, body = body })
                    context.response
        }


methodNotAllowed : Context -> Context
methodNotAllowed (Context context) =
    Context
        { context
            | response =
                Internal.Response.map
                    (\res -> { res | status = MethodNotAllowed, body = "Method Not Allowed", contentType = Text_Html })
                    context.response
        }
