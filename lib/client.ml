open Common
open Rpc_async
open! Core
open Async
open Cohttp
open Cohttp_async

include BookstoreAPI(GenClient ())

let ( >>>= ) x f = x |> T.get >>= f

let get_response ~host ~port ~body =
  let%bind response,body = Cohttp_async.Client.post ~body (Uri.make ~host ~port ~path:"/" ()) in
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

let create_remote_rpc ~host ~port =
  remote_rpc ~host ~port

let demo_rpc rpc =
  let () = Xmlrpc.string_of_call rpc |> Async.print_endline in
  let%bind response = Bookstore__Server.rpc_fn rpc in
  let () = Xmlrpc.string_of_response response |> Async.prerr_endline in
  return response

let get_lookup_result rpc arg = 
  lookup rpc arg >>>= 
  (function
  | Ok result -> return result
  | Error _ -> return "RPC call failed")
  