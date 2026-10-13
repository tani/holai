(* Snapshot the real logical initialization before test-only extensions. *)
let schematic_type_name names s =
  if String.length s > 1 && s.[0] = '?' &&
     List.for_all (fun c -> c >= "0" && c <= "9") (explode (String.sub s 1 (String.length s - 1)))
  then try assoc s !names with Failure _ ->
    let name = "?t" ^ string_of_int (length !names) in names := (s,name) :: !names; name
  else s;;
let rec schematic_type_string names = function
  Tyvar s -> "'" ^ schematic_type_name names s
  | Tyapp(s,args) ->
    let rendered = List.map (schematic_type_string names) args in
    s ^ "(" ^ String.concat "," rendered ^ ")";;
let generated_registry_binder s =
  String.length s > 9 && String.sub s 0 9 = "GEN%PVAR%" &&
  List.for_all (fun c -> c >= "0" && c <= "9") (explode (String.sub s 9 (String.length s - 9)));;
let rec schematic_term_string names bound = function
  Var(s,t) as tm ->
    let ty = schematic_type_string names t in
    if generated_registry_binder s && mem tm bound
    then "b:" ^ string_of_int (index tm bound) ^ ":" ^ ty
    else "v:" ^ s ^ ":" ^ ty
  | Const(s,t) -> "c:" ^ s ^ ":" ^ schematic_type_string names t
  | Comb(f,x) ->
    let left = schematic_term_string names bound f in let right = schematic_term_string names bound x in
    "(" ^ left ^ " " ^ right ^ ")"
  | Abs(v,b) ->
    let variable =
      if generated_registry_binder (fst(dest_var v))
      then ":" ^ schematic_type_string names (type_of v)
      else schematic_term_string names bound v in
    let body = schematic_term_string names (v::bound) b in
    "(lambda " ^ variable ^ "." ^ body ^ ")";;
let schematic_theorem_string th =
  let names = ref [] in
  let assumptions = List.map (schematic_term_string names []) (hyp th) in
  let conclusion = schematic_term_string names [] (concl th) in
  String.concat "," assumptions ^ "|-" ^ conclusion;;
let initial_logic_observations =
  ["init_types=" ^ String.concat ";" (map (fun (s,n) -> s ^ ":" ^ string_of_int n) (types()));
   "init_constants=" ^ String.concat ";" (map (fun (s,ty) -> s ^ ":" ^ schematic_type_string (ref []) ty) (constants()));
   "init_definitions=" ^ String.concat ";" (map schematic_theorem_string (definitions()));
   "init_axioms=" ^ String.concat ";" (map theorem_string (axioms()));
   "TRUTH=" ^ theorem_string TRUTH];;
let instantiation_string (counts,tmins,tyins) =
  "beta=" ^ String.concat ";" (map (fun (n,t) -> string_of_int n ^ ":" ^ term_string t) counts) ^
  "|terms=" ^ String.concat ";" (map (fun (t,v) -> term_string v ^ "->" ^ term_string t) tmins) ^
  "|types=" ^ String.concat ";" (map (fun (t,v) -> type_string v ^ "->" ^ type_string t) tyins);;
let callback_format_observations () =
  let custom fmt (n,s) = Format.pp_print_string fmt (s ^ string_of_int n) in
  let finish = Format.asprintf "type=%a; %d %s %b %%" pp_print_type (mk_fun_ty bool_ty bool_ty) in
  let b = Buffer.create 8 in let fmt = Format.formatter_of_buffer b in
  let emit = Format.fprintf fmt "item=%a:%d" custom (7,"n") in
  emit 9; Format.pp_print_flush fmt ();
  ["asprintf=" ^ finish 4 "text" true;
   "fprintf=" ^ Buffer.contents b;
   "format_zero=" ^ String.escaped (Format.asprintf "plain%%\n");
   "format_thunk=" ^ Format.asprintf "%t" (fun fmt -> Format.pp_print_string fmt "thunk");
   "format_flush=" ^ Format.asprintf "%s%!%s" "first" "second";
   "format_two=" ^ Format.asprintf "%a / %a" pp_print_type bool_ty pp_print_type (mk_fun_ty bool_ty bool_ty)];;
let logic_observations () =
  let p = mk_var("p",bool_ty) and q = mk_var("q",bool_ty) in
  let x = mk_var("x",bool_ty) and y = mk_var("y",bool_ty) in
  let f = mk_var("f",mk_fun_ty bool_ty bool_ty) in
  let beta = mk_comb(mk_abs(x,mk_comb(f,x)),p) in
  let nested = mk_comb(f,mk_comb(mk_abs(x,x),p)) in
  let forall = GEN x (REFL x) in
  let existential = mk_exists(x,mk_eq(x,x)) in
  let exists_th = EXISTS(existential,p) (REFL p) in
  let choose_th = CHOOSE(y,exists_th) (ADD_ASSUM (mk_eq(y,y)) (REFL p)) in
  let imp_th = DISCH p (CONJ (ASSUME p) (ASSUME q)) in
  let poly = mk_var("u",aty) in
  let mi = term_match [] poly p in
  let pattern = mk_abs(x,mk_comb(f,x)) in
  let target = mk_abs(y,mk_conj(y,y)) in
  let hi = term_match [] pattern target in
  let ui = term_unify [p;q] (mk_conj(p,q)) (mk_conj(q,p)) in
  let ti = term_type_unify poly p ([],[],[]) in
  let general = GEN x (DISCH (mk_eq(x,x)) (REFL x)) in
  let ax = ASSUME (mk_eq(p,p)) in
  let pm = PART_MATCH (fst o dest_imp) general (mk_eq(p,p)) in
  let cache_calls = ref 0 in
  let cached = CACHE_CONV (fun tm -> cache_calls := !cache_calls + 1; BETA_CONV tm) in
  let cache_one = cached beta in let cache_two = cached beta in
  let proof_tests =
    ["BETA_CONV=" ^ theorem_string (BETA_CONV beta);
     "case_shadow=" ^ string_of_int (case_shadow ());
     "case_function_shadow=" ^ string_of_int (case_function_shadow ());
     "case_parallel_functions=" ^ string_of_int (case_parallel_functions ());
     "conversion_chain=" ^ theorem_string ((BETA_CONV THENC ALL_CONV) beta);
     "RAND_CONV=" ^ theorem_string (RAND_CONV BETA_CONV nested);
     "DEPTH_CONV=" ^ theorem_string (DEPTH_CONV BETA_CONV nested);
     "conversion_fallback=" ^ theorem_string ((NO_CONV ORELSEC ALL_CONV) p);
     "SYM=" ^ theorem_string (SYM (ASSUME (mk_eq(p,q))));
     "SUBS=" ^ theorem_string (SUBS [ASSUME (mk_eq(p,q))] (REFL p));
     "CONJ=" ^ theorem_string (CONJ (ASSUME p) (ASSUME q));
     "CONJUNCT1=" ^ theorem_string (CONJUNCT1 (CONJ (ASSUME p) (ASSUME q)));
     "CONJUNCT2=" ^ theorem_string (CONJUNCT2 (CONJ (ASSUME p) (ASSUME q)));
     "DISCH=" ^ theorem_string imp_th;
     "MP=" ^ theorem_string (MP imp_th (ASSUME p));
     "UNDISCH=" ^ theorem_string (UNDISCH imp_th);
     "SPEC=" ^ theorem_string (SPEC p forall);
     "GEN=" ^ theorem_string forall;
     "ISPEC=" ^ theorem_string (ISPEC p (GEN poly (REFL poly)));
     "EXISTS=" ^ theorem_string exists_th;
     "CHOOSE=" ^ theorem_string choose_th;
     "DISJ_CASES=" ^ theorem_string (DISJ_CASES (DISJ1 (ASSUME p) q)
         (DISCH p (ASSUME p)) (DISCH p (ASSUME p)));
     "EQT_roundtrip=" ^ theorem_string (EQT_ELIM (EQT_INTRO (ASSUME p)));
     "negation_roundtrip=" ^ theorem_string (NOT_INTRO (NOT_ELIM (ASSUME (mk_neg p))));
     "PROVE_HYP=" ^ theorem_string (PROVE_HYP TRUTH (CONJ (ASSUME (concl TRUTH)) (ASSUME p)));
     "PART_MATCH=" ^ theorem_string pm;
     "MATCH_MP=" ^ theorem_string (MATCH_MP general ax);
     "term_match=" ^ instantiation_string mi;
     "instantiate=" ^ term_string (instantiate mi poly);
     "higher_match=" ^ instantiation_string hi;
     "higher_instantiation=" ^ term_string (instantiate hi pattern);
     "higher_match_valid=" ^ bool_string (aconv (instantiate hi pattern) target);
     "term_unify=" ^ instantiation_string ui;
     "term_unify_valid=" ^ bool_string (aconv (instantiate ui (mk_conj(p,q))) (instantiate ui (mk_conj(q,p))));
     "type_unify=" ^ String.concat ";" (map (fun (t,v) -> type_string v ^ "->" ^ type_string t)
          (type_unify (mk_fun_ty aty bty) (mk_fun_ty bool_ty bool_ty) []));
     "term_type_unify=" ^ instantiation_string ti;
     "INSTANTIATE=" ^ theorem_string (INSTANTIATE mi (REFL poly));
     "CACHE_CONV=" ^ theorem_string cache_one ^ ":" ^ theorem_string cache_two ^ ":" ^ string_of_int !cache_calls;
     "bad_MP=" ^ bool_string (not (can (MP imp_th) (ASSUME q)));
     "bad_GEN=" ^ bool_string (not (can (GEN p) (ASSUME p)));
     "bad_SPEC=" ^ bool_string (not (can (SPEC f) forall));
     "bad_CHOOSE=" ^ bool_string (not (can (CHOOSE(y,exists_th)) (REFL y)));
     "bad_CONJUNCT=" ^ bool_string (not (can CONJUNCT1 (ASSUME p)));
     "bad_term_occurs=" ^ bool_string (not (can (term_unify [p] p) (mk_comb(f,p))));
     "bad_type_occurs=" ^ bool_string (not (can (type_unify aty (mk_fun_ty aty bool_ty)) []));
     "bad_local_match=" ^ bool_string (not (can (term_match [p] p) q));
     "bad_definition_arg=" ^ bool_string (not (can new_definition (parse_term "bad_arg T = T")));
     "bad_definition_free=" ^ bool_string (not (can new_definition (parse_term "bad_free = (p:bool)")))] in
  let atoms = [p;q;concl TRUTH;parse_term "F";mk_conj(p,q);mk_imp(p,q)] in
  let grid = allpairs (fun a b ->
    "logical_grid=" ^ theorem_string (DISCH a (CONJ (ASSUME a) (ASSUME b)))) atoms atoms in
  let definition = new_definition (parse_term "test_logic_id (z:bool) = z") in
  let definition_instance = SPEC p definition in
  Format.printf "printed_conversion=";
  let printed = PRINT_TERM_CONV p in
  Format.pp_print_flush Format.std_formatter ();
  initial_logic_observations @ proof_tests @ grid @ callback_format_observations () @
    ["new_definition=" ^ theorem_string definition;
     "definition_instance=" ^ theorem_string definition_instance;
     "definition_const=" ^ type_string (get_const_type "test_logic_id");
     "PRINT_TERM_CONV=" ^ theorem_string printed];;
