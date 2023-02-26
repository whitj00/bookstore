module Main : sig
  val lookup :
    Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t

  val search :
    Rpc_async.T.rpcfn -> string -> string Async_kernel__Types.Deferred.t

  val buy :
    Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t
end

val create_remote_rpc :
  host:string -> port:int -> Rpc.call -> Rpc.response Async.Deferred.t

module Time : sig
  val buy :
    Rpc_async.T.rpcfn -> int -> n:int -> string Async_kernel__Types.Deferred.t

  val search :
    Rpc_async.T.rpcfn ->
    string ->
    n:int ->
    string Async_kernel__Types.Deferred.t

  val lookup :
    Rpc_async.T.rpcfn -> int -> n:int -> string Async_kernel__Types.Deferred.t
end
