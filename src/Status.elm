module Status exposing (Status(..), fromCode, toCode)


type Status
    = Continue
    | SwitchingProtocols
    | Processing
    | EarlyHints
    | Ok
    | Created
    | Accepted
    | NonAuthoritativeInformation
    | NoContent
    | ResetContent
    | PartialContent
    | MultiStatus
    | AlreadyReported
    | IMUsed
    | MultipleChoices
    | MovedPermanently
    | Found
    | SeeOther
    | NotModified
    | UseProxy
    | SwitchProxy
    | TemporaryRedirect
    | PermanentRedirect
    | BadRequest
    | Unauthorized
    | PaymentRequired
    | Forbidden
    | NotFound
    | MethodNotAllowed
    | NotAcceptable
    | ProxyAuthenticationRequired
    | RequestTimeout
    | Conflict
    | Gone
    | LengthRequired
    | PreconditionFailed
    | PayloadTooLarge
    | URITooLong
    | UnsupportedMediaType
    | RangeNotSatisfiable
    | ExpectationFailed
    | ImATeapot
    | MisdirectedRequest
    | UnprocessableEntity
    | Locked
    | FailedDependency
    | TooEarly
    | UpgradeRequired
    | PreconditionRequired
    | TooManyRequests
    | RequestHeaderFieldsTooLarge
    | UnavailableForLegalReasons
    | InternalServerError
    | NotImplemented
    | BadGateway
    | ServiceUnavailable
    | GatewayTimeout
    | HTTPVersionNotSupported
    | VariantAlsoNegotiates
    | InsufficientStorage
    | LoopDetected
    | NotExtended
    | NetworkAuthenticationRequired


toCode : Status -> Int
toCode status =
    case status of
        Continue ->
            100

        SwitchingProtocols ->
            101

        Processing ->
            102

        EarlyHints ->
            103

        Ok ->
            200

        Created ->
            201

        Accepted ->
            202

        NonAuthoritativeInformation ->
            203

        NoContent ->
            204

        ResetContent ->
            205

        PartialContent ->
            206

        MultiStatus ->
            207

        AlreadyReported ->
            208

        IMUsed ->
            226

        MultipleChoices ->
            300

        MovedPermanently ->
            301

        Found ->
            302

        SeeOther ->
            303

        NotModified ->
            304

        UseProxy ->
            305

        SwitchProxy ->
            306

        TemporaryRedirect ->
            307

        PermanentRedirect ->
            308

        BadRequest ->
            400

        Unauthorized ->
            401

        PaymentRequired ->
            402

        Forbidden ->
            403

        NotFound ->
            404

        MethodNotAllowed ->
            405

        NotAcceptable ->
            406

        ProxyAuthenticationRequired ->
            407

        RequestTimeout ->
            408

        Conflict ->
            409

        Gone ->
            410

        LengthRequired ->
            411

        PreconditionFailed ->
            412

        PayloadTooLarge ->
            413

        URITooLong ->
            414

        UnsupportedMediaType ->
            415

        RangeNotSatisfiable ->
            416

        ExpectationFailed ->
            417

        ImATeapot ->
            418

        MisdirectedRequest ->
            421

        UnprocessableEntity ->
            422

        Locked ->
            423

        FailedDependency ->
            424

        TooEarly ->
            425

        UpgradeRequired ->
            426

        PreconditionRequired ->
            428

        TooManyRequests ->
            429

        RequestHeaderFieldsTooLarge ->
            431

        UnavailableForLegalReasons ->
            451

        InternalServerError ->
            500

        NotImplemented ->
            501

        BadGateway ->
            502

        ServiceUnavailable ->
            503

        GatewayTimeout ->
            504

        HTTPVersionNotSupported ->
            505

        VariantAlsoNegotiates ->
            506

        InsufficientStorage ->
            507

        LoopDetected ->
            508

        NotExtended ->
            510

        NetworkAuthenticationRequired ->
            511


fromCode : Int -> Maybe Status
fromCode code =
    case code of
        100 ->
            Just Continue

        101 ->
            Just SwitchingProtocols

        102 ->
            Just Processing

        103 ->
            Just EarlyHints

        200 ->
            Just Ok

        201 ->
            Just Created

        202 ->
            Just Accepted

        203 ->
            Just NonAuthoritativeInformation

        204 ->
            Just NoContent

        205 ->
            Just ResetContent

        206 ->
            Just PartialContent

        207 ->
            Just MultiStatus

        208 ->
            Just AlreadyReported

        226 ->
            Just IMUsed

        300 ->
            Just MultipleChoices

        301 ->
            Just MovedPermanently

        302 ->
            Just Found

        303 ->
            Just SeeOther

        304 ->
            Just NotModified

        305 ->
            Just UseProxy

        306 ->
            Just SwitchProxy

        307 ->
            Just TemporaryRedirect

        308 ->
            Just PermanentRedirect

        400 ->
            Just BadRequest

        401 ->
            Just Unauthorized

        402 ->
            Just PaymentRequired

        403 ->
            Just Forbidden

        404 ->
            Just NotFound

        405 ->
            Just MethodNotAllowed

        406 ->
            Just NotAcceptable

        407 ->
            Just ProxyAuthenticationRequired

        408 ->
            Just RequestTimeout

        409 ->
            Just Conflict

        410 ->
            Just Gone

        411 ->
            Just LengthRequired

        412 ->
            Just PreconditionFailed

        413 ->
            Just PayloadTooLarge

        414 ->
            Just URITooLong

        415 ->
            Just UnsupportedMediaType

        416 ->
            Just RangeNotSatisfiable

        417 ->
            Just ExpectationFailed

        418 ->
            Just ImATeapot

        421 ->
            Just MisdirectedRequest

        422 ->
            Just UnprocessableEntity

        423 ->
            Just Locked

        424 ->
            Just FailedDependency

        425 ->
            Just TooEarly

        426 ->
            Just UpgradeRequired

        428 ->
            Just PreconditionRequired

        429 ->
            Just TooManyRequests

        431 ->
            Just RequestHeaderFieldsTooLarge

        451 ->
            Just UnavailableForLegalReasons

        500 ->
            Just InternalServerError

        501 ->
            Just NotImplemented

        502 ->
            Just BadGateway

        503 ->
            Just ServiceUnavailable

        504 ->
            Just GatewayTimeout

        505 ->
            Just HTTPVersionNotSupported

        506 ->
            Just VariantAlsoNegotiates

        507 ->
            Just InsufficientStorage

        508 ->
            Just LoopDetected

        510 ->
            Just NotExtended

        511 ->
            Just NetworkAuthenticationRequired

        _ ->
            Nothing
