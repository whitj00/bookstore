val start :
  pool:
    ( (module Caqti_async.CONNECTION),
      [< Caqti_error.t > `Decode_rejected
      `Encode_failed
      `Encode_rejected
      `Request_failed
      `Request_rejected
      `Response_failed
      `Response_rejected ] )
    Caqti_async.Pool.t ->
  port:int ->
  unit ->
  'a Async_kernel__Types.Deferred.t
