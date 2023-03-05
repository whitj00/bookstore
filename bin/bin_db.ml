open! Core
open Async
open Bookstore
open Common

let build_basic_cmd ~summary cmd =
  Command.async ~summary
    (let%map_open.Command uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let%bind _ = cmd ~pool () in
       Deferred.unit)

let create_cmd =
  build_basic_cmd ~summary:"creates the books and purchases tables"
    Db.Util.create_tables

let drop_cmd =
  build_basic_cmd ~summary:"drops the books and purchases tables"
    Db.Util.drop_tables

let reset_cmd =
  build_basic_cmd ~summary:"resets our books and purchases tables"
    Db.Util.reset_tables

let insert_cmd =
  Command.async ~summary:"adds a row to our books table"
    (let%map_open.Command id = anon ("id" %: int)
     and title = anon ("title" %: string)
     and topic = anon ("topic" %: string)
     and stock = anon ("stock" %: int)
     and price = anon ("price" %: float)
     and uri = db_flag in
     fun () ->
       let pool = Db.Connection_pool.create ~uri in
       let%bind _ = Db.Util.add_row ~pool (id, title, topic, stock, price) in
       Deferred.unit)

let db_commands =
  let subcommands =
    [
      ("create", create_cmd);
      ("drop", drop_cmd);
      ("reset", reset_cmd);
      ("insert", insert_cmd);
    ]
  in
  Command.group ~summary:"Database manipulation commands for development"
    subcommands
