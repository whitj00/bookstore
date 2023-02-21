module SearchResponse = struct
  type t = string list [@@deriving rpcty]
end

module LookupResponse = struct
  type t = string [@@deriving rpcty]
end

module BookstoreAPI (R : Idl.RPC) = struct
  open R
  open Idl

  (* We define the description of our API *)
  let description = 
    Interface.
    { name = "Bookstore"
    ; namespace = None
    ; description = [ "Bookstore Project" ]
    ; version = 1, 0, 0
    }

  (* We implement the API using the description we just defined *)
  let implementation = implement description

  let str_p name = Idl.Param.mk ~name Rpc.Types.string
  let int_p name = Idl.Param.mk ~name Rpc.Types.int
  let search_response_p = Idl.Param.mk ~name:"return" SearchResponse.t 
  let lookup_response_p = Idl.Param.mk ~name:"return" LookupResponse.t 
  let e1 = Idl.DefaultError.err

  let search =
    declare "search" ["Search for books"]
      (str_p "topic" @-> returning search_response_p e1)

  let lookup =
    declare "lookup" ["Find a book by its item_number"]
      (int_p "item_number" @-> returning lookup_response_p e1)
end

