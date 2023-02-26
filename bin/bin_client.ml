open Core
open Async
open Bookstore

let call_and_print_with_arg fn arg ~host ~port =
  let rpc_fn = Client.create_remote_rpc ~host ~port in
  let%bind result = fn rpc_fn arg in
  print_endline result |> return

module Main = struct
  let create_cmd ~arg_name ~arg_type ~summary f =
    let arg_flag = sprintf "-%s" arg_name in
    Command.async ~summary
      (let%map_open.Command arg = flag arg_flag (required arg_type) ~doc:""
       and host =
         flag "-host"
           (optional_with_default "localhost" string)
           ~doc:" Host of target rpc server (default localhost)"
       and port =
         flag "-port"
           (optional_with_default 8000 int)
           ~doc:" Port of target rpc server (default 8000)"
       in
       fun () -> call_and_print_with_arg ~host ~port f arg)

  let lookup_cmd =
    create_cmd ~arg_name:"item-number" ~arg_type:Command.Param.int
      ~summary:
        "allows an item number to be specified and returns details such as \
         title, cost, subject, and whether or not the item is in stock"
      Client.Main.lookup

  let search_cmd =
    create_cmd ~arg_name:"topic" ~arg_type:Command.Param.string
      ~summary:
        "specify a topic (or category) and returns all entries belonging to \
         that category"
         Client.Main.search

  let buy_cmd =
    create_cmd ~arg_name:"item-number" ~arg_type:Command.Param.int
      ~summary:"Buys an item from the bookstore"       Client.Main.buy
end

module Time = struct
  let create_time_cmd ~arg_name ~arg_type ~summary
      (f : Rpc_async.T.rpcfn -> 'a -> n:int -> string Deferred.t) =
    let arg_flag = sprintf "-%s" arg_name in
    Command.async ~summary
      (let%map_open.Command arg = flag arg_flag (required arg_type) ~doc:""
       and n =
         flag "-n" (required int) ~doc:"Number of times to call the function"
       and host =
         flag "-host"
           (optional_with_default "localhost" string)
           ~doc:" Host of target rpc server (default localhost)"
       and port =
         flag "-port"
           (optional_with_default 8000 int)
           ~doc:" Port of target rpc server (default 8000)"
       in
       fun () -> call_and_print_with_arg ~host ~port (f ~n) arg)

  let lookup =
    create_time_cmd ~arg_name:"item-number" ~arg_type:Command.Param.int
      ~summary:"Time the lookup command" Client.Time.lookup

  let search =
    create_time_cmd ~arg_name:"topic" ~arg_type:Command.Param.string
      ~summary:"Time the search command" Client.Time.search

  let buy =
    create_time_cmd ~arg_name:"item-number" ~arg_type:Command.Param.int
      ~summary:"Time the buy command" Client.Time.buy

  let commands =
    [ ("lookup", lookup); ("search", search); ("buy", buy) ]
    |> Command.group ~summary:"Time RPC calls"
end

let commands =
  let subcommands =
    [
      ("lookup", Main.lookup_cmd);
      ("search", Main.search_cmd);
      ("buy", Main.buy_cmd);
      ("time", Time.commands);
    ]
  in
  Command.group ~summary:"Make an RPC client call" subcommands
