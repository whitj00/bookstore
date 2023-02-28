open Common
open Core
open Async
open Rpc_async
open Cohttp_async

let lookup_impl ~pool =
  let get_lookup_result item_number =
    let%bind result = Db.Client.lookup_book ~pool item_number in
    match result with
    | Some (title, topic, stock, price) ->
        Ok { LookupResponse.title; topic; stock; price } |> return
    | None ->
        Error (Idl.DefaultError.InternalError "Not found") |> Deferred.return
  in
  T.lift get_lookup_result

let search_impl ~pool =
  let get_search_result search_query =
    let%bind result = Db.Client.search_book ~pool search_query in
    let records =
      List.map result ~f:(fun (item_number, title) ->
          { SearchRecord.item_number; title })
    in
    return (Ok records)
  in
  T.lift get_search_result

let buy_impl ~pool =
  let get_buy_result item_number =
    let%bind success, message = Db.Client.buy_book ~pool item_number in
    return (Ok { BuyResponse.success; message })
  in
  T.lift get_buy_result

(* Implement RPC Server From our Definition *)
let create_rpc ~pool =
  let module Interface = BookstoreAPI (GenServer ()) in
  Interface.lookup (lookup_impl ~pool);
  Interface.search (search_impl ~pool);
  Interface.buy (buy_impl ~pool);
  server Interface.implementation

let create_request_handler ~pool =
  let rpc = create_rpc ~pool in
  let request_handler ~body _ _ =
    let%bind request = Body.to_string body >>| Xmlrpc.call_of_string in
    let%bind response = rpc request >>| Xmlrpc.string_of_response in
    Server.respond_string response ~status:`OK
  in
  request_handler

let create_server ~pool port =
  let request_handler = create_request_handler ~pool in
  let%bind _ =
    Server.create ~on_handler_error:`Ignore
      (Tcp.Where_to_listen.of_port port)
      request_handler
  in
  return ()

let start ~pool ~port () =
  let%bind () = create_server ~pool port in
  Deferred.never ()
