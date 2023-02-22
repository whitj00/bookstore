val rpc_fn :
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
  Rpc.call ->
  Rpc.response Async.Deferred.t

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
  (Async_unix__Unix_syscalls.Socket.Address.Inet.t, int) Cohttp_async.Server.t
  Async_kernel__Types.Deferred.t
