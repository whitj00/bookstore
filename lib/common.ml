open! Core

module SearchRecord = struct
  type t = { title : string; item_number : int } [@@deriving rpcty]
end

module SearchResponse = struct
  type t = SearchRecord.t list [@@deriving rpcty]

  let to_string (t : t) =
    match t with
    | [] -> "No results found\n"
    | results ->
        List.map results ~f:(fun { SearchRecord.title; item_number } ->
            sprintf "%d: %s" item_number title)
        |> String.concat ~sep:"\n"
end

module LookupResponse = struct
  type t = { title : string; topic : string; stock : int; price : float }
  [@@deriving rpcty]

  let to_string t =
    sprintf "Title: %s\nTopic: %s\nRemaining Stock: %d\nPrice: %.2f\n" t.title
      t.topic t.stock t.price
end

module BuyResponse = struct
  type t = int [@@deriving rpcty]

  let to_string t = sprintf "Bought book %d\n" t
end

module BookstoreAPI (R : Idl.RPC) = struct
  open R
  open Idl

  (* We define the description of our API *)
  let description =
    Interface.
      {
        name = "Bookstore";
        namespace = None;
        description = [ "Bookstore Project" ];
        version = (1, 0, 0);
      }

  (* We implement the API using the description we just defined *)
  let implementation = implement description
  let str_p name = Idl.Param.mk ~name Rpc.Types.string
  let int_p name = Idl.Param.mk ~name Rpc.Types.int
  let search_response_p = Idl.Param.mk ~name:"return" SearchResponse.t
  let lookup_response_p = Idl.Param.mk ~name:"return" LookupResponse.t
  let buy_response_p = Idl.Param.mk ~name:"return" BuyResponse.t
  let e = Idl.DefaultError.err

  let search =
    declare "search" [ "Search for books" ]
      (str_p "topic" @-> returning search_response_p e)

  let lookup =
    declare "lookup"
      [ "Find a book by its item_number" ]
      (int_p "item_number" @-> returning lookup_response_p e)

  let buy =
    declare "buy"
      [ "Buy a book by item number" ]
      (int_p "item_number" @-> returning buy_response_p e)
end
