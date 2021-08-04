module Internal.Response exposing (Header(..), InternalResponse(..), ResponseData, base, map)

import ContentType exposing (ContentType(..))
import Status exposing (Status(..))


type InternalResponse
    = InternalResponse ResponseData


type alias ResponseData =
    { status : Status
    , body : String
    , contentType : ContentType
    , headers : List Header
    }


type Header = Header
    { key : String
    , value : String
    }


base : InternalResponse
base =
    InternalResponse
        { status = StatusOk
        , body = "OK"
        , contentType = Text_Html
        , headers = []
        }


map : (ResponseData -> ResponseData) -> InternalResponse -> InternalResponse
map fn (InternalResponse response) =
    InternalResponse (fn response)
