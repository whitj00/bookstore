module Main : sig
  val lookup : Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t

  val search :
    Rpc_async.T.rpcfn -> string -> string Async_kernel__Types.Deferred.t

  val buy : Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t
end

module Rpc : sig
  val create_remote_rpc :
    host:string -> port:int -> Rpc.call -> Rpc.response Async.Deferred.t
end

module Time : sig
  val test_buy :
    Rpc_async.T.rpcfn ->
    int ->
    n:int ->
    c:int ->
    string Async_kernel__Types.Deferred.t

  val test_search :
    Rpc_async.T.rpcfn ->
    string ->
    n:int ->
    c:int ->
    string Async_kernel__Types.Deferred.t

  val test_lookup :
    Rpc_async.T.rpcfn ->
    int ->
    n:int ->
    c:int ->
    string Async_kernel__Types.Deferred.t
end
