open Common
open Async
open Rpc_async
open Cohttp_async

let rpc_fn =
  let module Interface = BookstoreAPI(GenServer ()) in
  Interface.lookup (fun x -> Rpc_async.ErrM.return (Int.to_string x));
  Interface.search (fun _ -> Rpc_async.ErrM.return ["found"]);
  server Interface.implementation

let serve process_fn ~port =
  let where_to_listen = Tcp.Where_to_listen.of_port port in
  let%bind _ = Server.create ~on_handler_error:`Ignore where_to_listen process_fn in
  Deferred.never ()

let start ~port () =
  let process ~body _a _r =
    let open Deferred.Let_syntax in
    let%bind request = Body.to_string body >>| Xmlrpc.call_of_string in
    let%bind response = rpc_fn request >>| Xmlrpc.string_of_response in
    Server.respond_string response ~status:`OK
  in
  serve process ~port

