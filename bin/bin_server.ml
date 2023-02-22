open! Core
open Async
open Bookstore

let start_command ~pool =
  Command.async ~summary:"Start an server"
    (let%map_open.Command port =
       flag "-port"
         (optional_with_default 8000 int)
         ~doc:" Port (Default: 8000)"
     in
     fun () ->
       let () = print_endline "Starting server..." in
       let%bind _ = Server.start ~pool ~port () in
       return ())

let logs_cmd ~pool =
  Command.async ~summary:"Prings a log of purchases"
    (let%map_open.Command () = return () in
     fun () ->
       let%bind purchases = Db.get_purchases ~pool () in
       List.iter purchases
         ~f:(fun (purchase_id, time_created, price, item_number) ->
           printf "%d (%s): Bought %d for $%.2f\n" purchase_id time_created
             item_number price)
       |> return)

let update_price_cmd ~pool =
  Command.async ~summary:"Updates the price of a book"
    (let%map_open.Command id = anon ("id" %: int)
     and price = anon ("price" %: float) in
     fun () ->
       let%map result = Db.update_price ~pool price id in
       match result with
       | true -> print_endline "Price updated"
       | false -> printf "Book %d not found\n" id)

let restock_cmd ~pool =
  Command.async ~summary:"Increases the stock of a book by 5"
    (let%map_open.Command id = anon ("id" %: int) in
      fun () ->
        let%map result = Db.update_stock ~pool id in
        match result with
        | true -> print_endline "Added 5 books to stock"
        | false -> printf "Book %d not found\n" id)
      
      
let commands =
  let pool = Db.create_pool () in
  let subcommands =
    [
      ("start", start_command ~pool);
      ("logs", logs_cmd ~pool);
      ("update", update_price_cmd ~pool);
      ("restock", restock_cmd ~pool);
    ]
  in
  Command.group ~summary:"Database manipulation commands for development"
    subcommands
