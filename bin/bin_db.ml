open! Core
open Async
open Bookstore

let create_cmd ~pool =
  Command.async ~summary:"creates a books table"
    (let%map_open.Command () = return () in
     fun () ->
       let%bind _ = Db.Util.create_tables ~pool () in
       Deferred.unit)

let drop_cmd ~pool =
  Command.async ~summary:"drops our books table"
    (let%map_open.Command () = return () in
     fun () ->
       let%bind _ = Db.Util.drop_tables ~pool () in
       Deferred.unit)

let reset_cmd ~pool =
  Command.async ~summary:"resets our books table"
    (let%map_open.Command () = return () in
     fun () ->
       let%bind _ = Db.Util.reset_tables ~pool () in
       Deferred.unit)

let insert_cmd ~pool =
  Command.async ~summary:"adds a row to our books table"
    (let%map_open.Command id = anon ("id" %: int)
     and title = anon ("title" %: string)
     and topic = anon ("topic" %: string)
     and stock = anon ("stock" %: int)
     and price = anon ("price" %: float) in
     fun () ->
       let%bind _ = Db.Util.add_row ~pool (id, title, topic, stock, price) in
       Deferred.unit)

let db_commands =
  let pool = Db.Connection_pool.create () in
  let subcommands =
    [
      ("create", create_cmd ~pool);
      ("drop", drop_cmd ~pool);
      ("reset", reset_cmd ~pool);
      ("insert", insert_cmd ~pool);
    ]
  in
  Command.group ~summary:"Database manipulation commands for development"
    subcommands
