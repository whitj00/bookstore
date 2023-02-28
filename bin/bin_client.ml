open Core
open Async
open Bookstore
open Common

let call_rpc_and_print ~host ~port fn arg =
  let rpc_fn = Client.Rpc.create_remote_rpc ~host ~port in
  let%bind result = fn rpc_fn arg in
  print_endline result |> return

module Main = struct
  let create_cmd ~arg_name ~arg_type ~summary f =
    Command.async ~summary
      (let%map_open.Command arg =
         flag (sprintf "-%s" arg_name) (required arg_type) ~doc:""
       and host = host_flag
       and port = port_flag in
       fun () -> call_rpc_and_print ~host ~port f arg)

  let lookup_cmd =
    create_cmd ~arg_name:"item-number" ~arg_type:int
      ~summary:
        "allows an item number to be specified and returns details such as \
         title, cost, subject, and whether or not the item is in stock"
      Client.Main.lookup

  let search_cmd =
    create_cmd ~arg_name:"topic" ~arg_type:string
      ~summary:
        "specify a topic (or category) and returns all entries belonging to \
         that category"
      Client.Main.search

  let buy_cmd =
    create_cmd ~arg_name:"item-number" ~arg_type:int
      ~summary:"Buys an item from the bookstore" Client.Main.buy
end

module Time = struct
  (* All of our time functions call an API with one parameter, n calls, a
     maximum concurrency, and a host and a port. This helper function creates a
     CLI command to time a specific function in [Client.Time] *)
  let create_time_cmd method_name arg_name arg_type f =
    let arg_flag = sprintf "-%s" arg_name in
    let summary = sprintf "Time the %s command" method_name in
    let command =
      Command.async ~summary
        (let%map_open.Command arg = flag arg_flag (required arg_type) ~doc:""
         and host = host_flag
         and port = port_flag
         and n =
           flag "-n" (required int)
             ~doc:"count Number of times to call the function"
         and c =
           flag "-c"
             (optional_with_default 50 int)
             ~doc:"max Maximum concurrent calls (default = 50)"
         in
         fun () -> call_rpc_and_print ~host ~port (f ~n ~c) arg)
    in
    (method_name, command)

  let time_lookup =
    create_time_cmd "lookup" "item-number" int Client.Time.test_lookup

  let time_search =
    create_time_cmd "search" "topic" string Client.Time.test_search

  let time_buy = create_time_cmd "buy" "item-number" int Client.Time.test_buy

  let commands =
    Command.group
      [ time_lookup; time_search; time_buy ]
      ~summary:"Time RPC calls"
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
