open Common
open Core
open Async
open Rpc_async
open Cohttp_async

let lookup ~pool item_number =
  let lookup_async =
    let%bind result = Db.lookup_book ~pool item_number in
    match result with
    | Some (title,topic,stock,price) ->
      Ok {LookupResponse.title;topic;stock;price} |> return
    | None -> Error (Idl.DefaultError.InternalError "Not found") |> Deferred.return
  in
  T.put lookup_async

let search ~pool search_query =
  let lookup_async =
    let%bind result = Db.search_book ~pool search_query in
    let records = List.map result ~f:(fun (item_number,title) ->
      {SearchRecord.item_number;title}
    )
    in
    return (Ok records)
  in
  T.put lookup_async
  
let rpc_fn ~pool =
  let module Interface = BookstoreAPI (GenServer ()) in
  Interface.lookup (lookup ~pool);
  Interface.search (search ~pool);
  server Interface.implementation

let serve process_fn ~port =
  let where_to_listen = Tcp.Where_to_listen.of_port port in
  let%bind _ = Server.create ~on_handler_error:`Ignore where_to_listen process_fn in
  Deferred.never ()

let start ~pool ~port () =
  let process ~body _a _r =
    let open Deferred.Let_syntax in
    let%bind request = Body.to_string body >>| Xmlrpc.call_of_string in
    let%bind response = rpc_fn ~pool request >>| Xmlrpc.string_of_response in
    Server.respond_string response ~status:`OK
  in
  serve process ~port



