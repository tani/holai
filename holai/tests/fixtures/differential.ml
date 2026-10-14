(* Same observations are executed by original OCaml and translated Lisp. *)
let bool_string b = if b then "true" else "false";;
let int_list_string xs = String.concat "," (map string_of_int xs);;
let rec type_string = function
  Tyvar s -> "'" ^ s
  | Tyapp(s,args) -> s ^ "(" ^ String.concat "," (map type_string args) ^ ")";;
let rec term_string = function
  Var(s,t) -> "v:" ^ s ^ ":" ^ type_string t
  | Const(s,t) -> "c:" ^ s ^ ":" ^ type_string t
  | Comb(f,x) -> "(" ^ term_string f ^ " " ^ term_string x ^ ")"
  | Abs(v,b) -> "(lambda " ^ term_string v ^ "." ^ term_string b ^ ")";;
let theorem_string th =
  String.concat "," (map term_string (hyp th)) ^ "|-" ^ term_string (concl th);;
let observations () =
  let p = mk_var("p",bool_ty) and q = mk_var("q",bool_ty) in
  let fx = mk_var("f",mk_fun_ty bool_ty bool_ty) in
  let cap = mk_abs(q,p) in
  let vx = mk_var("x",aty) and vy = mk_var("x",bty) in
  let numbers = (--) 0 20 in
  let fp = (|->) 3 9 ((|->) 1 7 ((|=>) 2 8)) in
  let lib_tests =
    ["map=" ^ int_list_string (map inc numbers);
     "fold=" ^ string_of_int (itlist (+) numbers 0);
     "sort=" ^ int_list_string (sort (<=) [4;1;3;1;2]);
     "setify=" ^ int_list_string (setify [4;1;3;1;2]);
     "qmap_identity=" ^ bool_string (qmap I numbers == numbers);
     "fp_graph=" ^ String.concat ";" (map (fun (x,y) -> string_of_int x ^ ":" ^ string_of_int y) (graph fp));
     "fp_get=" ^ string_of_int (apply fp 3);
     "fp_removed=" ^ bool_string (not (defined (undefine 3 fp) 3));
     "num=" ^ string_of_num (num_of_string "0x2a");
     "hex=" ^ string_of_num_hex (num 65535);
     "gcd=" ^ string_of_int (gcd (-84) 30);
     "higher=" ^ string_of_int (higher add 2 5);
     "staged=" ^ string_of_int (staged add);
     "over=" ^ string_of_int (overapplication ());
     "unit=" ^ string_of_int (pass_unit unit_fn);
     "pair=" ^ string_of_int (pair_fn answer_pair);
     "pattern_shadow=" ^ string_of_int (pattern_shadow (3,4) 9);
     "negate=" ^ string_of_int (negate 7) ^ "," ^ string_of_int (subtract_op 10 3);
     "shadow=" ^ string_of_int (g 2) ^ "," ^ string_of_int (old 2) ^ "," ^ string_of_int (f 2);
     "parallel=" ^ string_of_int (parallel ());
     "lexical=" ^ string_of_int (lexical ());
     "local_nonrec=" ^ string_of_int (local_nonrec ());
     "local_cl_functions=" ^ string_of_int (local_cl_functions ());
     "local_syntax_function=" ^ string_of_int (local_syntax_function ());
     "parent_capture=" ^ string_of_int (parent_capture ());
     "rec=" ^ bool_string (even 20) ^ "," ^ bool_string (local_mutual 19);
     "patterns=" ^ string_of_int (inspect (One 3)) ^ "," ^ string_of_int (inspect (Pair(4,9))) ^ "," ^ string_of_int (inspect (Fields(5,8)));
     "alias=" ^ string_of_int (alias (Pair(4,9)));
     "exceptions=" ^ string_of_int (catch (-3)) ^ "," ^ string_of_int (nested_catch ());
     "chars=" ^ string_of_int (char_match 'a') ^ "," ^ string_of_int (char_match 'z');
     "radices=" ^ string_of_int hex ^ "," ^ string_of_int binary ^ "," ^ string_of_int octal]
  in
  let kernel_tests =
    ["type_subst=" ^ type_string (type_subst [bool_ty,aty] (mk_fun_ty aty bty));
     "type_identity=" ^ bool_string (type_subst [] (type_of fx) == type_of fx);
     "capture=" ^ term_string (vsubst [q,p] cap);
     "inst_capture=" ^ term_string (inst [bool_ty,aty;bool_ty,bty] (mk_abs(vx,vy)));
     "alpha=" ^ bool_string (aconv (mk_abs(p,p)) (mk_abs(q,q)));
     "REFL=" ^ theorem_string (REFL p);
     "TRANS=" ^ theorem_string (TRANS (REFL p) (REFL p));
     "MK_COMB=" ^ theorem_string (MK_COMB(REFL fx,REFL p));
     "ABS=" ^ theorem_string (ABS p (REFL p));
     "BETA=" ^ theorem_string (BETA (mk_comb(mk_abs(p,p),p)));
     "ASSUME=" ^ theorem_string (ASSUME p);
     "EQ_MP=" ^ theorem_string (EQ_MP (REFL p) (ASSUME p));
     "DEDUCT=" ^ theorem_string (DEDUCT_ANTISYM_RULE (ASSUME p) (ASSUME q));
     "INST=" ^ theorem_string (INST [q,p] (ASSUME p));
     "INST_TYPE=" ^ theorem_string (INST_TYPE [bool_ty,aty] (REFL vx));
     "bad_comb=" ^ bool_string (not (can mk_comb (p,q)));
     "bad_assume=" ^ bool_string (not (can ASSUME vx));
     "bad_TRANS=" ^ bool_string (not (can (TRANS (REFL p)) (REFL q)));
     "frees=" ^ String.concat "," (map term_string (frees cap))]
  in
  let grid = allpairs (fun x y ->
    "sum:" ^ string_of_int x ^ ":" ^ string_of_int y ^ "=" ^ string_of_int (higher add x y)) numbers numbers in
  let d = new_basic_definition (mk_eq(mk_var("test_id",mk_fun_ty bool_ty bool_ty),mk_abs(p,p))) in
  let predicate = mk_abs(p,mk_eq(p,p)) in
  let witness = new_axiom (mk_comb(predicate,q)) in
  let td1,td2 = new_basic_type_definition "test_type" ("test_abs","test_rep") witness in
  lib_tests @ kernel_tests @ grid @
    ["definition=" ^ theorem_string d;"typedef1=" ^ theorem_string td1;"typedef2=" ^ theorem_string td2];;
