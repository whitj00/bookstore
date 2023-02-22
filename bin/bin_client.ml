open Core
open Async
open Bookstore

let call_and_print_with_arg fn arg =
  let rpc_fn = Client.create_remote_rpc ~host:"localhost" ~port:8000 in
  let%bind result = fn rpc_fn arg in
  print_endline result |> return 

let lookup_cmd =
  Command.async
    ~summary:"allows an item number to be specified and returns details such as title, cost, subject, and whether or not the item is in stock"
    (let%map_open.Command item_number = anon ("item_number" %: int) in
      fun () -> call_and_print_with_arg Client.get_lookup_result item_number)

let search_cmd =
  Command.async
    ~summary:"specify a topic (or category) and returns all entries belonging to that category"
    (let%map_open.Command topic = anon ("topic" %: string) in
      fun () -> call_and_print_with_arg Client.get_search_result topic)

let commands =
  let subcommands = ["lookup", lookup_cmd; "search", search_cmd] in
  Command.group ~summary:"Make an RPC client call" subcommands
