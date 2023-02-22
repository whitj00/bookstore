open! Core
open! Async
open! Caqti_async
open! Caqti_driver_sqlite3

let default_url =
  "sqlite3:////Users/whitjackson/Downloads/bookstore/test.db?create=true"

let exec_unit_no_args ~pool query =
  let call (module C : Caqti_async.CONNECTION) = C.exec query () in
  let%bind result = Caqti_async.Pool.use call pool in
  match result with
  | Ok () -> return ()
  | Error e -> Caqti_error.show e |> failwith

let create_pool ?uri () =
  let uri = Option.value uri ~default:default_url in
  match Caqti_async.connect_pool ~max_size:10 (Uri.of_string uri) with
  | Ok pool -> pool
  | Error err -> failwith (Caqti_error.show err)

let add_row ~pool (id, title, topic, stock, price) =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (tup2 (tup4 int string string int) float -->. unit)
    @:- "INSERT INTO books (ID,TITLE,TOPIC,STOCK,PRICE) VALUES (?,?,?,?,?)"
  in
  let query' (module C : Caqti_async.CONNECTION) =
    C.exec query ((id, title, topic, stock), price)
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok () -> return ()
  | Error e -> Caqti_error.show e |> failwith

let initial_books =
  [
    ( 53477,
      "Achieve Less Bugs and More Hugs in CSCI 339",
      "distributed systems",
      5,
      10.00 );
    (53573, "Distributed Systems for Dummies", "distributed systems", 5, 10.00);
    (12365, "Surviving College", "college life", 5, 10.00);
    (12498, "Cooking for the Impatient Undergraduate", "college life", 5, 10.00);
  ]

let create_table ~pool () =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (unit -->. unit)
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

let drop_table ~pool () =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (unit -->. unit) @:- "DROP TABLE IF EXISTS BOOKS"
  in
  exec_unit_no_args ~pool query

let reset_table ~pool () =
  let%bind () = drop_table ~pool () in
  let%bind () = create_table ~pool () in
  return ()

let lookup_book ~pool item_number =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (int -->! tup4 string string int float)
    @:- "SELECT title,topic,stock,price FROM BOOKS WHERE ID = ?"
  in
  let query' (module C : Caqti_async.CONNECTION) =
    C.find_opt query item_number
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith

let search_book ~pool search_query =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (string -->* tup2 int string)
    @:- "SELECT id, title FROM BOOKS WHERE topic LIKE ?;"
  in
  let wrapped_string = [ "%"; search_query; "%" ] |> String.concat in
  let query' (module C : Caqti_async.CONNECTION) =
    C.fold query (fun a acc -> a :: acc) wrapped_string []
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith

let buy_book ~pool item_number =
  let output_query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (tup3 int int int -->! tup2 bool string)
    @:- "SELECT ( CASE\n\
        \    WHEN EXISTS (SELECT *\n\
        \                 FROM   books\n\
        \                 WHERE  id = ?\n\
        \                        AND stock >= 1) THEN true\n\
        \    ELSE false\n\
        \  END ) AS success,\n\
         ( CASE\n\
        \    WHEN NOT EXISTS (SELECT *\n\
        \                     FROM   books\n\
        \                     WHERE  id = ?) THEN\n\
        \    'No book found with given item_number'\n\
        \    WHEN NOT EXISTS (SELECT *\n\
        \                     FROM   books\n\
        \                     WHERE  id = ?\n\
        \                            AND stock > 0) THEN 'Out of stock'\n"
  in
  let update_query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (int -->. unit)
    @:- "UPDATE BOOKS SET STOCK = STOCK - 1 WHERE ID = ? AND STOCK > 0"
  in
  let query' (module C : Caqti_async.CONNECTION) =
    C.with_transaction (fun () ->
        let%bind.Deferred.Result success, message =
          C.find output_query (item_number, item_number, item_number)
        in
        match success with
        | false -> return (Ok (success, message))
        | true ->
            let%bind.Deferred.Result () = C.exec update_query item_number in
            return (Ok (success, message)))
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith
