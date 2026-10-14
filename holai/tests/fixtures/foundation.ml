(* Actual original-source theory initialization, inductive definitions and MESON. *)
let initial_foundation_observations =
  ["initial_inductive_definitions=" ^ string_of_int (length (!the_inductive_definitions));
   "initial_monotonicity=" ^ string_of_int (length (!monotonicity_theorems));
   "initial_type_definitions=" ^ string_of_int (length (!the_type_definitions));
   "initial_inductive_types=" ^ String.concat ";" (map (fun (s,(n,_,_)) ->
      s ^ ":" ^ string_of_int n) (!inductive_type_store))];;

(* Normalize bound variable spelling only. Free names/types and the full
   hypotheses/conclusion remain observable. Conversions can allocate fresh
   binders in a different order under the accepted evaluation-order profile. *)
let rec bound_term_string bound tm =
  match tm with
    Var(_,ty) ->
      (try "b:" ^ string_of_int (index tm bound) ^ ":" ^ type_string ty
       with Failure _ -> term_string tm)
  | Const(_,_) -> term_string tm
  | Comb(f,x) -> "(" ^ bound_term_string bound f ^ " " ^ bound_term_string bound x ^ ")"
  | Abs(v,b) -> "(lambda :" ^ type_string (type_of v) ^ "." ^ bound_term_string (v::bound) b ^ ")";;
let bound_theorem_string th =
  String.concat "," (map (bound_term_string []) (hyp th)) ^ "|-" ^
  bound_term_string [] (concl th);;
let checked_proof label goal th =
  if hyp th <> [] || not (aconv goal (concl th))
  then failwith ("Invalid proof observation: " ^ label)
  else label ^ "=" ^ theorem_string th;;
let checked_conversion label conv text =
  let tm = parse_term text in
  let th = conv tm in let l,_ = dest_eq (concl th) in
  if hyp th <> [] || not (aconv l tm)
  then failwith ("Invalid conversion observation: " ^ label)
  else label ^ "=" ^ bound_theorem_string th;;
let bounded_meson ths goal =
  try prove(goal,GEN_MESON_TAC 0 12 1 ths)
  with Failure message -> failwith ("Bounded MESON: " ^ string_of_term goal ^ ": " ^ message);;

let classical_observations () =
  let standard = map (fun (name,th) -> name ^ "=" ^ theorem_string th)
    ["EQ_REFL",EQ_REFL; "EQ_SYM",EQ_SYM; "EQ_TRANS",EQ_TRANS;
     "CONJ_ASSOC",CONJ_ASSOC; "DISJ_ASSOC",DISJ_ASSOC;
     "MONO_FORALL",MONO_FORALL; "MONO_EXISTS",MONO_EXISTS;
     "ETA_AX",ETA_AX; "SELECT_AX",SELECT_AX; "EQ_EXT",EQ_EXT;
     "FUN_EQ_THM",FUN_EQ_THM; "EXCLUDED_MIDDLE",EXCLUDED_MIDDLE;
     "SELECT_REFL",SELECT_REFL; "SKOLEM_THM",SKOLEM_THM;
     "one_tydef",one_tydef; "one_DEF",one_DEF; "one",one;
     "one_INDUCT",one_INDUCT; "one_RECURSION",one_RECURSION;
     "one_Axiom",one_Axiom; "FORALL_ONE_THM",FORALL_ONE_THM;
     "EXISTS_ONE_THM",EXISTS_ONE_THM; "ETA_ONE",ETA_ONE] in
  let tauts = map (fun text -> let goal = parse_term text in
    checked_proof ("TAUT:" ^ text) goal (TAUT goal))
    ["p \\/ ~p"; "~ ~p ==> p"; "((p ==> q) ==> p) ==> p";
     "(p ==> q) <=> (~q ==> ~p)";
     "(if p then q else r) <=> (p /\\ q) \\/ (~p /\\ r)"] in
  let a = mk_var("a",aty) in
  let exists = EXISTS(parse_term "?x:A. x = a",a) (REFL a) in
  let selected = SELECT_RULE exists in
  let cases_goal = parse_term "p \\/ ~p" in
  let cases = prove(cases_goal,ASM_CASES_TAC (parse_term "p:bool") THEN ASM_REWRITE_TAC []) in
  let one_goal = parse_term "!x:1. x = one" in
  let one_proof = prove(one_goal,MATCH_ACCEPT_TAC one) in
  standard @ tauts @
    ["SELECT_RULE=" ^ theorem_string selected;
     checked_proof "ASM_CASES_TAC" cases_goal cases;
     checked_proof "one_proof" one_goal one_proof;
     checked_conversion "ETA_CONV" ETA_CONV "\\x:A. (f:A->B) x";
     checked_conversion "SELECT_CONV" SELECT_CONV "(@x:A. x = a) = a";
     "bad_ETA_CONV=" ^ bool_string (not (can ETA_CONV (parse_term "\\x:A. (f:A->A) (f x)")));
     "bad_SELECT_RULE=" ^ bool_string (not (can SELECT_RULE TRUTH))];;

let canonical_observations () =
  map (fun (label,conv,text) -> checked_conversion label conv text)
    ["canon_conj",CONJ_CANON_CONV,"q /\\ (p /\\ q) /\\ p";
     "canon_disj",DISJ_CANON_CONV,"q \\/ (p \\/ q) \\/ p";
     "canon_presimp",PRESIMP_CONV,"(T /\\ p) \\/ (F /\\ q)";
     "canon_nnf_imp",NNF_CONV,"~(p ==> q)";
     "canon_nnf_iff",NNF_CONV,"p <=> q";
     "canon_nnfc_iff",NNFC_CONV,"p <=> q";
     "canon_nnf_quant",NNF_CONV,"~(!x:A. P x ==> Q x)";
     "canon_nnf_exists",NNF_CONV,"~(?x:A. P x /\\ Q x)";
     "canon_skolem",SKOLEM_CONV,"!x:A. ?y:B. R x y";
     "canon_skolem_nested",SKOLEM_CONV,"!x:A. ?y:B. P x y /\\ (?z:C. Q y z)";
     "canon_prenex",PRENEX_CONV,"(!x:A. P x) /\\ (?y:B. Q y)";
     "canon_prenex_disj",PRENEX_CONV,"(?x:A. P x) \\/ (!y:B. Q y)";
     "canon_weak_dnf",WEAK_DNF_CONV,"(p \\/ q) /\\ (r \\/ s)";
     "canon_dnf",DNF_CONV,"(p \\/ q) /\\ (p \\/ r)";
     "canon_weak_cnf",WEAK_CNF_CONV,"(p /\\ q) \\/ (r /\\ s)";
     "canon_cnf",CNF_CONV,"(p /\\ q) \\/ (p /\\ r)";
     "canon_cond",CONDS_ELIM_CONV,"(P:A->bool) (if p then x else y)";
     "canon_cond_clausal",CONDS_CELIM_CONV,"(P:A->bool) (if p then x else y)";
     "canon_lambda",LAMBDA_ELIM_CONV,"(P:(A->A)->bool) (\\x:A. x)";
     "canon_assoc",ASSOC_CONV CONJ_ASSOC,"(p /\\ q) /\\ (r /\\ s)"];;

let inductive_observations () =
  let clauses = parse_term
    "(!x:A. test_reach (R:A->A->bool) x x) /\\ (!x y z. R x y /\\ test_reach R y z ==> test_reach R x z)" in
  let existence = prove_inductive_relations_exist clauses in
  let rules,induction,cases = new_inductive_definition clauses in
  let strong = derive_strong_induction(rules,induction) in
  let closed = forall (fun th -> hyp th = []) [existence;rules;induction;cases;strong] in
  if not closed then failwith "Inductive property has unproved hypotheses" else
  let reflexive = parse_term "!R:A->A->bool. !x. test_reach R x x" in
  let path = parse_term "!R:A->A->bool. !x y z. R x y /\\ R y z ==> test_reach R x z" in
  let reflexive_th = bounded_meson [rules] reflexive in
  let path_th = bounded_meson [rules] path in
  let mutual_clauses = parse_term
    "(!x:bool. (P:bool->bool) x ==> test_even P x) /\\ (!x:bool. test_even P x ==> test_odd P x) /\\ (!x:bool. test_odd P x ==> test_even P x)" in
  let mr,mi,mc = new_inductive_definition mutual_clauses in
  let ms = derive_strong_induction(mr,mi) in
  if not (forall (fun th -> hyp th = []) [mr;mi;mc;ms])
  then failwith "Mutual induction has unproved hypotheses" else
  ["ind_exists=" ^ bound_theorem_string existence;
   "ind_rules=" ^ bound_theorem_string rules;
   "ind_induction=" ^ bound_theorem_string induction;
   "ind_cases=" ^ bound_theorem_string cases;
   "ind_strong=" ^ bound_theorem_string strong;
   "ind_closed=" ^ bool_string closed;
   checked_proof "ind_reflexive" reflexive reflexive_th;
   checked_proof "ind_two_steps" path path_th;
   "ind_mutual_rules=" ^ bound_theorem_string mr;
   "ind_mutual_induction=" ^ bound_theorem_string mi;
   "ind_mutual_cases=" ^ bound_theorem_string mc;
   "ind_mutual_strong=" ^ bound_theorem_string ms;
   "ind_registry=" ^ string_of_int (length (!the_inductive_definitions));
   "ind_reach_type=" ^ type_string (get_const_type "test_reach");
   "ind_mutual_type=" ^ type_string (get_const_type "test_odd")];;

(* Restore every source search setting even if a bounded search fails. *)
let with_meson_profile depth prefine brand split work =
  let old_depth = !meson_depth and old_prefine = !meson_prefine
  and old_brand = !meson_brand and old_split = !meson_split_limit
  and old_dcutin = !meson_dcutin and old_skew = !meson_skew
  and old_chatty = !meson_chatty in
  let restore () =
    meson_depth := old_depth; meson_prefine := old_prefine;
    meson_brand := old_brand; meson_split_limit := old_split;
    meson_dcutin := old_dcutin; meson_skew := old_skew; meson_chatty := old_chatty in
  meson_depth := depth; meson_prefine := prefine; meson_brand := brand;
  meson_split_limit := split; meson_chatty := false;
  try let result = work () in restore (); result
  with ex -> restore (); raise ex;;
let meson_observations () =
  let texts =
    ["p \\/ ~p"; "~ ~p ==> p"; "((p ==> q) ==> p) ==> p";
     "!x:A. x = x";
     "(!x:A. P x ==> Q x) ==> (!x. P x) ==> (!x. Q x)";
     "(!x:A. P x ==> Q x) ==> (?x. P x) ==> (?x. Q x)";
     "(!x:A. P x ==> P (f x)) ==> P a ==> P (f (f a))";
     "(?x:A. !y:A. R x y) ==> (!y. ?x. R x y)";
     "!x y:A. x = y ==> (f:A->B) x = f y";
     "!x y z:A. x = y ==> y = z ==> x = z";
     "(if p then q else r) ==> (p ==> q) /\\ (~p ==> r)"] in
  let proofs = map (fun text -> let goal = parse_term text in
    checked_proof ("MESON:" ^ text) goal (bounded_meson [] goal)) texts in
  let rule_goal = parse_term "p /\\ q ==> q /\\ p" in
  let rule = MESON [] rule_goal in
  let ext_goal = parse_term "(!x:A. (f:A->B) x = g x) ==> f = g" in
  let ext = bounded_meson [EQ_EXT] ext_goal in
  let p = parse_term "p:bool" in
  let assumed = MESON [ASSUME p] p in
  if not (aconv (concl assumed) p && hyp assumed = [p])
  then failwith "MESON failed to preserve lemma hypotheses" else
  let profiles = map (fun (label,depth,prefine,brand,split,text) ->
    with_meson_profile depth prefine brand split (fun () ->
      let goal = parse_term text in
      checked_proof label goal (bounded_meson [] goal)))
    ["meson_depth",true,true,false,0,"(!x:A. P x ==> P (f x)) ==> P a ==> P (f (f a))";
     "meson_unrefined",false,false,false,0,"p /\\ q ==> q /\\ p";
     "meson_brand",false,true,true,0,"!x y:A. x = y ==> (f:A->B) x = f y";
     "meson_no_split",false,true,false,0,"(p \\/ q) /\\ ~p ==> q"] in
  let failures = map (fun text ->
    "meson_bounded_failure:" ^ text ^ "=" ^
    bool_string (not (can (fun goal -> prove(goal,GEN_MESON_TAC 0 2 1 [])) (parse_term text))))
    ["p:bool"; "F"; "!x:A. P x"; "?x:A. P x"] in
  proofs @ profiles @ failures @
    [checked_proof "MESON_rule" rule_goal rule;
     checked_proof "MESON_extensionality" ext_goal ext;
     "MESON_lemma_hypotheses=" ^ theorem_string assumed;
     "meson_settings=" ^ bool_string !meson_depth ^ ":" ^ bool_string !meson_prefine ^
       ":" ^ bool_string !meson_brand ^ ":" ^ string_of_int !meson_split_limit ^
       ":" ^ string_of_int !meson_dcutin ^ ":" ^ string_of_int !meson_skew ^
       ":" ^ bool_string !meson_chatty];;
let foundation_observations () =
  let old_verbose = !verbose in verbose := false;
  try
    let classical = classical_observations () in
    let canonical = canonical_observations () in
    let inductive = inductive_observations () in
    let meson = meson_observations () in
    Format.print_string "meson_flush="; Format.print_flush ();
    Format.print_string "ok"; Format.print_newline ();
    verbose := old_verbose;
    initial_foundation_observations @ classical @ canonical @ inductive @ meson
  with ex -> verbose := old_verbose; raise ex;;
