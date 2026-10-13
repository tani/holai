(* Actual source tactics and justification closures, not replacement proofs. *)
let initial_tactical_observations =
  ["initial_rewrites=" ^ string_of_int (length (basic_rewrites ()));
   "initial_convs=" ^ string_of_int (length (basic_convs ()));
   "initial_congs=" ^ string_of_int (length (basic_congs ()));
   "falsity_definition=" ^ theorem_string _FALSITY_];;
let goal_string (asl,w) =
  String.concat ";" (map (fun (label,th) -> label ^ ":" ^ theorem_string th) asl) ^
  "?" ^ term_string w;;
let goalstate_string (_,goals,_) = String.concat " / " (map goal_string goals);;
let goalstack_string stack = String.concat " || " (map goalstate_string stack);;
let print_goal_string goal =
  let b = Buffer.create 16 in let fmt = Format.formatter_of_buffer b in
  let original_boxes = Format.pp_get_max_boxes fmt () in
  Format.pp_set_max_boxes fmt 64;
  pp_print_goal fmt goal;
  String.escaped (Buffer.contents b) ^ ":boxes=" ^ string_of_int original_boxes ^
  ":after=" ^ string_of_int (Format.pp_get_max_boxes fmt ());;
let print_stack_string stack =
  let b = Buffer.create 16 in let fmt = Format.formatter_of_buffer b in
  pp_print_goalstack fmt stack; Format.pp_print_flush fmt ();
  String.escaped (Buffer.contents b);;
let interactive_observations () =
  let first = set_goal([],parse_term "(p /\\ q) ==> q /\\ p") in
  let first_s = goalstack_string first in
  let discharged = e DISCH_TAC in let discharged_s = goalstack_string discharged in
  let split = e CONJ_TAC in let split_s = goalstack_string split in
  let printed = print_stack_string split in
  let rotated = r 1 in let rotated_s = goalstack_string rotated in
  let backed = b () in let backed_s = goalstack_string backed in
  let one = e (ASM_REWRITE_TAC []) in let one_s = goalstack_string one in
  let solved = e (ASM_REWRITE_TAC []) in let solved_s = goalstack_string solved in
  let theorem = top_thm () in
  current_goalstack := [];
  ["goal_initial=" ^ first_s;"goal_discharged=" ^ discharged_s;
   "goal_split=" ^ split_s;"goal_rotated=" ^ rotated_s;"goal_backed=" ^ backed_s;
   "goal_one=" ^ one_s;"goal_solved=" ^ solved_s;
   "goal_top_thm=" ^ theorem_string theorem;"print_stack=" ^ printed;
   "no_goal_refine=" ^ bool_string (not (can (fun () -> e ALL_TAC) ()))];;
let tactical_observations () =
  verbose := false;
  let p = parse_term "p:bool" and q = parse_term "q:bool" in
  let identity = parse_term "p ==> p" in
  let proof = prove(identity,DISCH_TAC THEN FIRST_ASSUM ACCEPT_TAC) in
  let bogus (_:goal) = null_meta,[],(fun _ [] -> TRUTH) in
  let proof_tests =
    ["prove_identity=" ^ theorem_string proof;
     "prove_THENL=" ^ theorem_string (prove(parse_term "p /\\ q ==> q /\\ p",
         DISCH_TAC THEN CONJ_TAC THENL
         [FIRST_ASSUM (ACCEPT_TAC o CONJUNCT2);FIRST_ASSUM (ACCEPT_TAC o CONJUNCT1)]));
     "prove_ORELSE=" ^ theorem_string (prove(identity,
         (FAIL_TAC "first" ORELSE DISCH_TAC) THEN FIRST_ASSUM ACCEPT_TAC));
     "prove_REPEAT=" ^ theorem_string (prove(parse_term "p ==> q ==> p",
         REPEAT DISCH_TAC THEN FIRST_ASSUM ACCEPT_TAC));
     "prove_GEN=" ^ theorem_string (prove(parse_term "!x:bool. x = x",GEN_TAC THEN REFL_TAC));
     "prove_EXISTS=" ^ theorem_string (prove(parse_term "?x:bool. x = x",
         EXISTS_TAC (parse_term "T") THEN REFL_TAC));
     "prove_THEN1=" ^ theorem_string (prove(identity,then1_ DISCH_TAC (FIRST_ASSUM ACCEPT_TAC)));
     "TAC_PROOF=" ^ theorem_string (TAC_PROOF((["hp",ASSUME p],p),FIRST_ASSUM ACCEPT_TAC));
     "bad_unfinished=" ^ bool_string (not (can prove (identity,DISCH_TAC)));
     "bad_THENL_count=" ^ bool_string (not (can prove
         (parse_term "T /\\ T",CONJ_TAC THENL [ACCEPT_TAC TRUTH])));
     "bad_THEN1_count=" ^ bool_string (not (can prove
         (parse_term "T /\\ T",then1_ CONJ_TAC (ACCEPT_TAC TRUTH))));
     "bad_justification=" ^ bool_string (not (can prove (parse_term "F",bogus)));
     "bad_VALID=" ^ bool_string (not (can (VALID bogus) ([],parse_term "F")));
     "bad_goal_type=" ^ bool_string (not (can mk_goalstate ([],parse_term "\\x:bool. x")));
     "print_goal=" ^ print_goal_string (["hp",ASSUME p],mk_imp(p,q))] in
  let intuitive = map (fun s -> "ITAUT:" ^ s ^ "=" ^ theorem_string (ITAUT (parse_term s)))
    ["p /\\ q ==> q /\\ p";"p \\/ q ==> q \\/ p";
     "(p ==> q) /\\ (q ==> r) ==> p ==> r";
     "p ==> ~ ~ p";"(p <=> q) ==> (q <=> p)";
     "p /\\ (q \\/ r) ==> (p /\\ q) \\/ (p /\\ r)";
     "(!x:bool. P x) ==> ?x:bool. P x"] in
  let atoms = [p;q;concl TRUTH;mk_conj(p,q)] in
  let grid = allpairs (fun a b ->
    "tactic_grid=" ^ theorem_string (ITAUT (mk_imp(mk_conj(a,b),mk_conj(b,a))))) atoms atoms in
  let id_def = new_definition (parse_term "test_tactic_id (z:bool) = z") in
  let term = parse_term "test_tactic_id (test_tactic_id (p:bool))" in
  let conditional = DISCH p (EQT_INTRO (DISCH q (ASSUME p))) in
  let rewrite_tests =
    ["REWRITE_CONV=" ^ theorem_string (REWRITE_CONV [id_def] term);
     "PURE_REWRITE_CONV=" ^ theorem_string (PURE_REWRITE_CONV [id_def] term);
     "ONCE_REWRITE_CONV=" ^ theorem_string (ONCE_REWRITE_CONV [id_def] term);
     "REWRITE_RULE=" ^ theorem_string (REWRITE_RULE [id_def] (REFL term));
     "REWRITE_TAC=" ^ theorem_string (prove(parse_term "test_tactic_id (p:bool) = p",REWRITE_TAC [id_def] THEN REFL_TAC));
     "SIMP_CONV=" ^ theorem_string (SIMP_CONV [id_def] term);
     "PURE_SIMP_CONV=" ^ theorem_string (PURE_SIMP_CONV [id_def] term);
     "ONCE_SIMP_CONV=" ^ theorem_string (ONCE_SIMP_CONV [id_def] term);
     "SIMP_RULE=" ^ theorem_string (SIMP_RULE [id_def] (REFL term));
     "SIMP_TAC=" ^ theorem_string (prove(parse_term "test_tactic_id (p:bool) = p",SIMP_TAC [id_def] THEN REFL_TAC));
     "conditional_simp=" ^ theorem_string (SIMP_CONV [conditional;ASSUME p] (mk_imp(q,p)));
     "ASM_SIMP_TAC=" ^ theorem_string (prove(parse_term "p ==> q ==> p",
          DISCH_TAC THEN ASM_SIMP_TAC [conditional]));
     "ASM_REWRITE_TAC=" ^ theorem_string (prove(identity,DISCH_TAC THEN ASM_REWRITE_TAC []))] in
  let old_rewrites = basic_rewrites () in
  set_basic_rewrites [id_def];
  let registered = REWRITE_CONV [] term in
  let registered_count = length (basic_rewrites ()) in
  set_basic_rewrites old_rewrites;
  let state = interactive_observations () in
  let scalar = Printf.sprintf "n=%d text=%s bool=%b %%" (-7) "plain" true in
  let staged = Printf.sprintf "%s:%d" "staged" in
  Printf.printf "printf_scalar=%s:%d%%\n%!" "plain" 7;
  initial_tactical_observations @ proof_tests @ intuitive @ grid @ rewrite_tests @ state @
    ["registered_rewrite=" ^ theorem_string registered;
     "registered_count=" ^ string_of_int registered_count;
     "restored_rewrites=" ^ string_of_int (length (basic_rewrites ()));
     "Printf_sprintf=" ^ scalar;"Printf_partial=" ^ staged 8;
     "Printf_zero=" ^ Printf.sprintf "literal%%"];;
