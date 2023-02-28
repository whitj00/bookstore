open Async

module Connection_pool : sig
  type t

  val create : ?uri:string -> unit -> t
end

module Util : sig
  val create_tables : pool:Connection_pool.t -> unit -> unit Deferred.t
  val drop_tables : pool:Connection_pool.t -> unit -> unit Deferred.t
  val reset_tables : pool:Connection_pool.t -> unit -> unit Deferred.t

  val add_row :
    pool:Connection_pool.t ->
    int * string * string * int * float ->
    unit Deferred.t
end

module Client : sig
  val lookup_book :
    pool:Connection_pool.t ->
    int ->
    (string * string * int * float) option Deferred.t

  val search_book :
    pool:Connection_pool.t -> string -> (int * string) list Deferred.t

  val buy_book : pool:Connection_pool.t -> int -> (bool * string) Deferred.t
end

module Server : sig
  val get_purchases :
    pool:Connection_pool.t ->
    unit ->
    (int * string * float * int) list Deferred.t

  val update_price : pool:Connection_pool.t -> float -> int -> bool Deferred.t
  val update_stock : pool:Connection_pool.t -> int -> int -> bool Deferred.t
end
