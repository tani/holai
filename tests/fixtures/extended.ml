(* Runtime/compiler boundaries exercised against original OCaml modules. *)
type cell = { mutable counter : int; label : string };;
let record_test () =
  let r = { counter = 1; label = "source" } in
  let s = { r with counter = 7 } in
  r.counter <- r.counter + 1;
  string_of_int r.counter ^ ":" ^ string_of_int s.counter ^ ":" ^ s.label;;
let record_pattern {counter=c;label=l} = string_of_int c ^ ":" ^ l;;
type inline_record = Named of { name : string; size : int };;
let inline_record_test () =
  let value = Named {name="tree";size=3} in
  match value with Named {size} -> string_of_int size;;
let array_test () =
  let a = [|3;4;5|] in a.(1) <- 9;
  match a with [|x;y;z|] -> string_of_int (x+y+z) | _ -> "bad";;
let whole_constructor_pattern = function Fields _ -> 12 | _ -> 0;;
let whole_constructor_test () = whole_constructor_pattern (Fields(4,8));;
let format_test margin =
  let b = Buffer.create 8 in let fmt = Format.formatter_of_buffer b in
  Format.pp_set_margin fmt margin;
  Format.pp_open_hvbox fmt 2;
  Format.pp_print_string fmt "alpha"; Format.pp_print_space fmt ();
  Format.pp_print_string fmt "beta"; Format.pp_print_space fmt ();
  Format.pp_print_string fmt "gamma";
  Format.pp_close_box fmt (); Format.pp_print_flush fmt ();
  String.escaped (Buffer.contents b);;
let extended_observations () =
  type_invention_warning := false;
  let p = mk_var("p",bool_ty) and q = mk_var("q",bool_ty) in
  let f = mk_var("f",mk_fun_ty bool_ty bool_ty) in
  let n1 = enter [] (p,1) empty_net in
  let n2 = enter [q] (q,2) empty_net in
  let n3 = enter [] (mk_comb(f,p),3) n1 in
  let net = merge_nets(n2,n3) in
  let keys = (--) 0 50 in
  let first_map = itlist (fun k m -> I_map.add k (k*k) m) keys I_map.empty in
  let other = itlist (fun k m -> I_map.add k (k+1) m) ((--) 25 75) I_map.empty in
  let merged = I_map.union (fun k a b -> if k mod 2 = 0 then Some(a+b) else None) first_map other in
  let map_observations = map (fun k ->
    "map:" ^ string_of_int k ^ "=" ^
    (try string_of_int (I_map.find k merged) with Not_found -> "none")) ((--) 0 75) in
  ["record=" ^ record_test ();
   "record_pattern=" ^ record_pattern {counter=6;label="match"};
   "inline_record=" ^ inline_record_test ();
   "array=" ^ array_test ();
   "whole_constructor=" ^ string_of_int (whole_constructor_test ());
   "format_wide=" ^ format_test 78;
   "format_narrow=" ^ format_test 10;
   "net_p=" ^ int_list_string (lookup p net);
   "net_q=" ^ int_list_string (lookup q net);
   "net_fp=" ^ int_list_string (lookup (mk_comb(f,p)) net);
   "type_match=" ^ String.concat ";" (map (fun (a,b) -> type_string a ^ ":" ^ type_string b) (type_match aty bool_ty []));
   "parse_type=" ^ type_string (parse_type "bool->bool");
   "parse_lambda=" ^ term_string (parse_term "\\x:bool. x");
   "parse_eq=" ^ term_string (parse_term "(p:bool) = p");
   "print_type=" ^ string_of_type (mk_fun_ty bool_ty bool_ty);
   "print_lambda=" ^ string_of_term (mk_abs(p,p));
   "print_reflexivity=" ^ string_of_thm (REFL p);
   "quote=" ^ term_string `((q:bool) = q)`]
  @ map_observations;;
