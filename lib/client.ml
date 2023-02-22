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

let get_result rpc_call to_str rpc arg = 
  rpc_call rpc arg >>>= 
  (function
  | Ok result -> return (to_str result)
  | Error e -> return (sprintf "RPC call failed: %s" (Util.string_of_default_error e)))

let get_lookup_result =
  get_result lookup LookupResponse.to_string

let get_search_result =
  get_result search (String.concat ~sep:"\n")