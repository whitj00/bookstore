open Core
open Async

let () =
  let commands =
    [
      ("server", Bin_server.commands);
      ("client", Bin_client.commands);
      ("db", Bin_db.db_commands);
    ]
  in
  Command.group ~summary:"Run an RPC server or client" commands
  |> Command_unix.run
