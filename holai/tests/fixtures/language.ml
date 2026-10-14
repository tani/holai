(* New source-language/library boundaries, also executed in original OCaml. *)
let language_capture = 7;;
module type Language_key = sig val value : int end;;
module Language_functor (Key : Language_key) = struct
  let counter = ref 0
  let observe () = language_capture + Key.value
  let tick () = incr counter; !counter
end;;
let language_capture = 100;;
module Language_key_a = struct let value = 1 end;;
module Language_key_b = struct let value = 3 end;;
module Language_a = Language_functor(Language_key_a);;
module Language_b = Language_functor(Language_key_b);;
module Language_alias = Language_a;;
type language_flag = True | False;;
let language_bool b = if b then True else False;;
let language_bool_string = function True -> "tag_true" | False -> "tag_false";;
let language_labels x ~left ~right = x + 10 * left + 100 * right;;
let language_recursive =
  let delta = 2 in
  let rec count = let unit_step = delta in
    fun n -> if n = 0 then 0 else unit_step + count (n-1) in count;;
let language_local seed =
  let calls = ref 0 in
  let module Local = struct
    type item = Box of int
    let saved = Box seed
    let next n = incr calls; match saved with Box x -> x + n + !calls
    let rec run = let step = 1 in fun n -> if n = 0 then 0 else step + run (n-1)
  end in
  let module Alias = Local in
  fun n -> Alias.next n + Local.run 2;;
module Language_nested = struct
  let make seed =
    let module Inner = struct
      type cell = Cell of int
      let saved = Cell seed
      let observe n = match saved with Cell value -> value+n
    end in
    Inner.observe
end;;
(* Instantiate library functors after earlier lexical type metadata exists. *)
module Language_ordered = struct type t = int let compare = compare end;;
module Language_map = Map.Make(Language_ordered);;
module Language_set = Set.Make(Language_ordered);;
module Language_import = struct let value = 20 let combine x y = x+y end;;
let language_import_collisions () =
  let before = Language_import.combine 3 4 in
  let combine x y = x-y in
  let result = Language_import.combine 4 5 + combine 9 2 in
  let value = 3 in before + result + Language_import.value + value;;
let language_prefix_operator () =
  let rec (!) f n = if n = 0 then 0 else f n + !f (n-1) in
  !(fun n -> n+1) 3;;
let language_loops () =
  let sum = ref 0 in
  for i = 1 to 4 do sum := !sum + i done;
  for i = 3 downto 1 do sum := !sum + i done;
  let iterations = ref 0 in
  while !iterations < 3 do incr iterations; incr sum done;
  !sum,!iterations;;
let language_lazy () =
  let calls = ref 0 in let cell = lazy (incr calls; 42) in
  let before = !calls in let first = Lazy.force cell in let second = Lazy.force cell in
  let failed_calls = ref 0 in let failed = lazy (incr failed_calls; failwith "cached") in
  let first_failure = not (can Lazy.force failed) in
  let second_failure = not (can Lazy.force failed) in
  int_list_string [before;first;second;!calls;!failed_calls] ^ ":" ^
    bool_string first_failure ^ ":" ^ bool_string second_failure;;
let language_random () =
  Random.init 0;
  let first = List.map (fun _ -> Random.bits ()) ((--) 0 7) in
  Random.init 0;
  let second = List.map (fun _ -> Random.int 97) ((--) 0 7) in
  (* Use a sequential standard-library map for stateful callback order. *)
  Random.init (-7);
  let seeded = List.map (fun _ -> Random.bits ()) [1;2;3;4] in
  int_list_string first ^ ":" ^ int_list_string second ^ ":" ^ int_list_string seeded;;
let language_containers () =
  let m = List.fold_left (fun m n -> Language_map.add n (n*n) m)
    Language_map.empty [5;2;4;1;3] in
  let m = Language_map.remove 2 m in
  let m = Language_map.filter (fun k _ -> k mod 2 = 1) m in
  let m = Language_map.map (fun n -> n+1) m in
  let other = Language_map.singleton 3 100 in
  let m = Language_map.merge (fun _ a b -> match a,b with
    Some x,Some y -> Some(x+y) | Some x,None | None,Some x -> Some x | _ -> None) m other in
  let bindings = String.concat ";" (List.map (fun (k,v) -> string_of_int k ^ ":" ^ string_of_int v) (Language_map.bindings m)) in
  let s = List.fold_left (fun s n -> Language_set.add n s) Language_set.empty [5;2;4;1;3] in
  let s = Language_set.remove 2 s in
  let other = Language_set.add 7 (Language_set.singleton 3) in
  let union = Language_set.union s other and inter = Language_set.inter s other in
  let diff = Language_set.diff s other in
  [bindings; int_list_string (Language_set.elements union);
   int_list_string (Language_set.elements inter); int_list_string (Language_set.elements diff);
   string_of_int (Language_map.cardinal m); string_of_int (Language_set.cardinal s);
   bool_string (Language_set.subset inter union);
   bool_string (Language_set.for_all (fun n -> n > 0) union);
   bool_string (Language_map.exists (fun _ v -> v > 100) m);
   string_of_int (Language_set.compare inter diff)];;
(* Adjacent named-function stages must retain their original lexical scopes. *)
let language_function_chain () =
  let add x y = x+y in
  let increment n = add 1 n in
  let apply fn n = fn n in
  int_list_string [increment 41; apply (add 20) 22];;
let language_function_mixed () =
  let step n = n+1 in
  let rec even n = n = 0 || odd (n-1)
  and odd n = n <> 0 && even (n-1) in
  let advance n = if even n then step n else n in
  let rec total n = if n = 0 then 0 else advance n + total (n-1) in
  let snapshot n = total n in
  let total n = total n + 1 in
  let bumped n = total n in
  let rec total n = if n = 0 then 0 else total (n-1) + step n in
  int_list_string [snapshot 4; bumped 4; total 3; advance 4; advance 3];;
let language_function_shadow () =
  let calculate x y = x+y in
  let captured () = calculate in
  let calculate x y = x*y in
  let middle () = calculate in
  let calculate x y = x-y in
  let later () = calculate in
  let calculate x y = x+2*y in
  int_list_string [captured () 20 22; middle () 14 3;
                   later () 46 4; calculate 22 10] ^ ":" ^
  bool_string (captured () == captured ()) ^ ":" ^
  bool_string (not (captured () == middle ()));;
let language_function_parallel () =
  let combine x y = x+y in
  let combine x y = combine x y + 100
  and previous x y = combine x y in
  let observe n = previous n 22 in
  int_list_string [combine 20 22; previous 20 22; observe 20];;
let language_function_import () =
  let imported x = Language_import.combine x 22 in
  let combine x y = x-y in
  let global x = language_capture+x in
  let language_capture x = x+2 in
  int_list_string [imported 20; combine 64 22; global 1; language_capture 40];;
let language_function_barrier () =
  let calls = ref 0 in
  let before n = n+1 in
  let initialized = (incr calls; fun n -> before n + !calls) in
  let middle n = initialized n in
  let next n = middle n in
  let before n = n+100 in
  int_list_string [next 40; before 1; !calls];;
let language_observations () =
  let a1 = Language_a.tick () in let a2 = Language_alias.tick () in
  let b1 = Language_b.tick () in
  let local_a = language_local 10 in let local_b = language_local 30 in
  let la1 = local_a 3 in let la2 = local_a 3 in let lb1 = local_b 3 in
  let loop_sum,loop_count = language_loops () in
  let table = Hashtbl.create 1 in
  Hashtbl.add table (1,2) 4; Hashtbl.add table (1,2) 5;
  let first = Hashtbl.find table (1,2) in
  Hashtbl.replace table (1,2) 9; let replaced = Hashtbl.find table (1,2) in
  Hashtbl.clear table;
  let b = Buffer.create 16 in let fmt = Format.formatter_of_buffer b in
  Format.pp_open_vbox fmt 2;
  Format.pp_print_char fmt 'x'; Format.pp_print_cut fmt ();
  Format.pp_print_int fmt 42; Format.pp_close_box fmt (); Format.pp_print_flush fmt ();
  ["language_functor=" ^ string_of_int (Language_a.observe ()) ^ ":" ^ string_of_int (Language_b.observe ());
   "language_instances=" ^ int_list_string [a1;a2;b1];
   "language_bool=" ^ language_bool_string (language_bool true) ^ ":" ^ language_bool_string (language_bool false);
   "language_labels=" ^ string_of_int (language_labels 7 ~right:3 ~left:2);
   "language_recursive=" ^ string_of_int (language_recursive 4);
   "language_local=" ^ int_list_string [la1;la2;lb1];
   "language_nested=" ^ string_of_int (Language_nested.make 11 3);
   "language_import=" ^ string_of_int (language_import_collisions ());
   "language_prefix_operator=" ^ string_of_int (language_prefix_operator ());
   "language_function_chain=" ^ language_function_chain ();
   "language_function_mixed=" ^ language_function_mixed ();
   "language_function_shadow=" ^ language_function_shadow ();
   "language_function_parallel=" ^ language_function_parallel ();
   "language_function_import=" ^ language_function_import ();
   "language_function_barrier=" ^ language_function_barrier ();
   "language_loops=" ^ int_list_string [loop_sum;loop_count];
   "language_lazy=" ^ language_lazy ();
   "language_hash=" ^ int_list_string [first;replaced] ^ ":" ^
     bool_string (try ignore (Hashtbl.find table (1,2)); false with Not_found -> true);
   "language_assert=" ^ bool_string (try assert false; false with Assert_failure _ -> true);
   "language_format=" ^ String.escaped (Buffer.contents b);
   "language_map_set=" ^ String.concat "|" (language_containers ());
   "language_stdlist=" ^ int_list_string (List.map2 (+) [1;2;3] [4;5;6]) ^ ":" ^
     string_of_int (List.fold_left2 (fun a x y -> a+x*y) 0 [1;2] [3;4]);
   "language_random=" ^ language_random ()] @
  map (fun (x,n) -> "language_shift:" ^ string_of_int x ^ ":" ^ string_of_int n ^ "=" ^
    string_of_int (x lsr n)) [(-1,0);(-1,1);(-1,62);(-2,3);(17,2);(1,63)];;
