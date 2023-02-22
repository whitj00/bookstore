open! Core
open! Async
open! Caqti_async
open! Caqti_driver_sqlite3
let default_url = "sqlite3:////Users/whitjackson/Downloads/bookstore/test.db?create=true"

let exec_unit_no_args ~pool query =
  let call (module C : Caqti_async.CONNECTION) =
    C.exec query ()
  in
  let%bind result = Caqti_async.Pool.use call pool in
  match result with
  | Ok () -> return ()
  | Error e -> Caqti_error.show e |> failwith

let exec_unit_with_args ~pool query args =
  let query' (module C : Caqti_async.CONNECTION) =
    C.exec query args
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok () -> return ()
  | Error e -> Caqti_error.show e |> failwith

let find_one_with_args ~pool query args =
  let query' (module C : Caqti_async.CONNECTION) =
    C.find_opt query args
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith
    
  (* Create an Sqlite Connection pool *)
let create_pool ?(uri) () =
  let uri = Option.value uri ~default:default_url in
  match Caqti_async.connect_pool ~max_size:10 (Uri.of_string uri) with
  | Ok pool -> pool
  | Error err -> failwith (Caqti_error.show err)

let add_row ~pool (id,title,topic,stock,price) =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    (tup2 (tup4 int string string int) float) -->. unit @:-
    "INSERT INTO books (ID,TITLE,TOPIC,STOCK,PRICE) VALUES (?,?,?,?,?)"
  in
  let row = ((id,title,topic,stock),price) in
  exec_unit_with_args ~pool query row
  
let initial_books =
  [(53477, "Achieve Less Bugs and More Hugs in CSCI 339", "distributed systems", 5, 10.00);
   (53573, "Distributed Systems for Dummies", "distributed systems", 5, 10.00);
   (12365, "Surviving College", "college life", 5, 10.00);
   (12498, "Cooking for the Impatient Undergraduate", "college life", 5, 10.00)]

let create_table ~pool () = 
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    unit -->. unit @:-
    "CREATE TABLE BOOKS (
      ID INT PRIMARY KEY NOT NULL,
      TITLE CHAR(100) NOT NULL,
      TOPIC CHAR(50) NOT NULL,
      STOCK INT NOT NULL,
      PRICE FLOAT NOT NULL
    );"  
  in
  let%bind () = exec_unit_no_args ~pool query in
  Deferred.List.iter initial_books ~f:(fun book -> add_row ~pool book)

let drop_table ~pool () = 
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    unit -->. unit @:-
    "DROP TABLE IF EXISTS BOOKS"  
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
    int -->! (tup4 string string int float) @:-
    "SELECT title,topic,stock,price FROM BOOKS WHERE ID = ?"  
  in
  find_one_with_args ~pool query item_number

let search_book ~pool search_query =
  let query =
    let open Caqti_type.Std in
    let open Caqti_request.Infix in
    string -->* (tup2 int string) @:-
    "SELECT id, title FROM BOOKS WHERE topic LIKE ?;"  
  in
  let wrapped_string = ["%";search_query;"%"] |> String.concat in
  let query' (module C : Caqti_async.CONNECTION) =
    C.fold query (fun (id,title) acc -> sprintf "%i: %s" id title :: acc) wrapped_string []
  in
  let%bind result = Caqti_async.Pool.use query' pool in
  match result with
  | Ok x -> return x
  | Error e -> Caqti_error.show e |> failwith
