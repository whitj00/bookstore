module SearchRecord : sig
  type t = { title : string; item_number : int }
end

module SearchResponse : sig
  type t = SearchRecord.t list

  val to_string : t -> string
end

module LookupResponse : sig
  type t = { title : string; topic : string; stock : int; price : float }

  val to_string : t -> string
end

module BuyResponse : sig
  type t

  val to_string : int -> string
end

module BookstoreAPI : functor (R : Idl.RPC) -> sig
  val implementation : R.implementation
  val lookup : (int -> (LookupResponse.t, Idl.DefaultError.t) R.comp) R.res
  val buy : (int -> (int, Idl.DefaultError.t) R.comp) R.res

  val search :
    (string -> (SearchRecord.t list, Idl.DefaultError.t) R.comp) R.res
end
