module Response exposing
    ( Header
    , Response
    , default
    , error
    , header
    , json
    , methodNotAllowed
    , notFound
    , setBody
    , setContentType
    , setStatus
    )

import ContentType exposing (ContentType(..))
import Http exposing (Response)
import Internal.Response exposing (Header, InternalResponse(..))
import Internal.Server exposing (Context(..))
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


default : Response
default =
    Internal.Response.base


header : String -> String -> Header
header key value =
    Header { key = key, value = value }


json : Value -> Response
json body =
    Internal.Response.base
        |> Internal.Response.map
            (\r ->
                { r | status = InternalServerError, body = Json.Encode.encode 0 body }
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
