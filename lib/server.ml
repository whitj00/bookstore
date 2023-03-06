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
        Error (Idl.DefaultError.InternalError "Book not found")
        |> Deferred.return
  in
  T.lift get_lookup_result

let search_impl ~pool =
  let get_search_result search_query =
    let%bind result = Db.Client.search_book ~pool search_query in
    (* Turn a record tuple into a SearchRecord.t *)
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
    match success with
    | true -> Ok () |> return
    | false -> Error (Idl.DefaultError.InternalError message) |> return
  in
  T.lift get_buy_result

(* Implements the RPC server bindings from our definition *)
let create_rpc_handler ~pool =
  let module Interface = BookstoreAPI (GenServer ()) in
  (* Attach implementations to server bindings *)
  Interface.lookup (lookup_impl ~pool);
  Interface.search (search_impl ~pool);
  Interface.buy (buy_impl ~pool);
  server Interface.implementation

(* This function is called by the server to handle each new connection. The
   function converts the body of the request to an Rpc.call, calls the
   rpc_handler, and responds with the result. *)
let create_request_handler ~pool =
  let rpc_handler = create_rpc_handler ~pool in
  let request_handler ~body _ _ =
    let%bind request = Body.to_string body >>| Xmlrpc.call_of_string in
    let%bind response = rpc_handler request >>| Xmlrpc.string_of_response in
    Server.respond_string response ~status:`OK
  in
  request_handler

let create_server ~pool port =
  let request_handler = create_request_handler ~pool in
  let%bind _ =
    Server.create ~on_handler_error:`Raise
      (Tcp.Where_to_listen.of_port port)
      request_handler
  in
  return ()

let start ~pool ~port () = create_server ~pool port |> Deferred.ignore_m
