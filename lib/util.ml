open! Core
open! Async
open! Rpc_async

let string_of_default_error (e : Idl.DefaultError.t) =
  match e with InternalError s -> s
