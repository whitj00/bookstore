open Bookstore
open Rpc_async
open Core
open Async

let demo () =
  let%bind _ = Client.get_lookup_result Client.demo_rpc 1 in
  Deferred.unit

let client () =
  let rpc_fn = Client.create_remote_rpc ~host:"localhost" ~port:8000 in
  let%bind result = Client.get_lookup_result rpc_fn 1 in
  print_endline result |> return
  
let demo_command =
  Command.async
    ~summary:"Use Genservers"
    (let%map_open.Command () = return () in
    fun () -> demo ())

let client_command =
  Command.async
    ~summary:"Use Genservers"
    (let%map_open.Command () = return () in
    fun () -> client ())
    
let server_command =
  Command.async
    ~summary:"Start an server"
    (let%map_open.Command port =
      flag
        "-port"
        (optional_with_default 8000 int)
        ~doc:" Port (Default: 8000)"
    in
    fun () -> let%bind _ = 
      Server.start ~port () in
      return ())

let () =
  let commands = ["demo", demo_command; "server", server_command; "client", client_command] in
  Command.group ~summary:"Run an RPC server or client" commands |> Command_unix.run
