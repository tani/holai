let name x = x + 1;;
let NAME x = x + 10;;
let name' x = x + 100;;
let name'' x = x + 1000;;
let t = 2;;
let t' = 3;;
let nil = 4;;
let pi = 5;;
let pi' = 6;;
let reserved_sum () = t + t' + nil + pi + pi';;
let prime_arguments x x' x'' = x + 10 * x' + 100 * x'';;
let local_case () = let R = 30 in let r = 12 in R - r;;
let parallel_case () = let K x = x + 40 and k x = x + 2 in K 1 + k 1;;
type stars_record = { t:int; t':int; pi:int; pi':int; nan:int; nan':int };;
let field_sum () =
  let r = { t=1; t'=2; pi=3; pi'=4; nan=5; nan'=6 } in
  let r = { r with t'=20; pi'=40; nan'=60 } in
  r.t + r.t' + r.pi + r.pi' + r.nan + r.nan';;
type stars_variant = Empty | Empty' | Full;;
let empty = 7;;
let EMPTY = 8;;
let variant = function Empty -> 1 | Empty' -> 2 | Full -> 3;;
module Prime' = struct let value' = 19;; end;;
let observations () = [
  "star-case=" ^ string_of_int(name 1 + NAME 1 + name' 1 + name'' 1);
  "star-reserved=" ^ string_of_int(reserved_sum());
  "star-primes=" ^ string_of_int(prime_arguments 1 2 3);
  "star-local-case=" ^ string_of_int(local_case());
  "star-parallel=" ^ string_of_int(parallel_case());
  "star-fields=" ^ string_of_int(field_sum());
  "star-variants=" ^ string_of_int(empty + EMPTY + variant Empty + variant Empty' + variant Full);
  "star-module=" ^ string_of_int Prime'.value';
  "star-literal=|unchanged|" ];;
