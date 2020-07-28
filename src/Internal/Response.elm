module Internal.Response exposing (Response(..), default, map)

import ContentType exposing (ContentType(..))
import Status exposing (Status(..))


type Response
    = Building ResponseData
    | Sent


type alias ResponseData =
    { status : Status
    , body : String
    , contentType : ContentType
    }


default : Response
default =
    Building { status = Status.Ok, body = "", contentType = Text_Html }


map : (ResponseData -> ResponseData) -> Response -> Response
map fn response =
    case response of
        Sent ->
            response

        Building res ->
            Building (fn res)
