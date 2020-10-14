module Response exposing
    ( Header
    , Response
    , error
    , header
    , json
    , methodNotAllowed
    , notFound
    , ok
    , setBody
    , setContentType
    , setStatus
    )

import ContentType exposing (ContentType(..))
import Http exposing (Response)
import Internal.Response exposing (Header, InternalResponse(..))
import Json.Encode exposing (Value)
import Status exposing (Status(..))


setStatus : Status -> Response -> Response
setStatus status =
    Internal.Response.map (\r -> { r | status = status })


setBody : String -> Response -> Response
setBody body =
    Internal.Response.map (\r -> { r | body = body })


setContentType : ContentType -> Response -> Response
setContentType contentType =
    Internal.Response.map (\r -> { r | contentType = contentType })


type alias Response =
    InternalResponse


type Header
    = Header Internal.Response.Header


ok : Response
ok =
    Internal.Response.base


header : String -> String -> Header
header key value =
    Header { key = key, value = value }


json : Value -> Response
json body =
    Internal.Response.base
        |> Internal.Response.map
            (\r ->
                { r
                    | body = Json.Encode.encode 0 body
                    , contentType = Application_Json
                }
            )


notFound : Response
notFound =
    Internal.Response.base
        |> Internal.Response.map (\r -> { r | status = NotFound, body = "Not Found" })


error : String -> Response
error body =
    Internal.Response.base
        |> Internal.Response.map (\r -> { r | status = InternalServerError, body = body })


methodNotAllowed : Response
methodNotAllowed =
    Internal.Response.base
        |> Internal.Response.map (\r -> { r | status = MethodNotAllowed, body = "Method Not Allowed" })
