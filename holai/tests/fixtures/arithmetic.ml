(* Mixed recursive groups and actual arith.ml algorithms, in both hosts. *)
let arithmetic_shift delta n = delta + n;;
let rec arithmetic_global n =
  if n = 0 then arithmetic_global_base else arithmetic_global (n-1)
and arithmetic_global_base = max 3 7;;
let rec arithmetic_standalone = max 8 5;;
module Arithmetic_mixed = struct
  let rec run n = if n = 0 then finish 2 else run (n-1)
  and finish = arithmetic_shift 6
end;;
let arithmetic_local seed =
  let calls = ref 0 in
  let rec even n = if n = 0 then finish seed else odd (n-1)
  and odd n = if n = 0 then finish (seed+1) else even (n-1)
  and finish = (incr calls; arithmetic_shift 4)
  and floor = max seed 2 in
  let a = even 4 in let b = odd 4 in
  a,b,floor,!calls;;
let arithmetic_module seed =
  let calls = ref 0 in
  let module Local = struct
    let rec run n = if n = 0 then finish seed else run (n-1)
    and finish = (incr calls; arithmetic_shift 3)
    and floor = max seed 2
  end in
  let result = Local.run 4 in
  result,Local.finish 2,Local.floor,!calls;;
let arithmetic_shadow () =
  let rec run n = if n = 0 then saved else run (n-1)
  and saved = let run n = n+1 in run 8 in
  run 2;;
let arithmetic_capture seed =
  let rec run n = if n = 0 then saved else run (n-1)
  and saved =
    let module Outer = struct let base = seed end in
    arithmetic_shift 2 Outer.base in
  run;;
let arithmetic_nested () =
  let rec run n = if n = 0 then saved else run (n-1)
  and saved =
    let rec inner n = if n = 0 then base else inner (n-1)
    and base = max 3 5 in inner 2 in
  run 1;;
let arithmetic_group_observations () =
  let a,b,floor,calls = arithmetic_local 6 in
  let m,f,mfloor,mcalls = arithmetic_module 7 in
  let captured = arithmetic_capture 11 in
  ["arithmetic_global=" ^ int_list_string [arithmetic_global 3;arithmetic_global_base;arithmetic_standalone];
   "arithmetic_static_module=" ^ string_of_int (Arithmetic_mixed.run 3);
   "arithmetic_mixed_local=" ^ int_list_string [a;b;floor;calls];
   "arithmetic_mixed_module=" ^ int_list_string [m;f;mfloor;mcalls];
   "arithmetic_shadow=" ^ string_of_int (arithmetic_shadow ());
   "arithmetic_capture=" ^ string_of_int (captured 3);
   "arithmetic_nested=" ^ string_of_int (arithmetic_nested ())];;
let arithmetic_theorem_observations () =
  map (fun (label,th) ->
    if hyp th <> [] then failwith ("Open arithmetic theorem: " ^ label)
    else "arith_theorem:" ^ label ^ "=" ^ theorem_string th)
   ["ADD_CLAUSES",ADD_CLAUSES;"ADD_ASSOC",ADD_ASSOC;"ADD_SYM",ADD_SYM;
    "MULT_CLAUSES",MULT_CLAUSES;"LEFT_ADD_DISTRIB",LEFT_ADD_DISTRIB;
    "EXP_ADD",EXP_ADD;"LE_ANTISYM",LE_ANTISYM;"LT_TRANS",LT_TRANS;
    "num_WOP",num_WOP;"SUB_EQ_0",SUB_EQ_0;"EVEN_ADD",EVEN_ADD;
    "DIVISION",DIVISION;"DIVISION_0",DIVISION_0;"DIV_ZERO",DIV_ZERO;
    "MOD_ZERO",MOD_ZERO;"MOD_ADD_MOD",MOD_ADD_MOD;
    "MINIMAL",MINIMAL;"MINIMAL_UNIQUE",MINIMAL_UNIQUE];;
let arithmetic_proof_observations () =
  map (fun (label,text,tac) ->
    let goal = parse_term text in
    checked_proof label goal (prove(goal,tac)))
   ["arith_induction","!n:num. n + 0 = n",INDUCT_TAC THEN ASM_REWRITE_TAC [ADD];
    "arith_cutoff","!n:num. n - n = 0",REWRITE_TAC [SUB_REFL];
    "arith_division","!n:num. n DIV 0 = 0 /\\ n MOD 0 = n",REWRITE_TAC [DIV_ZERO;MOD_ZERO];
    "arith_distributive","!a b c:num. a * (b + c) = a * b + a * c",REWRITE_TAC [LEFT_ADD_DISTRIB];
    "arith_order","!m n:num. m <= n /\\ n <= m ==> m = n",MESON_TAC [LE_ANTISYM];
    "arith_minimal","!n:num. (minimal m. m = n) = n",
      GEN_TAC THEN MATCH_MP_TAC MINIMAL_UNIQUE THEN BETA_TAC THEN
      REWRITE_TAC [] THEN MESON_TAC [LT_REFL]];;
let arithmetic_conversion_observations () =
  map (fun (label,conv,text,expected) -> execution_conversion label conv text expected)
   ["arith_mod_add",MOD_DOWN_CONV,"(m MOD p + n MOD p) MOD p","(m + n) MOD p";
    "arith_mod_suc",MOD_DOWN_CONV,"SUC ((m MOD n) MOD n) MOD n","SUC m MOD n";
    "arith_mod_mult",MOD_DOWN_CONV,"(m MOD n * p MOD n) MOD n","(m * p) MOD n";
    "arith_mod_exp",MOD_DOWN_CONV,"((m MOD n) EXP k) MOD n","(m EXP k) MOD n";
    "arith_cancel",NUM_CANCEL_CONV,"a + b + c = b + a + d","c = d:num";
    "arith_cancel_repeat",NUM_CANCEL_CONV,"a + b + a = b + a + c","a = c:num";
    "arith_cancel_zero",NUM_CANCEL_CONV,"a + b = a","b = 0:num";
    "arith_bits0",BITS_ELIM_CONV,"BIT0 m","2 * m";
    "arith_bits1",BITS_ELIM_CONV,"BIT1 m","2 * m + 1";
    "arith_bits_numeral",BITS_ELIM_CONV,"NUMERAL (BIT0 m)","2 * m"] @
  ["arith_cancel_invalid=" ^ bool_string (not (can NUM_CANCEL_CONV (parse_term "T")));
   "arith_numeral_unchanged=" ^ execution_conversion "numeral" BITS_ELIM_CONV "17" "17";
   "arith_mod_identity=" ^ execution_conversion "mod_identity" MOD_DOWN_CONV "m MOD n" "m MOD n"];;
let arithmetic_observations () =
  let groups = arithmetic_group_observations () in
  let theorems = arithmetic_theorem_observations () in
  let proofs = arithmetic_proof_observations () in
  let conversions = arithmetic_conversion_observations () in
  groups @ theorems @ proofs @ conversions;;
