val default_url : string
val create_pool :
  ?uri:string ->
  unit ->
  (Caqti_async.connection, [> Caqti_error.connect ]) Caqti_async.Pool.t

val create_table :
    pool:((module Caqti_async.CONNECTION),
        [< Caqti_error.t
            > `Decode_rejected `Encode_failed `Encode_rejected
            `Request_failed `Request_rejected `Response_failed
            `Response_rejected ])
        Caqti_async.Pool.t ->
    unit -> unit Async.Deferred.t

val drop_table :
    pool:((module Caqti_async.CONNECTION),
    [< Caqti_error.t
        > `Decode_rejected `Encode_failed `Encode_rejected
        `Request_failed `Request_rejected `Response_failed
        `Response_rejected ])
    Caqti_async.Pool.t ->
    unit -> unit Async.Deferred.t

val reset_table :
    pool:((module Caqti_async.CONNECTION),
    [< Caqti_error.t
        > `Decode_rejected `Encode_failed `Encode_rejected
        `Request_failed `Request_rejected `Response_failed
        `Response_rejected ])
    Caqti_async.Pool.t ->
    unit -> unit Async.Deferred.t

val add_row :
    pool:((module Caqti_async.CONNECTION),
    [< Caqti_error.t
        > `Decode_rejected `Encode_failed `Encode_rejected
        `Request_failed `Request_rejected `Response_failed
        `Response_rejected ])
    Caqti_async.Pool.t ->
    int * string * string * int * float -> unit Async.Deferred.t

val lookup_book :
    pool:((module Caqti_async.CONNECTION),
          [< Caqti_error.t
           > `Decode_rejected `Encode_failed `Encode_rejected
             `Request_failed `Request_rejected `Response_failed
             `Response_rejected ])
         Caqti_async.Pool.t ->
    int ->
    (string * string * int * float) option
    Async_kernel__Types.Deferred.t

val search_book :
    pool:((module Caqti_async.CONNECTION),
            [< Caqti_error.t
            > `Decode_rejected `Encode_failed `Encode_rejected
                `Request_failed `Request_rejected `Response_failed
                `Response_rejected ])
            Caqti_async.Pool.t ->
    string ->
    string list Async_kernel__Types.Deferred.t
