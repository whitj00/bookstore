open Core
open Async
open Cohttp
open Cohttp_async
open Common
open Rpc_async
module ClientAPI = BookstoreAPI (GenClient ())

module Rpc = struct
  let get_remote_response ~host ~port ~body =
    let%bind response, body =
      Cohttp_async.Client.post ~body (Uri.make ~host ~port ~path:"/" ())
    in
    let code = Response.status response |> Code.code_of_status in
    match code with
    | 200 ->
        let%bind body = Cohttp_async.Body.to_string body in
        return (Ok body)
    | _ -> return (Error (sprintf "HTTP error %d" code))

  (* This creates a function that takes in an Rpc.call, calls the remote server,
     and returns the Rpc.Response. This function is necessary because it
     implements the _transport_ mechanism for the rpc. Our client bindings take
     this function as an argument. *)
  let create_remote_rpc ~host ~port =
    let remote_rpc call =
      let call = Xmlrpc.string_of_call call in
      let body = Body.of_string call in
      let%bind response = get_remote_response ~host ~port ~body in
      match response with
      | Error e -> failwith e
      | Ok response_str -> return (Xmlrpc.response_of_string response_str)
    in
    remote_rpc
end

module Main = struct
  let get_result ~to_str rpc_call rpc arg =
    let%bind response = rpc_call rpc arg |> T.get in
    (match response with
    | Ok result -> to_str result
    | Error e -> sprintf "RPC call failed: %s" (Util.string_of_default_error e))
    |> return

  let lookup = get_result ClientAPI.lookup ~to_str:LookupResponse.to_string
  let search = get_result ClientAPI.search ~to_str:SearchResponse.to_string
  let buy = get_result ClientAPI.buy ~to_str:BuyResponse.to_string
end

module Time = struct
  (* Fails on error, ignores the results of successes *)
  let get_result' rpc_call (rpc : T.rpcfn) arg =
    let%bind response = rpc_call rpc arg |> T.get in
    (match response with
    | Ok _ -> ()
    | Error e ->
        sprintf "RPC call failed: %s" (Util.string_of_default_error e)
        |> failwith)
    |> return

  (* Calls the given rpc call n times, with c concurrent calls *)
  let time_n_calls call ~n ~c rpc_fn arg =
    let f _ = get_result' call rpc_fn arg in
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
  let with_int_arg arg ~f =
    match int_of_string_opt arg with
    | None -> print_endline "Invalid argument, must be an int" |> return
    | Some item_number -> f item_number

  (* This function takes a character and a string. If the string is surrounded
     by the character, this function will return the inner string *)
  let remove_prefix_and_suffix on str =
    match String.lsplit2 str ~on with
    | Some ("", str) -> (
        match String.rsplit2 str ~on with Some (str, "") -> str | _ -> str)
    | _ -> str

  (* Returns the argument, with surrounding single and double quotes removed *)
  let remove_quotes_if_exist arg =
    let arg' = remove_prefix_and_suffix '"' arg in
    remove_prefix_and_suffix '\'' arg'

  (* Evaluates a single command entered to the repl *)
  let eval rpcfn cmd =
    (* Split the command on the first argument *)
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
            with_int_arg arg ~f:(fun item_number ->
                let%bind result = Main.lookup rpcfn item_number in
                print_endline result |> return)
        | "buy" ->
            with_int_arg arg ~f:(fun item_number ->
                let%bind result = Main.buy rpcfn item_number in
                print_endline result |> return)
        | _ -> print_endline "Unknown command" |> return)

  let print_info () =
    print_endline
      "Welcome to the bookstore! We can support the following commands:\n\
       search <topic> - search for books by topic\n\
       lookup <item_number> - lookup a book by item number\n\
       buy <item_number> - buy a book by item number\n\
       help - print this prompt\n\
       quit - quit the bookstore"

  (* Simple recursive prompt loop, parameterized by our transport function *)
  let rec prompt rpcfn =
    printf "\n> ";
    let stdin = Lazy.force Reader.stdin in
    let%bind line = Reader.read_line stdin in
    match line with
    | `Eof ->
        let () = print_endline "No command entered, please try again" in
        prompt rpcfn
    | `Ok command -> (
        let command' = String.strip command in
        match command' with
        | "quit" -> Deferred.unit
        | "help" ->
            let () = print_info () in
            prompt rpcfn
        | _ ->
            let%bind () = eval rpcfn command' in
            prompt rpcfn)

  let start ~host ~port =
    let rpcfn = Rpc.create_remote_rpc ~host ~port in
    let () = print_info () in
    let%bind () = prompt rpcfn in
    prompt rpcfn
end
