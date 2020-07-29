module Response exposing (error, methodNotAllowed, notFound, setBody, setContentType, setStatus)

import ContentType exposing (ContentType(..))
import Internal.Response exposing (Response(..))
import Internal.Server exposing (Context(..))
import Server
import Status exposing (Status(..))


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
notFound =
    Server.respond
        { body = "Not Found"
        , status = NotFound
        }


error : String -> Context -> Context
error body =
    Server.respond
        { body = body
        , status = InternalServerError
        }


methodNotAllowed : Context -> Context
methodNotAllowed =
    Server.respond
        { body = "Method Not Allowed"
        , status = MethodNotAllowed
        }
