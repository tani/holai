(* Product/CBV/numeral/recursive-definition examples executed in both hosts. *)
module Execution_records = struct
  type left = { rws:int; head:int }
  type right = { rws:int; tail:int }
  let read = function
    | {head = h; rws = r} when h > 0 -> h+r
    | {rws = r} -> r
end;;
module Execution_constructors = struct
  type original = Var of int | Const of int * int | Abs of int * int
  let original_const a b = Const(a,b)
  let original_abs a b = Abs(a,b)
  type constant = {head:int}
  type lowered = Const of constant | Abs of lowered | Stop
  let original n = let x:original = Var n in x
  let first = function Var n -> n | Const(a,b) -> a+b | Abs(a,b) -> a-b
  let tuple_first = function
    | _,Var n -> n
    | _,Const(a,b) -> a+b
    | _,Abs(a,b) -> a-b
  let lower = function Stop -> 0 | Const {head = n} -> n | Abs _ -> 99
  let lower_value n = Const {head = n}
end;;
let execution_boundary_observations () =
  let cell = {contents = (4,5)} in
  let {contents = (a,b)} as same = cell in
  let copy = {cell with contents = (8,9)} in
  cell.contents <- (6,7);
  let read_without_bang = let (!) _ = 99 in fst cell.contents in
  let table = Hashtbl.create 1 in
  Hashtbl.add table (1,2) 4; Hashtbl.add table (1,2) 5;
  Hashtbl.add table (3,4) 7;
  let total = Hashtbl.fold (fun _ n acc -> n+acc) table 0 in
  let inventory = List.sort compare (Hashtbl.fold (fun k n acc -> (k,n)::acc) table []) in
  let inventory_s = String.concat ";" (List.map (fun ((a,b),n) -> int_list_string [a;b;n]) inventory) in
  Hashtbl.remove table (1,2); let revealed = Hashtbl.find table (1,2) in
  Hashtbl.remove table (1,2); Hashtbl.remove table (1,2);
  let absent = try ignore (Hashtbl.find table (1,2)); false with Not_found -> true in
  let log = ref [] in
  let array = Array.fold_left (fun acc n -> log := n :: !log; acc*10+n) 0 [|1;2;3|] in
  ["ref_record=" ^ int_list_string [a;b;fst !cell;snd !cell;fst !copy;snd !copy;read_without_bang] ^ ":" ^
     bool_string (same == cell) ^ ":" ^ bool_string (cell != copy);
   "hash_fold=" ^ string_of_int total ^ ":" ^ inventory_s;
   "hash_remove=" ^ string_of_int revealed ^ ":" ^ bool_string absent;
   "array_fold=" ^ string_of_int array ^ ":" ^ int_list_string (List.rev !log);
   "record_hint=" ^ string_of_int (Execution_records.read {Execution_records.head=3; rws=4}) ^ ":" ^
     string_of_int (Execution_records.read {Execution_records.head=0; rws=9});
   "constructor_family=" ^ string_of_int (Execution_constructors.first (Execution_constructors.original 7)) ^ ":" ^
     string_of_int (Execution_constructors.tuple_first (0,Execution_constructors.original 8)) ^ ":" ^
     string_of_int (Execution_constructors.lower (Execution_constructors.lower_value 11)) ^ ":" ^
     string_of_int (Execution_constructors.first (Execution_constructors.original_const 2 3)) ^ ":" ^
     string_of_int (Execution_constructors.first (Execution_constructors.original_abs 9 4)) ^ ":" ^
     string_of_int (Execution_constructors.tuple_first (0,Execution_constructors.original_const 3 4))];;
let execution_stage label f = try f () with Failure message -> failwith (label ^ ": " ^ message);;
let execution_conversion label conv text expected = execution_stage label (fun () ->
  let tm = parse_term text and expected = parse_term expected in
  let th = conv tm in
  let l,r = dest_eq (concl th) in
  if hyp th <> [] || not (aconv tm l && aconv expected r)
  then failwith ("Wrong conversion: " ^ label ^ ": " ^ string_of_term r ^ " expected " ^ string_of_term expected)
  else label ^ "=" ^ (if label="product_beta" then bound_theorem_string th else theorem_string th));;
let product_observations () =
  let p = parse_term "(p:bool),(q:bool)" in
  let x,y = dest_pair p in
  let paired = new_definition (parse_term "test_pfirst ((x:bool),(y:bool)) = x") in
  let theorem_names =
    ["PAIR_EQ",PAIR_EQ;"FST",FST;"SND",SND;"PAIR",PAIR;
     "pair_INDUCT",pair_INDUCT;"pair_RECURSION",pair_RECURSION;
     "CURRY_DEF",CURRY_DEF;"UNCURRY_DEF",UNCURRY_DEF] in
  ["product_type=" ^ type_string (type_of p);
   "product_roundtrip=" ^ bool_string (aconv p (mk_pair(x,y))) ^ ":" ^ term_string x ^ ":" ^ term_string y;
   "product_definition=" ^ theorem_string paired;
   execution_conversion "product_projection" (REWRITE_CONV [paired]) "test_pfirst ((p:bool),(q:bool))" "p:bool";
   execution_conversion "product_beta" GEN_BETA_CONV "(\\(x:bool,y:bool). x) (p:bool,q:bool)" "p:bool";
   execution_conversion "product_let" let_CONV "let x,y = (p:bool),(q:bool) in x" "p:bool"] @
   List.map (fun (name,th) -> if hyp th <> [] then failwith name else "product_theorem:" ^ name ^ "=" ^ theorem_string th) theorem_names;;
let computation_observations () =
  let cases =
    ["cbv_and","T /\\ F","F";"cbv_imp","F ==> p","T";
     "cbv_cond","if T then (p:bool) else q","p:bool";
     "cbv_nested","~(T /\\ F) /\\ (T ==> T)","T";
     "cbv_beta","(\\x:bool. x) p","p:bool";
     "cbv_abstraction","\\x:bool. (\\y. y) x","\\x:bool. x";
     "cbv_let","let x = T in x /\\ F","LET_END F"] in
  let evaluated = List.map (fun (name,text,result) -> execution_conversion name Compute.EVAL_CONV text result) cases in
  let weak = execution_conversion "cbv_weak" (Compute.WEAK_CBV_CONV (Compute.bool_compset ()))
    "\\x:bool. (\\y. y) x" "\\x:bool. (\\y. y) x" in
  let restricted = execution_conversion "cbv_restricted" (Compute.RESTR_EVAL_CONV [parse_term "~"])
    "~(T /\\ F)" "~F" in
  let let_cs = Compute.bool_compset () in
  execution_stage "add_let_end" (fun () -> Compute.add_thms [LET_END_DEF] let_cs);
  let full_let = execution_conversion "cbv_let_extended" (Compute.CBV_CONV let_cs)
    "let x = T in x /\\ F" "F" in
  let definition = execution_stage "cbv_definition" (fun () -> new_definition (parse_term "test_cbool (x:bool) <=> x /\\ T")) in
  let cs = execution_stage "new_compset" (fun () -> Compute.new_compset [definition;AND_CLAUSES]) in
  let before = execution_conversion "cbv_custom" (Compute.CBV_CONV cs) "test_cbool p" "p:bool" in
  execution_stage "scrub_thms" (fun () -> Compute.scrub_thms [definition] cs);
  let deleted = execution_conversion "cbv_deleted" (Compute.CBV_CONV cs) "test_cbool p" "test_cbool p" in
  execution_stage "restore_thms" (fun () -> Compute.add_thms [definition] cs);
  let restored = execution_conversion "cbv_restored" (Compute.CBV_CONV cs) "test_cbool p" "p:bool" in
  let items = List.sort compare (List.map fst (Compute.listItems cs)) in
  let invalid = not (can (Compute.new_compset) [REFL (parse_term "\\x:bool. x")]) in
  let p = parse_term "p:bool" in
  let assumed = execution_stage "EVAL_RULE" (fun () -> Compute.EVAL_RULE (ASSUME (parse_term "T /\\ p"))) in
  let expected = parse_term "T /\\ p" in
  if hyp assumed <> [expected] || not (aconv p (concl assumed)) then failwith "EVAL_RULE hypotheses" else
  evaluated @ [weak;restricted;full_let;"cbv_definition=" ^ theorem_string definition;before;deleted;restored;
    "cbv_items=" ^ String.concat ";" items;
    "cbv_invalid=" ^ bool_string invalid;
    "cbv_assumed=" ^ theorem_string assumed;
    "cbv_tactic=" ^ theorem_string (prove(parse_term "T /\\ ~F",Compute.EVAL_TAC));
    "cbv_flags=" ^ bool_string (!Compute.monitoring = None) ^ ":" ^ bool_string (!Compute.stoppers = None)];;
let natural_observations () =
  let texts = ["0";"1";"2";"17";"16777215";"16777216";"16777217";
    "123456789012345678901234567890"] in
  let numerals = List.map (fun text ->
    let n = num_of_string text in let tm = mk_numeral n in
    if not (is_numeral tm) || dest_numeral tm <>/ n then failwith "Numeral roundtrip" else
    "numeral:" ^ text ^ "=" ^ term_string tm ^ ":" ^ string_of_num (dest_numeral tm) ^ ":" ^ string_of_term tm) texts in
  let theorems = ["INFINITY_AX",INFINITY_AX;"NOT_SUC",NOT_SUC;"SUC_INJ",SUC_INJ;
    "num_INDUCTION",num_INDUCTION;"num_RECURSION",num_RECURSION;"num_CASES",num_CASES;
    "BIT0_DEF",BIT0_DEF;"BIT1_DEF",BIT1_DEF] in
  let reflexivity = prove(parse_term "!n:num. n = n",INDUCT_TAC THEN REFL_TAC) in
  numerals @ List.map (fun (name,th) -> if hyp th <> [] then failwith name else "natural_theorem:" ^ name ^ "=" ^ theorem_string th) theorems @
  ["natural_induction=" ^ theorem_string reflexivity;
   "numeral_negative=" ^ bool_string (not (can mk_numeral (num (-1))));
   "numeral_invalid=" ^ bool_string (not (can dest_numeral (parse_term "T")));
   "natural_types=" ^ string_of_int (get_type_arity "ind") ^ ":" ^ string_of_int (get_type_arity "num")];;
let recursion_observations () =
  let identity_text = "(test_nid 0 = 0) /\\ (!n:num. test_nid (SUC n) = SUC (test_nid n))" in
  let exists = prove_recursive_functions_exist num_RECURSION (parse_term identity_text) in
  let definition = new_recursive_definition num_RECURSION (parse_term identity_text) in
  let identity = prove(parse_term "!n:num. test_nid n = n",INDUCT_TAC THEN ASM_REWRITE_TAC [definition]) in
  let repeated = new_recursive_definition num_RECURSION (parse_term identity_text) in
  let pair_text = "(test_npair 0 (p:bool) = p) /\\ (!n p. test_npair (SUC n) p = test_npair n p)" in
  let pair_definition = new_recursive_definition num_RECURSION (parse_term pair_text) in
  let pair_result = prove(parse_term "!n:num. !p:bool. test_npair n p = p",
    INDUCT_TAC THEN ASM_REWRITE_TAC [pair_definition]) in
  let zero_ex = prove(parse_term "?n:num. n = 0",EXISTS_TAC (parse_term "0") THEN REFL_TAC) in
  let specified = new_specification ["test_speczero"] zero_ex in
  let respecified = new_specification ["test_speczero"] zero_ex in
  let invalid = not (can (new_specification ["a";"a"]) (prove(parse_term "?(x:bool) (y:bool). x = x /\\ y = y",
    EXISTS_TAC (parse_term "T") THEN EXISTS_TAC (parse_term "T") THEN REWRITE_TAC []))) in
  let free = not (can (new_specification ["b"]) (ASSUME (parse_term "?x:num. x = 0"))) in
  if not (forall (fun th -> hyp th = []) [exists;definition;identity;pair_definition;pair_result;specified])
  then failwith "Recursive/specification result has unproved hypotheses" else
  ["recursive_exists=" ^ bound_theorem_string exists;
   "recursive_definition=" ^ theorem_string definition;
   "recursive_identity=" ^ theorem_string identity;
   "recursive_benign=" ^ bool_string (aconv (concl repeated) (concl definition));
   "recursive_parameter=" ^ theorem_string pair_definition;
   "recursive_parameter_result=" ^ theorem_string pair_result;
   "specification=" ^ theorem_string specified;
   "specification_benign=" ^ bool_string (aconv (concl specified) (concl respecified));
   "specification_invalid=" ^ bool_string invalid ^ ":" ^ bool_string free];;
let execution_observations () =
  let old_verbose = !verbose in verbose := false;
  try
    let boundary = execution_boundary_observations () in
    let product = product_observations () in
    let computation = computation_observations () in
    let naturals = natural_observations () in
    let recursion = recursion_observations () in
    verbose := old_verbose; boundary @ product @ computation @ naturals @ recursion
  with e -> verbose := old_verbose; raise e;;
