val lookup : (Rpc.call -> Rpc.response Async.Deferred.t) -> int -> (string, Idl.DefaultError.t) Rpc_async.T.resultb
val create_remote_rpc : host:string -> port:int -> Rpc.call -> Rpc.response Async.Deferred.t
val demo_rpc : Rpc.call -> Rpc.response Async.Deferred.t