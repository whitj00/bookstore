open Common
open Rpc_async
open! Core
open Async
open Cohttp
open Cohttp_async
module ClientAPI = BookstoreAPI (GenClient ())

let ( >>>= ) x f = x |> T.get >>= f

module Rpc = struct
  let get_response ~host ~port ~body =
    let%bind response, body =
      Cohttp_async.Client.post ~body (Uri.make ~host ~port ~path:"/" ())
    in
    let code = Response.status response |> Code.code_of_status in
    match code with
    | 200 ->
        let%bind body = Cohttp_async.Body.to_string body in
        return (Ok body)
    | _ -> return (Error (sprintf "HTTP error %d" code))

  let create_remote_rpc ~host ~port =
    let remote_rpc call =
      let call = Xmlrpc.string_of_call call in
      let body = Body.of_string call in
      let%bind response = get_response ~host ~port ~body in
      match response with
      | Error e -> failwith e
      | Ok response_str -> return (Xmlrpc.response_of_string response_str)
    in
    remote_rpc
end

module Main = struct
  let get_result ~to_str rpc_call rpc arg =
    (* If not specified, return an empty response *)
    rpc_call rpc arg >>>= function
    | Ok result -> return (to_str result)
    | Error e ->
        sprintf "RPC call failed: %s" (Util.string_of_default_error e) |> return

  let lookup = get_result ClientAPI.lookup ~to_str:LookupResponse.to_string
  let search = get_result ClientAPI.search ~to_str:SearchResponse.to_string
  let buy = get_result ClientAPI.buy ~to_str:BuyResponse.to_string
end

module Time = struct
  let ignore_success rpc_call rpc arg =
    (* If not specified, return an empty response *)
    rpc_call rpc arg >>>= function
    | Ok _ -> return ()
    | Error e ->
        sprintf "RPC call failed: %s" (Util.string_of_default_error e)
        |> failwith

  let time_n_calls call ~n ~c rpc_fn arg =
    let f _ = ignore_success call rpc_fn arg in
    let start = Time.now () in
    let how = `Max_concurrent_jobs c in
    let%bind _ = Deferred.List.init ~how n ~f in
    let finish = Time.now () in
    Time.diff finish start |> Time.Span.to_string_hum |> return

  let test_lookup = time_n_calls ClientAPI.lookup
  let test_search = time_n_calls ClientAPI.search
  let test_buy = time_n_calls ClientAPI.buy
end

module Repl = struct
  let with_item_number arg ~f =
    match int_of_string_opt arg with
    | None -> print_endline "Invalid item number, must be an int" |> return
    | Some item_number -> f item_number

  let remove_prefix_and_suffix symbol arg  =
    match String.lsplit2 arg ~on:symbol with
    | Some ("", arg) -> (
        match String.rsplit2 arg ~on:symbol with Some (arg, "") -> arg | _ -> arg)
    | _ -> arg

  let remove_quotes_if_exist arg =
    let arg' = remove_prefix_and_suffix '"' arg in
    remove_prefix_and_suffix '\'' arg'

  let eval rpcfn cmd =
    match String.lsplit2 cmd ~on:' ' with
    | None ->
        let () = print_endline "No argument found, please try again" in
        Deferred.unit
    | Some (cmd, arg) -> (
        (* Remote quotation marks around arg, if they exist *)
        let arg = remove_quotes_if_exist arg in
        match cmd with
        | "search" ->
            let%bind result = Main.search rpcfn arg in
            print_endline result |> return
        | "lookup" ->
            with_item_number arg ~f:(fun item_number ->
                let%bind result = Main.lookup rpcfn item_number in
                print_endline result |> return)
        | "buy" ->
            with_item_number arg ~f:(fun item_number ->
                let%bind result = Main.buy rpcfn item_number in
                print_endline result |> return)
        | _ -> print_endline "Unknown command" |> return)

  let rec prompt rpcfn =
    printf "\n> ";
    let stdin = Lazy.force Reader.stdin in
    let%bind line = Reader.read_line stdin in
    match line with
    | `Ok "quit" -> Deferred.unit
    | `Eof ->
        let () = print_endline "No command entered, please try again" in
        prompt rpcfn
    | `Ok line ->
        let%bind () = eval rpcfn line in
        prompt rpcfn

  let print_info () =
    print_endline
      "Welcome to the bookstore! We can support the following commands:\n\
       search <topic> - search for books by topic\n\
       lookup <item_number> - lookup a book by item number\n\
       buy <item_number> - buy a book by item number\n\
       quit - quit the bookstore"

  let start rpcfn =
    print_endline "Starting bookstore client...";
    let () = print_info () in
    prompt rpcfn
end
