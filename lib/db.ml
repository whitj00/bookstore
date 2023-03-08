open! Core
open! Async
open! Caqti_async
open! Caqti_driver_sqlite3

(* caqti only natively supports up to 4 parameters, but this is a cleaner way to
   form a 5 tuple *)
let tup5 p1 p2 p3 p4 p5 = Caqti_type.(tup2 (tup4 p1 p2 p3 p4) p5)
let caqti_fail e = failwith (Caqti_error.show e)

module Connection_pool = struct
  type t = ((module Caqti_async.CONNECTION), Caqti_error.t) Caqti_async.Pool.t

  let create ~uri =
    (* Sqlite3 driver does not support connection pooling so max_size will be
       ignored. However, this should work (untested) for Caqti drivers that
       support pooling, such as postgres *)
    match Caqti_async.connect_pool ~max_size:20 (Uri.of_string uri) with
    | Ok pool -> pool
    | Error e -> caqti_fail e
end

let or_error ~(pool : Connection_pool.t) query =
  let%bind result = Caqti_async.Pool.use query pool in
  match result with Ok x -> return x | Error e -> caqti_fail e

let at_least_one_result ~(pool : Connection_pool.t) query =
  let%bind result = Caqti_async.Pool.use query pool in
  match result with
  | Ok 0 -> return false
  | Error e -> caqti_fail e
  | Ok _ -> return true

(* Executes a query that takes in no arguments *)
let exec_unit_no_args ~pool query =
  let query' (module C : Caqti_async.CONNECTION) = C.exec query () in
  or_error query' ~pool

module Util = struct
  let initial_books =
    [
      ( 53477,
        "Achieve Less Bugs and More Hugs in CSCI 339",
        "distributed systems",
        5,
        10.00 );
      (53573, "Distributed Systems for Dummies", "distributed systems", 5, 10.00);
      (12365, "Surviving College", "college life", 5, 10.00);
      ( 12498,
        "Cooking for the Impatient Undergraduate",
        "college life",
        5,
        10.00 );
    ]

  (* This function adds a row to our books table *)
  let add_row ~pool (id, title, topic, stock, price) =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(tup5 int string string int float -->. unit)
      @:- "INSERT INTO books (ID,TITLE,TOPIC,STOCK,PRICE) VALUES (?,?,?,?,?)"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.exec query ((id, title, topic, stock), price)
    in
    or_error query' ~pool

  let create_books_table ~pool () =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit)
      @:- "CREATE TABLE BOOKS (\n\
          \      ID INT PRIMARY KEY NOT NULL,\n\
          \      TITLE CHAR(100) NOT NULL,\n\
          \      TOPIC CHAR(50) NOT NULL,\n\
          \      STOCK INT NOT NULL,\n\
          \      PRICE FLOAT NOT NULL\n\
          \    );"
    in
    let%bind () = exec_unit_no_args ~pool query in
    Deferred.List.iter initial_books ~f:(fun book -> add_row ~pool book)

  let create_purchases_table ~pool () =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit)
      @:- "CREATE TABLE PURCHASES (\n\
          \      purchase_id INTEGER PRIMARY KEY AUTOINCREMENT,\n\
          \      time_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,\n\
          \      price FLOAT,\n\
          \      item_number INTEGER\n\
          \    );"
    in
    exec_unit_no_args ~pool query

  let drop_books_table ~pool () =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit) @:- "DROP TABLE IF EXISTS BOOKS;"
    in
    exec_unit_no_args ~pool query

  let drop_purchases_table ~pool () =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit) @:- "DROP TABLE IF EXISTS PURCHASES;"
    in
    exec_unit_no_args ~pool query

  let create_tables ~pool () =
    let%bind () = create_books_table ~pool () in
    let%bind () = create_purchases_table ~pool () in
    return ()

  let drop_tables ~pool () =
    let%bind () = drop_books_table ~pool () in
    let%bind () = drop_purchases_table ~pool () in
    return ()

  let reset_tables ~pool () =
    let%bind () = drop_tables ~pool () in
    let%bind () = create_tables ~pool () in
    return ()
end

module Client = struct
  let lookup_book ~pool item_number =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(int -->! tup4 string string int float)
      @:- "SELECT title,topic,stock,price FROM BOOKS WHERE ID = ?"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.find_opt query item_number
    in
    or_error ~pool query'

  let search_book ~pool search_query =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(string -->* tup2 int string)
      @:- "SELECT id, title FROM BOOKS WHERE topic LIKE ?;"
    in
    let wrapped_string = [ "%"; search_query; "%" ] |> String.concat in
    let query' (module C : Caqti_async.CONNECTION) =
      C.fold query (fun a acc -> a :: acc) wrapped_string []
    in
    or_error ~pool query'

  let buy_book ~pool item_number =
    let price_stock_query =
      let open Caqti_request.Infix in
      Caqti_type.(int -->! tup2 float int)
      @:- "SELECT PRICE, STOCK FROM BOOKS WHERE ID = ?"
    in
    let update_query =
      let open Caqti_request.Infix in
      Caqti_type.(int -->. unit)
      @:- "UPDATE BOOKS SET STOCK = STOCK - 1 WHERE ID = ? AND STOCK > 0"
    in
    let insert_log_query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 int float -->. unit)
      @:- "INSERT INTO purchases (item_number, price) VALUES (?, ?)"
    in

    let query' (module C : Caqti_async.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      C.with_transaction (fun () ->
          let%bind find_result = C.find_opt price_stock_query item_number in
          match find_result with
          | None -> return (false, "No book found with given item_number")
          | Some (_, 0) -> return (false, "Out of stock")
          | Some (price, _) ->
              let%bind () = C.exec update_query item_number in
              let%bind () = C.exec insert_log_query (item_number, price) in
              return (true, ""))
    in
    or_error ~pool query'
end

module Server = struct
  let get_purchases ~pool () =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->* tup4 int string float int)
      @:- "SELECT purchase_id, time_created, price, item_number FROM PURCHASES \
           ORDER BY time_created DESC;"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.fold query (fun a acc -> a :: acc) () []
    in
    or_error ~pool query'

  let update_price ~pool price id =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 float int -->. unit)
      @:- "UPDATE BOOKS SET PRICE = ? WHERE ID = ?"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.exec_with_affected_count query (price, id)
    in
    at_least_one_result ~pool query'

  let update_stock ~pool id amount =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 int int -->. unit)
      @:- "UPDATE BOOKS SET STOCK = STOCK + ? WHERE ID = ?"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.exec_with_affected_count query (amount, id)
    in
    at_least_one_result ~pool query'
end
