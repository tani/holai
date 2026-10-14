(* Complete standard-core examples; original algorithms run in both hosts. *)
module Standard_syntax_value = struct
  let lambda = 5
  let use n = (fun m -> m + lambda) n
end;;
module Standard_syntax_function = struct
  let lambda n = n+1
  let use n = (fun m -> lambda m) n
end;;
let standard_library_observations () =
  let cell = ref 3 in
  let original = [cell;cell] in let array = Array.of_list original in
  array.(0) <- ref 8;
  let calls = ref [] in
  let mapped = Array.map (fun n -> calls := n :: !calls; n*n) [|2;3;4|] in
  let config = Gc.get () in
  let altered = {config with Gc.stack_limit = config.Gc.stack_limit + 1} in
  Gc.set altered;
  let changed = (Gc.get ()).Gc.stack_limit in
  Gc.set config;
  let numeric = map (fun (a,b) ->
    string_of_num (quo_num (num a) (num b)) ^ ":" ^
    string_of_num (mod_num (num a) (num b))) [7,3;-7,3;7,-3;-7,-3] in
  ["standard_lambda=" ^ int_list_string [Standard_syntax_value.use 3;Standard_syntax_function.use 3];
   "standard_array=" ^ int_list_string [!(hd original);!(array.(0));!(array.(1))] ^ ":" ^
     bool_string (array.(1) == cell) ^ ":" ^ int_list_string (List.rev !calls) ^ ":" ^
     int_list_string [mapped.(0);mapped.(1);mapped.(2)];
   "standard_gc=" ^ int_list_string [config.Gc.stack_limit;changed;(Gc.get ()).Gc.stack_limit] ^ ":" ^
     bool_string (config != altered);
   "standard_num=" ^ string_of_num (minus_num (num 3 // num 2)) ^ ":" ^ String.concat ";" numeric;
   "standard_num_rational=" ^ string_of_num (quo_num (num 7 // num 2) (num (-3) // num 2)) ^ ":" ^
     string_of_num (mod_num (num 7 // num 2) (num (-3) // num 2));
   "standard_num_noninteger=" ^ bool_string (not (can Num.int_of_num (num 3 // num 2)));
   "standard_num_overflow=" ^ bool_string (not (can Num.int_of_num (power_num (num 2) (num 80))))];;
let standard_theorem_observations () =
  map (fun (label,th) ->
    if hyp th <> [] then failwith ("Open standard theorem: " ^ label)
    else "standard_theorem:" ^ label ^ "=" ^ theorem_string th)
   ["WF_num",WF_num;"WF_MEASURE",WF_MEASURE;"WF_REC",WF_REC;
    "list_INDUCT",list_INDUCT;"list_RECURSION",list_RECURSION;
    "APPEND_ASSOC",APPEND_ASSOC;"LENGTH_APPEND",LENGTH_APPEND;
    "REAL_ADD_ASSOC",REAL_ADD_ASSOC;"REAL_COMPLETE",REAL_COMPLETE;
    "INT_ADD_ASSOC",INT_ADD_ASSOC;"INT_ENTIRE",INT_ENTIRE;
    "IN_INSERT",IN_INSERT;"FINITE_INSERT",FINITE_INSERT;"CARD_CLAUSES",CARD_CLAUSES;
    "NSUM_CLAUSES_NUMSEG",NSUM_CLAUSES_NUMSEG;"SUM_CLAUSES_NUMSEG",SUM_CLAUSES_NUMSEG;
    "CART_EQ",CART_EQ;"LAMBDA_BETA",LAMBDA_BETA;"DIMINDEX_2",DIMINDEX_2;
    "WF_REC_CASES",WF_REC_CASES];;
let standard_numeric_observations () =
  map (fun (label,conv,text,expected) -> execution_conversion label conv text expected)
   ["standard_nat_add",NUM_ADD_CONV,"17 + 25:num","42:num";
    "standard_nat_mult",NUM_MULT_CONV,"12 * 13:num","156:num";
    "standard_nat_sub",NUM_SUB_CONV,"7 - 12:num","0:num";
    "standard_nat_div",NUM_DIV_CONV,"100 DIV 7","14:num";
    "standard_nat_mod",NUM_MOD_CONV,"100 MOD 7","2:num";
    "standard_nat_zero_div",NUM_REDUCE_CONV,"19 DIV 0","0:num";
    "standard_nat_zero_mod",NUM_REDUCE_CONV,"19 MOD 0","19:num";
    "standard_nat_pow",NUM_EXP_CONV,"4 EXP 5","1024:num";
    "standard_nat_le",NUM_LE_CONV,"17 <= 25:num","T";
    "standard_nat_nested",NUM_REDUCE_CONV,"((17 + 25) * 3) DIV 7","18:num";
    "standard_nat_large",NUM_ADD_CONV,"123456789012345678901234567890 + 89:num","123456789012345678901234567979:num";
    "standard_real_int",REAL_INT_REDUCE_CONV,"(-- &7 + &3) * &2:real","-- &8:real";
    "standard_rat_add",REAL_RAT_REDUCE_CONV,"&1 / &3 + &1 / &6:real","&1 / &2:real";
    "standard_rat_mult",REAL_RAT_REDUCE_CONV,"(-- &3 / &4) * (&8 / &9):real","-- &2 / &3:real";
    "standard_rat_inv",REAL_RAT_REDUCE_CONV,"inv (&2 / &3):real","&3 / &2:real";
    "standard_rat_zero",REAL_RAT_REDUCE_CONV,"inv (&0:real)","&0:real";
    "standard_rat_lt",REAL_RAT_REDUCE_CONV,"&1 / &3 < &1 / &2:real","T";
    "standard_int_add",INT_REDUCE_CONV,"-- &7 + &3:int","-- &4:int";
    "standard_int_mult",INT_REDUCE_CONV,"(-- &7) * (-- &3):int","&21:int";
    "standard_int_div",INT_REDUCE_CONV,"(-- &7) div &3:int","-- &3:int";
    "standard_int_rem",INT_REDUCE_CONV,"(-- &7) rem &3:int","&2:int";
    "standard_dimension",DIMINDEX_CONV,"dimindex(:2)","2:num"] @
  ["standard_nat_invalid=" ^ bool_string (not (can NUM_ADD_CONV (parse_term "T")));
   "standard_rat_invalid=" ^ bool_string (not (can REAL_RAT_ADD_CONV (parse_term "T")))];;
let standard_proof_observations () =
  map (fun (label,text,tac) ->
    try let goal = parse_term text in checked_proof label goal (prove(goal,tac))
    with Failure message -> failwith (label ^ ": " ^ message))
   ["standard_wf","WF(MEASURE (\\n:num. n))",MATCH_ACCEPT_TAC (ISPEC (parse_term "\\n:num. n") WF_MEASURE);
    "standard_arith","!m n:num. m <= n ==> m + 3 <= n + 3",ARITH_TAC;
    "standard_ring","!x y:num. (x + y) EXP 2 = x EXP 2 + 2 * x * y + y EXP 2",CONV_TAC NUM_RING;
    "standard_real_ring","!x y:real. (x + y) pow 2 = x pow 2 + &2 * x * y + y pow 2",CONV_TAC REAL_RING;
    "standard_real_arith","!x y:real. x <= y ==> x + &3 <= y + &3",REAL_ARITH_TAC;
    "standard_int_arith","!x y:int. x < y ==> x + &1 <= y",INT_ARITH_TAC;
    "standard_list","!l:(A)list. APPEND l [] = l",LIST_INDUCT_TAC THEN ASM_REWRITE_TAC [APPEND];
    "standard_set","!s t:A->bool. s UNION t = t UNION s",SET_TAC [];
    "standard_card","CARD {1,2,3} = 3",SIMP_TAC [CARD_CLAUSES;FINITE_INSERT;FINITE_EMPTY;IN_INSERT;NOT_IN_EMPTY] THEN ARITH_TAC;
    "standard_nsum","nsum {1,2,3} (\\i. i) = 6",
      SIMP_TAC [NSUM_CLAUSES;FINITE_INSERT;FINITE_EMPTY;IN_INSERT;NOT_IN_EMPTY] THEN CONV_TAC NUM_REDUCE_CONV;
    "standard_sum","sum {1,2,3} (\\i:num. &i) = &6",
      SIMP_TAC [SUM_CLAUSES;FINITE_INSERT;FINITE_EMPTY;IN_INSERT;NOT_IN_EMPTY] THEN
      CONV_TAC (NUM_REDUCE_CONV THENC REAL_RAT_REDUCE_CONV);
    "standard_cart","((lambda i. (&i:real)):real^2)$1 = &1",
      SIMP_TAC [LAMBDA_BETA;DIMINDEX_2;ARITH_RULE (parse_term "1 <= 1:num");ARITH_RULE (parse_term "1 <= 2:num")]];;
let standard_normalizer_observations () =
  let term = parse_term "(x + y) * (x + y):num" in
  let th = NUM_NORMALIZE_CONV term in
  let l,r = dest_eq (concl th) in
  if hyp th <> [] || not (aconv term l) then failwith "Invalid normalizer equation";
  let expected = parse_term "x EXP 2 + 2 * x * y + y EXP 2:num" in
  let equivalence = prove(mk_eq(r,expected),CONV_TAC NUM_RING) in
  ["standard_normalizer=" ^ theorem_string th;
   checked_proof "standard_normalizer_equivalence" (mk_eq(r,expected)) equivalence];;
let standard_definition_observations () =
  let induction,recursion = define_type "test_full_tree = TestLeaf A | TestNode test_full_tree test_full_tree" in
  if hyp induction <> [] || hyp recursion <> [] then failwith "Open datatype principles";
  let definition = define (parse_term "(test_full_size (TestLeaf (x:A)) = 1) /\\
     (!l r:(A)test_full_tree. test_full_size (TestNode l r) = test_full_size l + test_full_size r)") in
  let goal = parse_term "!x y:A. test_full_size (TestNode (TestLeaf x) (TestLeaf y)) = 2" in
  let proof = prove(goal,REWRITE_TAC [definition] THEN CONV_TAC NUM_REDUCE_CONV) in
  let recursive = define (parse_term "(test_full_countdown 0 = 0) /\\
    (!n. test_full_countdown (SUC n) = SUC(test_full_countdown n))") in
  let identity = parse_term "!n:num. test_full_countdown n = n" in
  let identity_th = prove(identity,INDUCT_TAC THEN ASM_REWRITE_TAC [recursive]) in
  if hyp definition <> [] || hyp recursive <> [] then failwith "Open general definition";
  ["standard_tree_induction=" ^ bound_theorem_string induction;
   "standard_tree_recursion=" ^ bound_theorem_string recursion;
   "standard_tree_arity=" ^ string_of_int (get_type_arity "test_full_tree");
   "standard_tree_definition=" ^ theorem_string definition;
   checked_proof "standard_tree_size" goal proof;
   "standard_general_definition=" ^ theorem_string recursive;
   checked_proof "standard_general_identity" identity identity_th;
   "standard_define_invalid=" ^ bool_string (not (can define (parse_term "T")))];;
let standard_stage label f = try f () with Failure message -> failwith (label ^ ": " ^ message);;
let standard_observations () =
  let library = standard_stage "standard library" standard_library_observations in
  let theorems = standard_stage "standard theorems" standard_theorem_observations in
  let numeric = standard_stage "standard numeric" standard_numeric_observations in
  let proofs = standard_stage "standard proofs" standard_proof_observations in
  let normalizer = standard_stage "standard normalizer" standard_normalizer_observations in
  let definitions = standard_stage "standard definitions" standard_definition_observations in
  library @ theorems @ numeric @ proofs @ normalizer @ definitions;;
