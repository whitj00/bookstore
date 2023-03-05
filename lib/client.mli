open! Core
open Async
open Rpc_async

module Main : sig
  val lookup : T.rpcfn -> int -> string Deferred.t
  val search : T.rpcfn -> string -> string Deferred.t
  val buy : Rpc_async.T.rpcfn -> int -> string Deferred.t
end

module Rpc : sig
  val create_remote_rpc : host:string -> port:int -> T.rpcfn
end

module Time : sig
  val test_buy : n:int -> c:int -> T.rpcfn -> int -> string Deferred.t
  val test_search : n:int -> c:int -> T.rpcfn -> string -> string Deferred.t
  val test_lookup : n:int -> c:int -> T.rpcfn -> int -> string Deferred.t
end

module Repl : sig
  val start : host:string -> port:int -> unit Async_kernel__Types.Deferred.t
end
