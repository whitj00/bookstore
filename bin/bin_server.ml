open! Core
open Async
open Bookstore
open Common

let daemonize =
  Daemon.daemonize ~redirect_stdout:`Do_not_redirect ~cd:(Core_unix.getcwd ())

let start_cmd =
  Command.async ~summary:"Start an server"
    (let%map_open.Command port = port_flag
     and daemon = flag "-daemon" no_arg ~doc:"run as daemon"
     and uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let () = print_endline "Starting server..." in
       let%bind _ = Server.start ~pool ~port () in
       let () = if daemon then daemonize () in
       Deferred.never ())

let logs_cmd =
  Command.async ~summary:"Prings a log of purchases"
    (let%map_open.Command uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let%bind purchases = Db.Server.get_purchases ~pool () in
       List.iter purchases
         ~f:(fun (purchase_id, time_created, price, item_number) ->
           printf "%d (%s): Bought %d for $%.2f\n" purchase_id time_created
             item_number price)
       |> return)

let update_price_cmd =
  Command.async ~summary:"Updates the price of a book"
    (let%map_open.Command id =
       flag "-item-number" (required int) ~doc:"item Item number"
     and price = flag "-price" (required float) ~doc:"price New price"
     and uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let%map result = Db.Server.update_price ~pool price id in
       match result with
       | true -> print_endline "Price updated"
       | false -> printf "Book %d not found\n" id)

let restock_cmd =
  Command.async ~summary:"Increases the stock of a book"
    (let%map_open.Command id =
       flag "-item-number" (required int) ~doc:"item Item number"
     and n =
       flag "-n"
         (optional_with_default 5 int)
         ~doc:"count Number of items to add (default = 5)"
     and uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let%map result = Db.Server.update_stock ~pool id n in
       match result with
       | true -> print_endline (sprintf "Added %d books to stock" n)
       | false -> printf "Book %d not found\n" id)

let commands =
  let subcommands =
    [
      ("start", start_cmd);
      ("logs", logs_cmd);
      ("update", update_price_cmd);
      ("restock", restock_cmd);
    ]
  in
  Command.group subcommands ~summary:"Run and manage a server"
