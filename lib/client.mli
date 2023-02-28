module Main : sig
  val lookup : Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t

  val search :
    Rpc_async.T.rpcfn -> string -> string Async_kernel__Types.Deferred.t

  val buy : Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t
end

module Rpc : sig
  val create_remote_rpc : host:string -> port:int -> Rpc_async.T.rpcfn
end

module Time : sig
  val test_buy :
    n:int ->
    c:int ->
    Rpc_async.T.rpcfn ->
    int ->
    string Async_kernel__Types.Deferred.t

  val test_search :
    n:int ->
    c:int ->
    Rpc_async.T.rpcfn ->
    string ->
    string Async_kernel__Types.Deferred.t

  val test_lookup :
    n:int ->
    c:int ->
    Rpc_async.T.rpcfn ->
    int ->
    string Async_kernel__Types.Deferred.t
end
