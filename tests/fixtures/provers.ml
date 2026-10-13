(* Real first-order provers, state restoration, quotient/lifting and tactics. *)
let rec fol_string = function
  Fvar n -> "v" ^ string_of_int n
  | Fnapp(n,args) -> "f" ^ string_of_int n ^ "(" ^ String.concat "," (List.map fol_string args) ^ ")";;
let substitution_string xs = String.concat ";" (List.map (fun (n,t) ->
  string_of_int n ^ ":" ^ fol_string t) xs);;
let firstorder_observations () =
  Mapping.reset_vars (); Mapping.reset_consts ();
  let term = parse_term "(f:bool->bool) x" in
  let fol = Mapping.fol_of_term [] [] term in
  let original_x = parse_term "x:bool" in
  let x_code = Mapping.fol_of_var original_x in
  let fresh_x = Mapping.hol_of_var x_code bool_ty in
  let reconstructed = vsubst [original_x,fresh_x] (Mapping.hol_of_term bool_ty fol) in
  let rest = Utils.List.list_rest [1;2;3] in
  let rest_s = String.concat ";" (List.map (fun (n,(before,after)) ->
    string_of_int n ^ ":" ^ int_list_string before ^ "|" ^ int_list_string after) rest) in
  let sub0 = Substarray.empty 16 in
  let sub1 = Substarray.unify_tms sub0 [Fvar 0] [Fnapp(7,[])] in
  let first = substitution_string (Substarray.to_list sub1) in
  let sub2 = Substarray.unify_tms sub0 [Fvar 0] [Fnapp(9,[])] in
  let restored = substitution_string (Substarray.to_list sub2) in
  let pure = Substlist.unify_tms (Substlist.empty 16) [Fvar 0;Fvar 1] [Fvar 1;Fnapp(5,[])] in
  let occurs = try
    ignore (Substlist.unify_tms (Substlist.empty 16) [Fvar 0] [Fnapp(5,[Fvar 0])]); false
    with Substlist.Unify -> true in
  let stream = Strom.append (Strom.of_list [1;2]) (Strom.of_list [3]) in
  let values = Strom.to_list (Strom.map (fun n -> n+10) (Strom.take 3 stream)) in
  let empty_stream = Strom.of_list [] in
  ["fol_term=" ^ fol_string fol;
   "fol_roundtrip=" ^ term_string reconstructed ^ ":" ^ bool_string (aconv term reconstructed);
   "fol_fresh_type=" ^ type_string (type_of fresh_x) ^ ":" ^
     bool_string (Mapping.hol_of_var x_code bool_ty == fresh_x);
   "firstorder_list_rest=" ^ rest_s;
   "subst_array_first=" ^ first;
   "subst_array_restored=" ^ restored;
   "subst_list=" ^ substitution_string pure;
   "subst_list_instantiated=" ^ fol_string (Substlist.inst_tm pure (Fvar 0));
   "subst_occurs=" ^ bool_string occurs;
   "stream_values=" ^ int_list_string values;
   "stream_exhausted=" ^ bool_string (Strom.next_opt empty_stream = None);
   "metis_option=" ^ string_of_int (Metis_prover.Option.value (Some 4) ~default:9) ^ ":" ^
     string_of_int (Metis_prover.Option.value None ~default:9);
   "metis_formula_boolean=" ^ bool_string (Metis_prover.Formula.mkBoolean true <> Metis_prover.Formula.mkBoolean false)];;
let prover_proof label prover text =
  let goal = parse_term text in
  try checked_proof (label ^ ":" ^ text) goal (prover [] goal)
  with Failure message -> failwith (label ^ ": " ^ text ^ ": " ^ message);;
let additional_proof_observations () =
  let texts =
    ["p /\\ q ==> q /\\ p"; "p \\/ ~p";
     "(p ==> q) /\\ (q ==> r) ==> p ==> r";
     "(!x:A. P x ==> Q x) ==> (?x. P x) ==> (?x. Q x)";
     "(!x:A. P x ==> P (f x)) ==> P a ==> P (f a)";
     "!x y:A. x = y ==> (f:A->B) x = f y"] in
  let metis = List.map (prover_proof "METIS" METIS) texts in
  let lean = List.map (prover_proof "LEANCOP" LEANCOP) texts in
  let nano_texts = Utils.List.take 5 texts @ ["!x y:A. x = y ==> y = x"] in
  let nano = List.map (prover_proof "NANOCOP" NANOCOP) nano_texts in
  let p = parse_term "p:bool" in
  let lemma name tactic =
    let th = TAC_PROOF((["hp",ASSUME p],p),tactic) in
    if concl th <> p || hyp th <> [p] then failwith ("Lemma hypotheses: " ^ name)
    else name ^ "_lemma=" ^ theorem_string th in
  let metis_hyp = lemma "METIS" (ASM_METIS_TAC []) in
  let lean_hyp = lemma "LEANCOP" (Leancop.GEN_LEANCOP_TAC Cop.search_opts []) in
  let nano_hyp = lemma "NANOCOP" (Nanocop.GEN_NANOCOP_TAC Cop.search_opts []) in
  let metis_extra = not (can (METIS [ASSUME p]) p) in
  let lean_extra = not (can (LEANCOP [ASSUME p]) p) in
  let nano_extra = not (can (NANOCOP [ASSUME p]) p) in
  (* Empty clause saturation and bounded/exhausted search, no unbounded
     connection-prover invocation on an unprovable formula. *)
  let metis_empty = not (can Metis_prover.Loop.run []) in
  Mapping.reset_vars (); Mapping.reset_consts (); Database.axioms2db [];
  let bounded_lean = Cop.deepen_to 2 (Leancop.start Cop.search_opts) 0 in
  metis @ lean @ nano @
    [metis_hyp;lean_hyp;nano_hyp;
     "METIS_rejects_extra_hyp=" ^ bool_string metis_extra;
     "LEANCOP_rejects_extra_hyp=" ^ bool_string lean_extra;
     "NANOCOP_rejects_extra_hyp=" ^ bool_string nano_extra;
     "metis_empty_failure=" ^ bool_string metis_empty;
     "leancop_bounded_empty=" ^ bool_string (bounded_lean = None)];;
let quotient_observations () =
  let eq_def = new_definition (parse_term "test_qeq (x:bool) y <=> (x = y)") in
  let refl = prove(parse_term "!x:bool. test_qeq x x",REWRITE_TAC [eq_def]) in
  let sym = prove(parse_term "!x y:bool. test_qeq x y <=> test_qeq y x",REWRITE_TAC [eq_def;EQ_SYM_EQ]) in
  let trans = bounded_meson [eq_def] (parse_term "!x y z:bool. test_qeq x y /\\ test_qeq y z ==> test_qeq x z") in
  let bij = define_quotient_type "test_quot" ("test_qabs","test_qrep") (parse_term "test_qeq") in
  let well = bounded_meson [eq_def] (parse_term "!x x':bool. test_qeq x x' ==> test_qeq (~x) (~x')") in
  let definition,lifted = lift_function (snd bij) (refl,trans) "test_qnot" well in
  let original = prove(parse_term "!x:bool. test_qeq (~ ~x) x",REWRITE_TAC [eq_def;NOT_CLAUSES]) in
  let double_not = lift_theorem bij (refl,sym,trans) [lifted] original in
  if not (forall (fun th -> hyp th = []) [fst bij;snd bij;definition;lifted;double_not])
  then failwith "Quotient/lifted theorem has unproved hypotheses" else
  if not (aconv (concl double_not) (parse_term "!x:test_quot. test_qnot (test_qnot x) = x"))
  then failwith "Lifted double negation has the wrong conclusion" else
  ["quot_relation=" ^ theorem_string eq_def;
   "quot_abs=" ^ bound_theorem_string (fst bij);
   "quot_rep=" ^ bound_theorem_string (snd bij);
   "quot_definition=" ^ bound_theorem_string definition;
   "quot_lifted=" ^ bound_theorem_string lifted;
   "quot_double_not=" ^ bound_theorem_string double_not;
   "quot_operator_type=" ^ type_string (get_const_type "test_qnot");
   "quot_type=" ^ string_of_int (get_type_arity "test_quot")];;
let implicational_observations () =
  let stage name f = try f () with Failure message -> failwith (name ^ ": " ^ message) in
  let p_definition = new_definition (parse_term "test_imp_p = T") in
  let q_definition = new_definition (parse_term "test_imp_q = T") in
  let predicate_definition = new_definition (parse_term "test_imp_pred (x:bool) = x") in
  let p = parse_term "test_imp_p" in let q = parse_term "test_imp_q" in
  let implication = ASSUME (mk_imp(p,q)) in
  let simple_goal = parse_term "p /\\ q ==> q" in
  let rewrite = prove(simple_goal,IMP_REWRITE_TAC [] THEN ITAUT_TAC) in
  let assumed_goal = parse_term "p ==> q ==> p" in
  let sequence = prove(assumed_goal,SEQ_IMP_REWRITE_TAC [] THEN ITAUT_TAC) in
  let forward = stage "IMP_REWRITE_assumed" (fun () -> TAC_PROOF((["hp",ASSUME p],q),IMP_REWRITE_TAC [implication] THEN ASM_REWRITE_TAC [])) in
  let target = stage "TARGET_REWRITE_assumed" (fun () -> TAC_PROOF((["hp",ASSUME p],q),TARGET_REWRITE_TAC [implication] (ASSUME p) THEN ASM_REWRITE_TAC [])) in
  let hint_goal = parse_term "test_imp_pred T ==> ?x:bool. test_imp_pred x" in
  let hint = stage "HINT_EXISTS_TAC" (fun () -> prove(hint_goal,REPEAT DISCH_TAC THEN HINT_EXISTS_TAC THEN ASM_MESON_TAC [])) in
  let unchanged = not (can (IMP_REWRITE_TAC []) ([],parse_term "p:bool")) in
  ["IMP_definitions=" ^ String.concat ";" (List.map theorem_string [p_definition;q_definition;predicate_definition]);
   checked_proof "IMP_REWRITE_TAC" simple_goal rewrite;
   checked_proof "SEQ_IMP_REWRITE_TAC" assumed_goal sequence;
   "IMP_REWRITE_assumed=" ^ theorem_string forward;
   "TARGET_REWRITE_assumed=" ^ theorem_string target;
   checked_proof "HINT_EXISTS_TAC" hint_goal hint;
   "IMP_REWRITE_unchanged=" ^ bool_string unchanged];;
let provers_observations () =
  let old_verbose = !verbose and old_cop = !copverb and old_metis = !metisverb in
  let restore () = verbose := old_verbose; copverb := old_cop; metisverb := old_metis in
  verbose := false; copverb := false; metisverb := false;
  try
    let firstorder = firstorder_observations () in
    let proofs = additional_proof_observations () in
    let quotients = quotient_observations () in
    let implications = implicational_observations () in
    restore (); firstorder @ proofs @ quotients @ implications
  with ex -> restore (); raise ex;;
