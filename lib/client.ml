open Common
open Rpc_async
open! Core
open Async
open Cohttp
open Cohttp_async
include BookstoreAPI (GenClient ())

let ( >>>= ) x f = x |> T.get >>= f

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

let remote_rpc ~host ~port rpc =
  let call = Xmlrpc.string_of_call rpc in
  let body = Body.of_string call in
  let%bind response = get_response ~host ~port ~body in
  match response with
  | Error e -> failwith e
  | Ok response_str -> return (Xmlrpc.response_of_string response_str)

let create_remote_rpc ~host ~port = remote_rpc ~host ~port
let with_result rpc_call rpc arg ~f = rpc_call rpc arg >>>= f

let get_result ?(to_str = fun _ -> "") ?(fail_on_error = false) =
  with_result ~f:(function
    | Ok result -> return (to_str result)
    | Error e -> (
        sprintf "RPC call failed: %s" (Util.string_of_default_error e)
        |> match fail_on_error with true -> failwith | false -> return))

module Main = struct
  let lookup = get_result lookup ~to_str:LookupResponse.to_string
  let search = get_result search ~to_str:SearchResponse.to_string
  let buy = get_result buy ~to_str:BuyResponse.to_string
end

module Time = struct
  let time_n_calls_to_get_result rpc_fn arg ~call ~n =
    let f _ = arg |> (get_result call) rpc_fn in
    let start = Time.now () in
    let%bind _ = Deferred.List.init n ~f in
    let finish = Time.now () in
    Time.diff finish start |> Time.Span.to_string_hum |> return

  let lookup = time_n_calls_to_get_result ~call:lookup
  let search = time_n_calls_to_get_result ~call:search
  let buy = time_n_calls_to_get_result ~call:buy
end
