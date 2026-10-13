(* Fault-line corpus: scopes, currying, tuples, patterns, exceptions. *)
let add x y = x + y;;
let inc = add 1;;
let higher f x y = f x y;;
let staged f = let middle = f 7 in middle 9;;
let choose_fun b = if b then add else fun x y -> x - y;;
let overapplication () = choose_fun true 3 4;;
let unit_fn () = 42;;
let pass_unit f = f ();;
let pair_fn (x,y) = x + y;;
let pattern_shadow (x,y) x = x + y;;
let negate = (~-);;
let subtract_op = (-);;
let f x = x + 1;;
let g = f;;
let old x = f x;;
let f x = x + 10;;
let x = 10;;
let parallel () = let x = 1 and y = x in x + y;;
let lexical () = let x = 1 in let f () = x in let x = 2 in f ();;
let local_nonrec () = let add x y = add x y + 100 in add 3 4;;
let case_shadow () = let R = 30 in let r = 12 in R - r;;
let case_function_shadow () = let K x = x + 40 in let k x = x + 2 in K 1 + k 1;;
let case_parallel_functions () = let K x = x + 40 and k x = x + 2 in K 1 + k 1;;
let rec even n = if n = 0 then true else odd (n - 1)
and odd n = if n = 0 then false else even (n - 1);;
let local_mutual n =
  let rec even_local n = if n = 0 then true else odd_local (n - 1)
  and odd_local n = if n = 0 then false else even_local (n - 1) in even_local n;;
type sample = Zero | One of int | Pair of (int * int) | Fields of int * int;;
let inspect = function
  (One n | Pair(n,_) | Fields(n,_)) when n > 0 -> n
  | _ -> 0;;
let only_one (One n) = n;;
let alias = function (Pair(x,y) as p) -> x + y | _ -> 0;;
exception Trouble of int * string;;
let catch n = try (if n < 0 then raise (Trouble(n,"bad")) else n)
  with Trouble(k,_) as ex -> -k;;
let propagate () = try raise (Trouble(1,"outer")) with Failure _ -> 0;;
let nested_catch () = try propagate () with Trouble(k,_) -> k;;
let empty_tuple = ();;
let answer_pair = 3,4;;
let escaped = "a\n\"b\\c";;
let floating x = x +. 0.5;;
let char_match = function 'a' -> 1 | _ -> 0;;
let hex = 0x2a and binary = 0b101010 and octal = 0o52;;
let local_cl_functions () =
  let rec atom n = if n = 0 then 0 else 1 + atom (n - 1)
  and search n = 10 + atom n in search 3;;
let local_syntax_function () =
  let lambda n = n + 4 in let block n = lambda n + 1 in block 7;;
let parent_before n = n + 2;;
module Parent_capture = struct let observe n = parent_before n end;;
let parent_before n = n + 20;;
let parent_capture () = Parent_capture.observe 3 + parent_before 3;;
