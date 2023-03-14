open! Core
open Async

(* This is used in bin_server and bin_db to configure the database path *)
let db_flag =
  let default =
    [ "sqlite3:///"; Core_unix.getcwd (); "/test.db?create=true" ]
    |> String.concat
  in
  Command.Param.(
    flag "-db"
      (optional_with_default default string)
      ~doc:"db_uri Sqlite path of database")

(* These two functions used in bin_server and bin_client to configure
   sending/receiving connections *)
let host_flag =
  Command.Param.(
    flag "-host"
      (optional_with_default "localhost" string)
      ~doc:"host Host of target rpc server (default localhost)")

let port_flag =
  Command.Param.(
    flag "-port"
      (optional_with_default 8000 int)
      ~doc:"port Port of target rpc server (default 8000)")

let string = Command.Param.string
let int = Command.Param.int
