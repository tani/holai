module type View = sig
  type token = private Token of int
  val make : int -> token
end;;
module Sealed : View = struct
  type token = Token of int
  let make n = Token n
end;;
include Sealed;;
let forged = Token 3;;
