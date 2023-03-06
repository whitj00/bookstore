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

  let create_books_table ~pool =
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

  let create_purchases_table ~pool =
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

  let drop_books_table ~pool =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit) @:- "DROP TABLE IF EXISTS BOOKS;"
    in
    exec_unit_no_args ~pool query

  let drop_purchases_table ~pool =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(unit -->. unit) @:- "DROP TABLE IF EXISTS PURCHASES;"
    in
    exec_unit_no_args ~pool query

  let create_tables ~pool =
    Deferred.List.iter
      [ create_books_table ~pool; create_purchases_table ~pool ]

  let drop_tables ~pool =
    Deferred.List.iter [ drop_books_table ~pool; drop_purchases_table ~pool ]

  let reset_tables ~pool () =
    Deferred.List.iter [ drop_tables ~pool; create_tables ~pool ]
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
    let output_query =
      let open Caqti_request.Infix in
      Caqti_type.(int -->! string)
      @:- "SELECT (CASE WHEN NOT EXISTS (SELECT * FROM books where id = ?1) \
           THEN 'No book found with given item_number' WHEN NOT EXISTS (SELECT \
           * FROM books where id = ?1 and STOCK > 0) THEN 'Out of stock' ELSE \
           '' END) as message"
    in
    let update_query =
      let open Caqti_request.Infix in
      Caqti_type.(int -->! float)
      @:- "UPDATE BOOKS SET STOCK = STOCK - 1 WHERE ID = ? AND STOCK > 0 \
           RETURNING PRICE"
    in
    let insert_query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 int float -->. unit)
      @:- "INSERT INTO purchases (item_number, price) VALUES (?, ?)"
    in

    let query' (module C : Caqti_async.CONNECTION) =
      let open Deferred.Result.Let_syntax in
      C.with_transaction (fun () ->
          let%bind error_message = C.find output_query item_number in
          match String.equal error_message "" with
          | false -> return (false, error_message)
          | true ->
              let%bind price = C.find update_query item_number in
              let%bind rows =
                C.exec_with_affected_count insert_query (item_number, price)
              in
              return
                (match rows with
                | 1 -> (true, "")
                | _ -> (false, "Unknown Error")))
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
      Caqti_type.(tup2 float int -->! bool)
      @:- "UPDATE BOOKS SET PRICE = ? WHERE ID = ? RETURNING id"
    in
    let query' (module C : Caqti_async.CONNECTION) = C.find query (price, id) in
    or_error ~pool query'

  let update_stock ~pool id amount =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 int int -->! bool)
      @:- "UPDATE BOOKS SET STOCK = STOCK + ? WHERE ID = ? RETURNING id"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.find query (amount, id)
    in
    or_error ~pool query'
end
