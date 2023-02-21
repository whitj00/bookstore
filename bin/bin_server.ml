open! Core
open Async
open Bookstore
let command =
  Command.async
    ~summary:"Start an server"
    (let%map_open.Command port =
      flag
        "-port"
        (optional_with_default 8000 int)
        ~doc:" Port (Default: 8000)"
    in
    fun () -> let%bind _ = 
      Server.start ~port () in
      return ())
