val get_lookup_result : Rpc_async.T.rpcfn -> int -> string Async_kernel__Types.Deferred.t
val get_search_result : Rpc_async.T.rpcfn -> string -> string Async_kernel__Types.Deferred.t
val create_remote_rpc : host:string -> port:int -> Rpc.call -> Rpc.response Async.Deferred.t
val demo_rpc : Rpc.call -> Rpc.response Async.Deferred.t