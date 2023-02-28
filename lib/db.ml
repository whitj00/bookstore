open! Core
open! Async
open! Caqti_async
open! Caqti_driver_sqlite3

let tup5 p1 p2 p3 p4 p5 = Caqti_type.(tup2 (tup4 p1 p2 p3 p4) p5)

module Connection_pool = struct
  type t = ((module Caqti_async.CONNECTION), Caqti_error.t) Caqti_async.Pool.t

  let default =
    [ "sqlite3:///"; Core_unix.getcwd (); "/test.db?create=true" ]
    |> String.concat

  let create ?uri () =
    let uri = Option.value uri ~default in
    match Caqti_async.connect_pool ~max_size:20 (Uri.of_string uri) with
    | Ok pool -> pool
    | Error err -> failwith (Caqti_error.show err)
end

let or_error ~(pool : Connection_pool.t) query =
  let%bind result = Caqti_async.Pool.use query pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith

let some_or_error ~pool query =
  let%bind result = Caqti_async.Pool.use query pool in
  match result with
  | Ok x -> Option.is_some x |> return
  | Error e -> Caqti_error.show e |> failwith

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
    let output_query =
      let open Caqti_request.Infix in
      Caqti_type.(tup3 int int int -->! tup2 bool string)
      @:- "SELECT (CASE WHEN EXISTS (SELECT * FROM books where id = ? and \
           stock >= 1) THEN true ELSE false END) as success, (CASE WHEN NOT \
           EXISTS (SELECT * FROM books where id = ?) THEN 'No book found with \
           given item_number' WHEN NOT EXISTS (SELECT * FROM books where id = \
           ? and STOCK > 0) THEN 'Out of stock' ELSE 'Purchase Successful' \
           END) as message"
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
      C.with_transaction (fun () ->
          let%bind.Deferred.Result success, message =
            C.find output_query (item_number, item_number, item_number)
          in
          match success with
          | false -> return (Ok (success, message))
          | true ->
              let%bind.Deferred.Result price =
                C.find update_query item_number
              in
              let%bind.Deferred.Result () =
                C.exec insert_query (item_number, price)
              in
              return (Ok (success, message)))
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
    let query' (module C : Caqti_async.CONNECTION) =
      C.find_opt query (price, id)
    in
    some_or_error ~pool query'

  let update_stock ~pool id amount =
    let query =
      let open Caqti_request.Infix in
      Caqti_type.(tup2 int int -->! bool)
      @:- "UPDATE BOOKS SET STOCK = STOCK + ? WHERE ID = ? RETURNING id"
    in
    let query' (module C : Caqti_async.CONNECTION) =
      C.find_opt query (amount, id)
    in
    some_or_error ~pool query'
end
