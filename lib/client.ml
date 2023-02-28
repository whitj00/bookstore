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
