open MLast
open Scope
open Sexp
let let_form head bindings bodies =
 let names=List.map (function List (name::_) -> name | _ -> assert false) bindings in
 form head (l bindings :: form "cl:declare" [form "cl:ignorable" names] :: bodies)
let rec local_function_groups = function
 | Origin (origin,node) when origin.rule="let" ->
   Option.map (fun (groups,body,origins) -> groups,body,origin::origins) (local_function_groups node)
 | List [Atom head;List definitions;body] ->
   if head="labelsc" || head="holai.runtime:labelsc"
   then Some (definitions,body,[]) else None
 | _ -> None
let combine_local_functions head functions body =
 match local_function_groups body with
 | None -> form head [l functions;body]
 | Some (inner,body,origins) ->
   let combined=form head [l (functions@inner);body] in
   (* Flatten only named-function let scopes; every original let retains its
      Origin on the combined form, and all annotated function bodies survive. *)
   List.fold_right (fun origin form -> Origin (origin,form)) origins combined
let rec module_function_group = function
 | Origin (origin,node) when origin.rule="local-module-binding" ->
   Option.map (fun (definitions,body,origins) -> definitions,body,origin::origins)
     (module_function_group node)
 | List [Atom head;List definitions;body] when head="labelsc" || head="holai.runtime:labelsc" ->
   Some (definitions,body,[])
 | _ -> None
let combine_module_functions head functions body =
 match module_function_group body with
 | None -> form head [l functions;body]
 | Some (inner,body,origins) ->
   let combined=form head [l (functions@inner);body] in
   List.fold_right (fun origin form -> Origin (origin,form)) origins combined
let lexical_targets env =
 let visited=ref [] in
 let rec collect env targets =
   if List.exists (fun previous -> previous==env) !visited then targets else (
     visited:=env:: !visited;
     let targets=SM.fold (fun _ (b:binding) targets ->
       if b.package="" then SS.add b.logical targets else targets) env.values targets in
     SM.fold (fun _ m targets -> collect m.public targets) env.modules targets) in
 collect env SS.empty
let rec expression_spine = function
 | ExApp (_,f,x) -> let h,xs=expression_spine f in h,xs@[x]
 | e -> e,[]
let rec pattern_spine = function
 | PaApp (_,f,x) -> let h,xs=pattern_spine f in h,xs@[x]
 | p -> p,[]
let rec strip_pattern = function PaTyc (_,p,_) -> strip_pattern p | p -> p
let patt_id = function
 | PaLid (_,s) -> Some (v s) | PaLong (_,p,_) -> Some (longid p)
 | _ -> None
let rec label_id = function
 | PaPfx (_,li,p) -> Option.map (fun name -> longid li^"."^name) (label_id p)
 | p -> patt_id (strip_pattern p)
type body = Expression of expr | Cases of case_branch list
let rec split_function = function
 | ExFun (_,cs) -> (match v cs with
   | [p,g,e] when v g=None -> let ps,b=split_function e in p::ps,b
   | cs -> [PaAny Ploc.dummy],Cases cs)
 | ExTyc (_,e,_) -> split_function e
 | e -> [],Expression e
let arity e = List.length (fst (split_function e))
let named_function_bindings bindings =
 List.for_all (fun (p,e,_) -> match strip_pattern p with PaLid _ -> arity e>0 | _ -> false) bindings
let rec closure_initializer = function
 | ExFun _ -> true | ExLet (_,_,_,body) | ExTyc (_,body,_) -> closure_initializer body
 | _ -> false
let check_recursive_patterns loc bindings =
 if not (List.for_all (fun (p,_,_) -> match strip_pattern p with PaLid _ -> true | _ -> false) bindings)
 then error loc "Recursive pattern binding is not supported"
let required_parameter = function
 | PaLab (loc,ps) -> (match v ps with [label,p] ->
     (match patt_id label with Some name -> Some name,Option.value (v p) ~default:label
      | None -> error loc "Unsupported labelled parameter")
     | _ -> error loc "Grouped labelled parameters are unsupported")
 | PaOlb (loc,_,_) -> error loc "Optional parameters are unsupported"
 | p -> None,p
let parameter_labels e = List.map (fun p -> fst (required_parameter p)) (fst (split_function e))
let labelled_binding (b:binding) e = {b with labels=parameter_labels e}
let local_module_emitter : (context -> env -> string -> module_expr -> modul * (Sexp.t -> Sexp.t)) option ref = ref None
let native_function (b:binding) =
 b.package="cl" || b.package="holai.runtime" || match b.kind with Constructor _ -> true | _ -> false
let function_ref c b n =
 if native_function b then
  form (runtime c "function-value") [a ("#'"^reference c b); a (string_of_int n)]
 else a ("#'"^reference c b)
let call_value fn args = l (reader_prefix fn::args)
let rec callable c b args = match b.kind with
 | Function n ->
   if not (native_function b) then form (reference c b) args
   else if List.length args=n then form (reference c b) args
   else if List.length args<n then form (runtime c "partial") (function_ref c b n::args)
   else let first=List.filteri (fun i _ -> i<n) args and rest=List.filteri (fun i _ -> i>=n) args in
     call_value (form (reference c b) first) rest
 | Value -> call_value (a (reference c b)) args
 | Constructor _ -> assert false
let constructor_args loc k args get_tuple make_tuple =
 let args=match args with [x] when k.fields>1 -> (match get_tuple x with Some xs -> xs | None -> args) | _ -> args in
 let args=match k.tuple_payload with Some n when List.length args=n && n>1 -> [make_tuple args] | _ -> args in
 let args=if k.fields=1 && List.length args>1 then [make_tuple args] else args in
 if List.length args<>k.fields then error loc (Printf.sprintf "Constructor arity mismatch: expected %d, got %d" k.fields (List.length args)); args
let tuple_expr = function ExTup (_,xs) -> Some (v xs) | _ -> None
let tuple_pattern = function PaTup (_,xs) -> Some (v xs) | _ -> None
let numeric_literal loc text suffix =
 if suffix<>"" then error loc "Sized integer literals are not supported";
 let text=String.concat "" (String.split_on_char '_' text) in
 let sign,rest=if String.length text>0 && text.[0]='-' then "-",String.sub text 1 (String.length text-1) else "",text in
 if String.length rest>2 && rest.[0]='0' then match rest.[1] with
 | 'x'|'X' -> a ("#x"^sign^String.sub rest 2 (String.length rest-2))
 | 'o'|'O' -> a ("#o"^sign^String.sub rest 2 (String.length rest-2))
 | 'b'|'B' -> a ("#b"^sign^String.sub rest 2 (String.length rest-2))
 | _ -> a text else a text
let decode_string loc s = try Scanf.unescaped s with _ -> error loc "Invalid string escape"

let field_name p = match label_id p with
 | Some name -> let parts=String.split_on_char '.' name in List.hd (List.rev parts)
 | None -> error (MLast.loc_of_patt p) "Unsupported record label"
let record_labels fields = List.map (fun (_,name,mutable_,_,attrs) ->
 if v attrs<>[] then error Ploc.dummy "Attributed record field";name,mutable_) fields
let choose_record env loc ~complete fields =
 let qualifiers=List.filter_map (fun (p,_) -> match label_id p with
   | Some name -> (match String.rindex_opt name '.' with None -> None | Some n -> Some (String.sub name 0 n))
   | None -> None) fields |> List.sort_uniq String.compare in
 let records=match qualifiers with [] -> env.records | [name] -> (find_module env loc name).public.records
   | _ -> error loc "Conflicting module qualifiers in record labels" in
 let names=List.map (fun (p,_) -> field_name p) fields |> List.sort_uniq String.compare in
 let candidates=SM.bindings records |> List.filter (fun (_,record) ->
   let labels=List.map fst record.labels |> List.sort String.compare in
   (not complete || names=labels) && List.for_all (fun name -> List.mem name labels) names) in
 match candidates with [_,record] -> record
 | [] -> error loc "Unknown or incomplete record literal/pattern"
 | _ -> error loc "Ambiguous record labels: type-directed disambiguation is not supported"
let known_field env name =
 name="contents" ||
 SM.exists (fun _ record -> List.mem_assoc name record.labels) env.records ||
 SM.exists (fun _ b -> match b.kind with Constructor {record_fields=Some fields;_} -> List.mem_assoc name fields | _ -> false) env.values
let reference_record env loc ~complete fields =
 match fields with
 | [p,_] when label_id p=Some "contents" ->
   if SM.exists (fun _ record -> List.mem_assoc "contents" record.labels &&
       (not complete || List.length record.labels=1)) env.records
   then error loc "Ambiguous record labels: contents requires an explicit module qualifier";
   true
 | _ -> false
let fields_to_keywords c env emit_value fields = List.concat_map (fun (p,x) -> [a (":"^Sexp.symbol (field_name p));emit_value c env x]) fields
let record_constructor c record =
 let b=record.type_binding in let printed,logical=maker_spelling b in
 reference c {b with printed;logical}
let qualified_value env name = SM.mem name env.values ||
 match String.index_opt name '.' with None -> false | Some n -> SM.mem (String.sub name 0 n) env.modules
let proof_composition env e =
 let h,args=expression_spine e in
 match ident h,args with
 | Some name,[lhs;rhs] when qualified_value env name ->
   let unlabelled = function ExLab _ | ExOlb _ -> false | _ -> true in
   if not (unlabelled lhs && unlabelled rhs) then None
   else let b=find env (MLast.loc_of_expr h) name in
     if b.proof_combinator then Some (b,lhs,rhs) else None
 | _ -> None
let boolean_token c loc name =
 let first=Ploc.first_pos loc and last=Ploc.last_pos loc in
 first>=0 && last<=String.length c.text &&
 (name="True" || name="False" || name="true" || name="false") &&
 List.mem (String.trim (String.sub c.text first (last-first))) ["true";"false"]

(* Pattern names are bound before emitting guards or branch bodies. *)
let bind_pattern c env p =
 List.fold_left (fun env name -> add env name (local c env name Value)) env (List.sort_uniq String.compare (pattern_names p))
let rec root_record_fields = function
 | PaRec (_,fields) -> v fields
 | PaTyc (_,p,_) -> root_record_fields p
 | PaAli (_,p,q) | PaOrp (_,p,q) -> root_record_fields p @ root_record_fields q
 | _ -> []
let case_record_hint env cs =
 let fields=List.concat_map (fun (p,_,_) -> root_record_fields p) cs in
 if fields=[] || List.for_all (fun (p,_) -> field_name p="contents") fields then None
 else let p,_,_=List.hd cs in
   try Some (choose_record env (MLast.loc_of_patt p) ~complete:false fields)
   with Diagnostic _ -> None
let constructor_candidates env loc name =
 let rec previous b = match b.kind with
 | Constructor k -> b :: (match k.previous with None -> [] | Some b -> previous b)
 | _ -> [] in
 let b=find env loc name in
 if String.contains name '.' then (match b.kind with Constructor _ -> [b] | _ -> []) else previous b
let select_pattern_constructor env loc name family args =
 let candidates=constructor_candidates env loc name in
 let current=match candidates with b::_ -> b | [] -> error loc ("Not a pattern constructor: "^name) in
 match family with
 | Some family -> (match List.find_opt (fun b -> match b.kind with Constructor k -> k.family=family | _ -> false) candidates with
   | Some b -> b | None -> error loc ("Inconsistent constructor family: "^name))
 | None -> (match current.kind with Constructor k when k.fields=1 && k.non_tuple_payload ->
   let n=match args with [PaTup (_,ps)] -> List.length (v ps) | _ -> List.length args in
   if n>1 then (match List.find_opt (fun b -> match b.kind with Constructor k -> k.fields=n | _ -> false) candidates with
     | Some b -> b | None -> error loc "Invalid arity for non-tuple constructor payload")
   else current | _ -> current)
let case_constructor_hints c env cs =
 let hints=ref SM.empty in
 let add path loc name =
   let candidates=try constructor_candidates env loc name with Diagnostic _ -> [] in
   let families=List.fold_left (fun s b -> match b.kind with Constructor k -> SS.add k.family s | _ -> s) SS.empty candidates in
   if not (SS.is_empty families) then
     hints:=SM.add path (match SM.find_opt path !hints with None -> families | Some old -> SS.inter old families) !hints in
 let rec walk path p = match p with
 | PaTup (_,ps) -> List.iteri (fun i p -> walk (path^"/"^string_of_int i) p) (v ps)
 | PaAli (_,p,q) | PaOrp (_,p,q) -> walk path p;walk path q
 | PaTyc (_,p,_) -> walk path p
 | PaLong (loc,li,_) -> let name=longid li in if not (boolean_token c loc name) then add path loc name
 | PaApp _ -> let h,_=pattern_spine p in (match patt_id h with Some name -> add path (MLast.loc_of_patt p) name | _ -> ())
 | _ -> () in
 List.iter (fun (p,_,_) -> walk "" p) cs;
 SM.filter_map (fun _ families -> if SS.cardinal families=1 then Some (SS.choose families) else None) !hints
let rec emit_pattern c env p = emit_pattern_hint c env None p
and emit_pattern_hint c env record_hint p = emit_pattern_guided c env record_hint SM.empty "" p
and emit_pattern_guided c env record_hint families path p =
 let loc=MLast.loc_of_patt p in
 let node,rule=match p with
 | PaAny _ -> a "_","wildcard-pattern"
 | PaLid (_,s) -> a (reference c (find env loc (v s))),"variable-pattern"
 | PaTup (_,ps) -> form (runtime c "tuple") (List.mapi (fun i p -> emit_pattern_guided c env None families (path^"/"^string_of_int i) p) (v ps)),"tuple-pattern"
 | PaArr (_,ps) -> form "cl:vector" (List.map (emit_pattern c env) (v ps)),"array-pattern"
 | PaAli (_,p,q) -> form "cl:and" [emit_pattern_guided c env record_hint families path q;emit_pattern_guided c env record_hint families path p],"alias-pattern"
 | PaOrp (_,p,q) ->
   if List.sort String.compare (pattern_names p)<>List.sort String.compare (pattern_names q) then error loc "OR pattern has unequal binding sets";
   form "cl:or" [emit_pattern_guided c env record_hint families path p;emit_pattern_guided c env record_hint families path q],"or-pattern"
 | PaTyc (_,p,_) -> emit_pattern_guided c env record_hint families path p,"pattern-annotation"
 | PaRec (_,fields) -> let fields=v fields in
   if record_hint=None && reference_record env loc ~complete:false fields then
     form (runtime c "ref-contents") [emit_pattern c env (snd (List.hd fields))],"reference-record-pattern"
   else let record=match record_hint with Some record -> record | None -> choose_record env loc ~complete:false fields in
     List.iter (fun (p,_) -> if not (List.mem_assoc (field_name p) record.labels) then error loc "Unknown hinted record field") fields;
     form (reference c record.type_binding) (fields_to_keywords c env emit_pattern fields),"record-pattern"
 | PaInt (_,s,suffix) -> numeric_literal loc (v s) suffix,"integer-pattern"
 | PaFlo (_,s) -> a (String.map (fun c -> if c='e'||c='E' then 'd' else c) (v s)),"float-pattern"
 | PaStr (_,s) -> string (decode_string loc (v s)),"string-pattern"
 | PaChr (_,s) -> let s=decode_string loc (v s) in
   if String.length s<>1 then error loc "Non-byte character literal";
   form (runtime c "character-code") [a (string_of_int (Char.code s.[0]))],"character-pattern"
 | PaLong (_,li,_) -> emit_constructor_pattern c env loc (longid li) [] (SM.find_opt path families),"constructor-pattern"
 | PaApp _ -> let h,args=pattern_spine p in
   let name=match patt_id h with Some s -> s | None -> error loc "Unsupported pattern application" in
   emit_constructor_pattern c env loc name args (SM.find_opt path families),"constructor-pattern"
 | _ -> error loc "Unsupported pattern (lazy, labelled, extension, object, or module pattern)"
 in mark c loc rule node
and emit_constructor_pattern c env loc name args family = match name,args with
 | "[]",[] -> a "nil"
 | "()",[] -> form "cl:type" [a "holai.runtime::unit-value"]
 | ("True"|"true"),[] when boolean_token c loc name -> a "cl:t"
 | ("False"|"false"),[] when boolean_token c loc name -> a "cl:nil"
 | "::",_ -> let args=match args with [PaTup (_,xs)] -> v xs | _ -> args in
   if List.length args<>2 then error loc "Invalid cons pattern";
   form "cl:cons" (List.map (emit_pattern c env) args)
 | _ -> let b=select_pattern_constructor env loc name family args in match b.kind with
   | Constructor k -> (match k.record_fields,args with
     | Some fields,[PaRec (_,ps)] ->
       List.iter (fun (p,_) -> if not (List.mem_assoc (field_name p) fields) then error loc "Unknown inline-record pattern field") (v ps);
       form (reference c b) (fields_to_keywords c env emit_pattern (v ps))
     | Some _,_ -> error loc "Inline-record constructor requires a record pattern"
     | None,[PaAny _] when k.fields>1 -> form (reference c b) [a "_"]
     | None,_ -> let args=constructor_args loc k args tuple_pattern (fun xs -> PaTup (loc,Ploc.VaVal xs)) in form (reference c b) (List.map (emit_pattern c env) args))
   | _ -> error loc ("Not a pattern constructor: "^name)

let rec emit c env e =
 let loc=MLast.loc_of_expr e in
 let node,rule=match e with
 | ExInt (_,s,suffix) -> numeric_literal loc (v s) suffix,"integer"
 | ExFlo (_,s) ->
   let s=String.concat "" (String.split_on_char '_' (v s)) in
   let s=String.map (fun c -> if c='e'||c='E' then 'd' else c) s in
   a (if String.contains s 'd' then s else s^"d0"),"float"
 | ExStr (_,s) -> string (decode_string loc (v s)),"string"
 | ExChr (_,s) -> let s=decode_string loc (v s) in
   if String.length s<>1 then error loc "Non-byte character literal";
   form "cl:code-char" [a (string_of_int (Char.code s.[0]))],"character"
 | ExLid (_,s) -> emit_identifier c env loc (v s),"identifier"
 | ExLong (_,s) -> emit_identifier c env loc (longid s),"identifier"
 | ExFle (_,base,name) when longlid (v name)="val" -> callable c (find env loc "!") [emit c env base],"reference-read"
 | ExFle (_,base,name) -> (match ident e with
   | Some name when qualified_value env name -> emit_identifier c env loc name,"qualified-identifier"
   | _ -> let field=List.hd (List.rev (String.split_on_char '.' (longlid (v name)))) in
     if not (known_field env field) then error loc ("Unknown record field or qualified value: "^field);
     form (runtime c "record-field") [emit c env base;a (":"^Sexp.symbol field)],"record-read")
 | ExRec (_,fields,base) -> let fields=v fields in
   (match base with
   | None -> if reference_record env loc ~complete:true fields then
       form (runtime c "ref") [emit c env (snd (List.hd fields))],"reference-record-literal"
     else let record=choose_record env loc ~complete:true fields in
       if record.private_record && record.type_binding.package<>c.package then error loc "Private record constructor";
       form (record_constructor c record) (fields_to_keywords c env emit fields),"record-literal"
   | Some base -> List.iter (fun (p,_) -> if not (known_field env (field_name p)) then error loc "Unknown record update field") fields;
     form (runtime c "record-update") (emit c env base::fields_to_keywords c env emit fields),"record-update")
 | ExApp _ -> (match proof_composition env e with
   | Some composition ->
     form "holai.runtime:proof" [emit_proof_fragment c env composition],"proof-tactical"
   | None -> let h,args=expression_spine e in emit_application c env loc h args,"application-spine")
 | ExTup (_,es) -> form (runtime c "tuple") (List.map (emit c env) (v es)),"tuple"
 | ExArr (_,es) -> form "cl:vector" (List.map (emit c env) (v es)),"array-literal"
 | ExAre (_,_,base,indices) ->
   if List.length (v indices)<>1 then error loc "Only one-dimensional arrays are supported";
   form (runtime c "array-get") (emit c env base::List.map (emit c env) (v indices)),"array-read"
 | ExSte (_,_,base,indices) ->
   if List.length (v indices)<>1 then error loc "Unsupported string index arity";
   form (runtime c "string-get") (emit c env base::List.map (emit c env) (v indices)),"string-read"
 | ExFun _ -> emit_lambda c env e,"lambda"
 | ExLaz (_,body) ->
   let parameter=synthetic_local c "lazy~unit" in
   form (runtime c "lazy-create")
     [form (runtime c "lambdac") [l [a parameter];emit c env body]],"lazy-expression"
 | ExAsr (_,condition) -> form (runtime c "assert-true")
   [emit c env condition;string c.source;a (string_of_int (Ploc.line_nb loc));
    a (string_of_int (Ploc.first_pos loc-Ploc.bol_pos loc))],"assertion"
 | ExWhi (_,condition,body) -> form "cl:loop"
   [a "while";emit c env condition;a "do";form "progn" (List.map (emit c env) (v body));
    a "finally";form "cl:return" [a (runtime c "unit")]],"while-loop"
 | ExFor (_,p,first,last,up,body) ->
   let name=match patt_id p with Some s -> s | None -> error loc "Unsupported for-loop binder" in
   let b=local c env name Value in
   form "cl:loop" [a "for";a b.printed;a "from";emit c env first;
    a (if v up then "to" else "downto");emit c env last;a "do";
    form "progn" (List.map (emit c (add env name b)) (v body));
    a "finally";form "cl:return" [a (runtime c "unit")]],"for-loop"
 | ExLmd (_,name,me,body) ->
   let name=match v name with Some s -> v s | None -> error loc "Anonymous local module" in
   let compiler=match !local_module_emitter with Some f -> f | None -> assert false in
   let m,wrap=compiler c env name me in
   wrap (emit c {env with modules=SM.add name m env.modules} body),"local-module"
 | ExIfe (_,q,t,f) -> form "if" [emit c env q;emit c env t;emit c env f],"if"
 | ExSeq (_,es) -> form "progn" (List.map (emit c env) (v es)),"sequence"
 | ExMat (_,x,cs) -> form (runtime c "match") (emit c env x::emit_cases c env (v cs)),"match"
 | ExTry (_,x,cs) -> let ex=synthetic_local c (Sexp.symbol (fresh c "exception")) in
   let fallback=l [a "_";form (runtime c "raise") [a ex]] in
   form "handler-case" [emit c env x;
     l [a "holai.runtime:ocaml-condition";l [a ex];
        form (runtime c "match") (a ex::emit_cases c env (v cs)@[fallback])]],"try"
 | ExLet (_,r,bs,body) -> emit_let c env loc (v r) (v bs) body,"let"
 | ExTyc (_,e,_) -> emit c env e,"expression-annotation"
 | ExAss (_,lhs,rhs) -> (match lhs with
   | ExAre (_,_,base,indices) | ExSte (_,_,base,indices) when List.length (v indices)=1 ->
     form (runtime c "array-set") [emit c env base;emit c env (List.hd (v indices));emit c env rhs],"array-write"
   | ExFle (_,cell,name) when longlid (v name)="val" -> form (runtime c "assign") [emit c env cell;emit c env rhs],"reference-write"
   | ExFle (_,cell,name) -> let field=List.hd (List.rev (String.split_on_char '.' (longlid (v name)))) in
     if not (known_field env field) then error loc "Unknown mutable record field";
     form (runtime c "record-assign") [emit c env cell;a (":"^Sexp.symbol field);emit c env rhs],"record-write"
   | _ -> error loc "Unsupported assignment target")
 | ExOpen (_,li,e) -> let m=find_module env loc (longid li) in emit c (union m.public env) e,"local-open"
 | ExUnr _ -> form (runtime c "match-failure") [],"unreachable-match"
 | _ -> error loc "Unsupported expression (object, loop, lazy, module, labelled argument or extension)"
 in mark c loc rule node
and emit_proof_fragment c env (b,lhs,rhs) =
 let left=match proof_composition env lhs with
   | Some composition ->
     let body=emit_proof_fragment c env composition in
     mark c (MLast.loc_of_expr lhs) "proof-tactical" body
   | None -> emit c env lhs in
 let right=emit c env rhs in
 let operator=match b.kind with
   | Value -> a (reference c b)
   | Function n -> function_ref c b n
   | Constructor _ -> assert false in
 fragment [left;operator;right]
and emit_identifier c env loc name = match name with
 | "[]" -> a "nil" | "()" -> a (runtime c "unit")
 | "true" | "True" when boolean_token c loc name -> a "cl:t"
 | "false" | "False" when boolean_token c loc name -> a "cl:nil"
 | _ -> let b=find env loc name in match b.kind with
   | Function n -> function_ref c b n | Value -> a (reference c b)
   | Constructor k ->
     if k.private_ && c.package<>b.package then error loc ("Private constructor is not callable: "^name);
     if k.record_fields<>None then error loc "Inline-record constructor requires a labelled source literal";
     if k.fields=0 then form (maker c b k) []
     else function_ref c {b with printed=k.maker;logical=k.maker_logical} k.fields
and emit_application c env loc h args =
 let unary_source () =
  let loc=MLast.loc_of_expr h in let first=Ploc.first_pos loc and last=Ploc.last_pos loc in
  first>=0 && last<=String.length c.text && last>first && c.text.[first]='-'
 in
 match ident h,args with
 | Some ("-"|"-."),[x] when unary_source () -> form "-" [emit c env x]
 | Some ("&&"|"&"),[x;y] -> form "cl:and" [emit c env x;emit c env y]
 | Some ("||"|"or"),[x;y] -> form "cl:or" [emit c env x;emit c env y]
 | Some "::",_ -> let args=match args with [ExTup (_,xs)] -> v xs | _ -> args in
   if List.length args<>2 then error loc "Invalid cons expression";
   form "cl:cons" (List.map (emit c env) args)
 | Some name,_ -> let b=find env loc name in (match b.kind with
   | Constructor k ->
     if k.private_ && c.package<>b.package then error loc ("Private constructor is not callable: "^name);
     (match k.record_fields,args with
     | Some fields,[ExRec (_,pairs,None)] ->
       let names=List.map (fun (p,_) -> field_name p) (v pairs) |> List.sort String.compare in
       if names<>List.sort String.compare (List.map fst fields) then error loc "Incomplete inline-record literal";
       form (maker c b k) (fields_to_keywords c env emit (v pairs))
     | Some _,_ -> error loc "Inline-record constructor requires a labelled source literal"
     | None,_ -> let args=constructor_args loc k args tuple_expr (fun xs -> ExTup (loc,Ploc.VaVal xs)) in form (maker c b k) (List.map (emit c env) args))
   | _ ->
     let decode = function ExLab (loc,ls) -> (match v ls with
       | [p,e] -> let name=match patt_id p with Some s -> s | None -> error loc "Invalid argument label" in
         let e=match v e with Some e -> e | None -> ExLid (loc,Ploc.VaVal name) in Some name,e
       | _ -> error loc "Grouped argument labels are unsupported")
       | ExOlb (loc,_,_) -> error loc "Optional argument calls are unsupported"
       | e -> None,e in
     let decoded=List.map decode args in
     let args=if List.exists (fun (l,_) -> l<>None) decoded then (
       if b.labels=[] then error loc "Labelled call needs statically resolved parameter labels";
       let positional=ref (List.filter_map (function None,e -> Some e | _ -> None) decoded) in
       let supplied=List.filter_map (function Some name,e -> Some (name,e) | _ -> None) decoded in
       if List.length supplied<>List.length (List.sort_uniq compare (List.map fst supplied)) then error loc "Duplicate argument label";
       List.iter (fun (name,_) -> if not (List.mem (Some name) b.labels) then error loc ("Unknown argument label: "^name)) supplied;
       let missing=ref false in
       List.filter_map (fun label ->
         let arg=match label with Some name -> List.assoc_opt name supplied | None ->
           (match !positional with [] -> None | x::xs -> positional:=xs;Some x) in
         match arg with None -> missing:=true;None | Some x ->
           if !missing then error loc "Non-prefix partial labelled call is unsupported";Some x) b.labels
     ) else args in
     callable c b (List.map (emit c env) args))
 | None,_ -> call_value (emit c env h) (List.map (emit c env) args)
and emit_cases c env cs =
 let record_hint=case_record_hint env cs in
 let families=case_constructor_hints c env cs in
 List.map (fun (p,g,e) ->
 let branch_env=bind_pattern c env p in
 let pattern=emit_pattern_guided c branch_env record_hint families "" p in
 let pattern=match v g with None -> pattern | Some g -> form (runtime c "guard") [pattern;emit c branch_env g] in
 l [pattern;emit c branch_env e]) cs
and compile_function c env parameters body =
 let parameters=List.map (fun p -> snd (required_parameter p)) parameters in
 let bound,params,wrappers = List.fold_left (fun (env,ps,ws) p -> match strip_pattern p with
   | PaLid (_,name) -> let name=v name in let b=local c env name Value in
     add env name b, ps@[a b.printed],ws
   | p -> let name=fresh c "arg" in let b=local c env name Value in
     let env=add env name b in let env=bind_pattern c env p in env,ps@[a b.printed],ws@[p,b,env]) (env,[],[]) parameters in
 let result=match body with
 | Expression e -> emit c bound e
 | Cases cs -> let input=List.hd (List.rev params) in form (runtime c "match") (input::emit_cases c bound cs) in
 let result=List.fold_right (fun (p,b,pattern_env) body ->
   match p with PaAny _ -> body | _ -> form (runtime c "match") [a b.printed;l [emit_pattern c pattern_env p;body]]) wrappers result in
 params,result
and emit_lambda c env e =
 let ps,body=split_function e in
 if ps=[] then error (MLast.loc_of_expr e) "Expected function expression";
 let args,body=compile_function c env ps body in
 form (runtime c "lambdac") [l args;body]
and emit_initializer c env recursive group e =
 if not recursive || closure_initializer e then emit c env e else
 let previous= !(c.reference_observer) in
 c.reference_observer := (fun b ->
   previous b;
   if List.exists (fun (member:binding) -> member.id=b.id && member.package=b.package) group then
     error (MLast.loc_of_expr e) ("Recursive value initializer references its group: "^b.source_name));
 Fun.protect ~finally:(fun () -> c.reference_observer:=previous) (fun () -> emit c env e)
and emit_let c env loc recursive bindings body =
 let named_functions=named_function_bindings bindings in
 if recursive then check_recursive_patterns loc bindings;
 if named_functions then
   (* Entry names must remain unavailable after their source binding is
      shadowed: an earlier nonrecursive RHS may still refer to that target. *)
   let reserved_targets=SM.fold (fun _ (b:binding) targets -> SS.add b.logical targets) env.values SS.empty in
   emit_named_functions c env reserved_targets recursive bindings body
 else (
   let body_env=List.fold_left (fun env (p,_,_) -> bind_pattern c env p) env bindings in
   let simple=List.for_all (fun (p,_,_) -> match strip_pattern p with PaLid _ -> true | _ -> false) bindings in
   if simple then (
     let group=List.map (fun (p,_,_) -> find body_env loc (Option.get (patt_id (strip_pattern p)))) bindings in
     let bs=List.map2 (fun (_,e,_) b -> l [a (reference c b);emit_initializer c (if recursive then body_env else env) recursive group e]) bindings group in
     let body=emit c body_env body in
     if recursive then
       let_form "let" (List.map (function List [name;_] -> l [name;a "nil"] | _ -> assert false) bs) [
         form "setf" (List.concat_map (function List [name;value] -> [name;value] | _ -> assert false) bs);body]
     else
     match unwrap body with
     | List [Atom ("let"|"let*");List inner;List [Atom "cl:declare";_];innerbody]
       when List.length bindings=1 -> let_form "let*" (bs@inner) [innerbody]
     | List [Atom ("let"|"let*");List inner;innerbody] when List.length bindings=1 ->
       let_form "let*" (bs@inner) [innerbody]
     | _ -> let_form "let" bs [body]
   ) else if List.length bindings=1 then (
     let p,e,_=List.hd bindings in form (runtime c "match") [emit c env e;l [emit_pattern c body_env p;emit c body_env body]]
   ) else form (runtime c "match") [form (runtime c "tuple") (List.map (fun (_,e,_) -> emit c env e) bindings);
       l [form (runtime c "tuple") (List.map (fun (p,_,_) -> emit_pattern c body_env p) bindings);emit c body_env body]]
 )
and emit_named_functions c env reserved_targets recursive bindings body =
 let named,_,reserved_targets=List.fold_left (fun (definitions,reserved,targets) (p,e,_) ->
   let name=Option.get (patt_id (strip_pattern p)) in
   let b=labelled_binding (local ~reserved_targets:targets c reserved name (Function (arity e))) e in
   definitions@[name,e,b],add reserved name b,SS.add b.logical targets) ([],env,reserved_targets) bindings in
 let body_env=List.fold_left (fun env (s,_,b) -> add env s b) env named in
 let rhs_env=if recursive then body_env else env in
 let functions=List.map (fun (_,e,b) ->
   let ps,body=split_function e in
   let args,body=compile_function c rhs_env ps body in
   l [a b.printed;l args;body]) named in
 (* Reserve only this consecutive chain, without installing historical bindings
    in the source environment or lowering future groups before these bodies. *)
 let body=match body with
 | ExLet (loc,r,bs,continuation) when named_function_bindings (v bs) ->
   let recursive=v r and bindings=v bs in
   if recursive then check_recursive_patterns loc bindings;
   let node=emit_named_functions c body_env reserved_targets recursive bindings continuation in
   mark c loc "let" node
 | _ -> emit c body_env body in
 combine_local_functions (runtime c "labelsc") functions body

let read_signature env mt =
 let rec read = function
 | MtLid (loc,s) -> (match SM.find_opt (v s) env.signatures with Some s -> s | None -> error loc ("Unknown signature: "^v s))
 | MtWit (_,mt,_) -> read mt
 | MtLong (loc,LiUid (_,s)) -> (match SM.find_opt (v s) env.signatures with Some s -> s | None -> error loc ("Unknown signature: "^v s))
 | MtSig (_,items) -> List.fold_left (fun (signature:signature) -> function
   | SgVal (_,s,_,_) -> {signature with values=SS.add (v s) signature.values}
   | SgExc (_,con,_) ->
       {signature with constructors=SM.add (constructor_name con) false signature.constructors}
   | SgTyp (_,_,ds) -> List.fold_left (fun (signature:signature) d ->
       List.fold_left (fun (signature:signature) cs -> {signature with constructors=SM.add (constructor_name cs) (v d.tdPrv) signature.constructors}) signature (constructors d.tdDef)) signature (v ds)
   | s -> error (MLast.loc_of_sig_item s) "Unsupported signature item") {values=SS.empty;constructors=SM.empty} (v items)
 | mt -> error (MLast.loc_of_module_type mt) "Unsupported module signature"
 in read mt
let restrict (signature:signature) env = {empty with values=SM.filter_map (fun name (b:binding) ->
 match b.kind with
 | Constructor k -> Option.map (fun private_ -> {b with kind=Constructor {k with private_;previous=None}}) (SM.find_opt name signature.constructors)
 | _ -> if SS.mem name signature.values then Some b else None) env.values}
type package_result = { ctx:context; forms:Sexp.t list }
type output = { packages:package_result list; environment:env; public:env; wrap:Sexp.t -> Sexp.t }
type map_template = { source:string; text:string; parameter:string; body:str_item list }
let stdlib_map : map_template option ref = ref None
let stdlib_set : map_template option ref = ref None
let install_map_template source text items =
 let api_and_helpers=SS.of_list ["height";"create";"singleton";"bal";"empty";"add";"find";
  "min_binding";"remove_min_binding";"add_min_binding";"add_max_binding";"join";"concat";"concat_or_join";"split";"union";
  "is_empty";"singleton";"cardinal";"bindings";"bindings_aux";"mem";"filter";"merge";"remove";"fold";"map";"exists"] in
 let functor_module=List.find_map (function
 | StMod (_,_,modules) -> List.find_map (fun (name,me,_) ->
   if Option.map v (v name)=Some "Make" then Some me else None) (v modules)
 | _ -> None) items in
 match functor_module with
 | Some (MeFun (loc,parameter,MeStr (_,items))) ->
   let parameter=match v parameter with Some (name,_) -> (match v name with Some name -> v name | None -> error loc "Anonymous map parameter") | None -> error loc "Unit map parameter" in
   let body=List.filter (function StTyp _ -> true | StVal (_,_,bs) -> List.exists (fun (p,_,_) -> List.exists (fun n -> SS.mem n api_and_helpers) (pattern_names p)) (v bs) | _ -> false) (v items) in
   stdlib_map:=Some {source;text;parameter;body}
 | _ -> error Ploc.dummy "Pinned OCaml Map.Make template has an unexpected shape"
let install_set_template source text items =
 let names=SS.of_list ["height";"create";"bal";"add";"singleton";"add_min_element";"add_max_element";
  "join";"min_elt";"remove_min_elt";"merge";"concat";"split";"empty";"is_empty";"mem";
  "remove";"union";"inter";"diff";"cons_enum";"compare_aux";"compare";"equal";"subset";
  "fold";"for_all";"exists";"cardinal";"elements_aux";"elements";"choose"] in
 let factory=List.find_map (function StMod (_,_,ms) -> List.find_map (fun (name,me,_) ->
   if Option.map v (v name)=Some "Make" then Some me else None) (v ms) | _ -> None) items in
 match factory with Some (MeFun (loc,param,MeStr (_,items))) ->
  let parameter=match v param with Some (name,_) -> (match v name with Some n -> v n | _ -> error loc "Anonymous Set parameter") | _ -> error loc "Unit Set parameter" in
  let body=List.filter (function StTyp _ -> true | StVal (_,_,bs) ->
    List.exists (fun (p,_,_) -> List.exists (fun n -> SS.mem n names) (pattern_names p)) (v bs) | _ -> false) (v items) in
  stdlib_set:=Some {source;text;parameter;body}
 | _ -> error Ploc.dummy "Unexpected pinned Set.Make shape"
let extra_sources () = List.filter_map (Option.map (fun m -> m.source,m.text)) [!stdlib_map;!stdlib_set]
let install_standard_functors env =
 List.fold_left (fun env (name,template,api) -> match template with None -> env | Some t ->
  let make={package="";public=empty;template=Some {parameter=t.parameter;
    body=MeStr (Ploc.dummy,Ploc.VaVal t.body);captured=env;origin=t.source;original_text=t.text;api=Some api}} in
  {env with modules=SM.add name {package="";public={empty with modules=SM.singleton "Make" make};template=None} env.modules}) env
  ["Map",!stdlib_map,["empty";"find";"add";"union";"is_empty";"singleton";"cardinal";"bindings";"mem";"filter";"merge";"remove";"fold";"map";"exists"];
   "Set",!stdlib_set,["empty";"add";"fold";"mem";"union";"diff";"elements";"singleton";"is_empty";"cardinal";"choose";"equal";"exists";"remove";"subset";"inter";"for_all";"compare"]]

let rec module_path = function MeUid (_,name) -> Some (v name)
 | MeAcc (_,a,b) -> (match module_path a,module_path b with Some a,Some b -> Some (a^"."^b) | _ -> None)
 | _ -> None
let rec structure c initial signature items =
 let env=ref initial and forms=ref [] and children=ref [] and wrappers=ref [] and members=ref SM.empty and record_members=ref SM.empty in
 let push loc rule f =
   let f=mark c loc rule f in
   if c.lexical_prefix<>None then c.metadata<-c.metadata@[f] else forms:= !forms @ [f] in
 let export name b = c.exports<-SM.add name b c.exports in
 let publish name b = env:=add !env name b;export name b in
 List.iter (fun item -> let loc=MLast.loc_of_str_item item in match item with
 | StVal (_,recursive,bs) ->
   let comment=String.trim (Ploc.comment loc) in
   if String.contains comment '(' then forms:= !forms @ [Comment comment];
   let bs=v bs and oldenv= !env in
   let reserved_targets=if c.lexical_prefix=None then SS.empty else lexical_targets oldenv in
   if v recursive then check_recursive_patterns loc bs;
   let lexical_slots=c.lexical_prefix<>None && not (List.for_all (fun (p,e,_) ->
     match strip_pattern p with PaLid _ -> arity e>0 | _ -> false) bs) in
   let defs=List.map (fun (p,e,attrs) ->
     if v attrs<>[] then error loc "Binding attributes are unsupported";
     match strip_pattern p with
     | PaLid (_,name) -> let name=v name in let n=arity e in
       p,e,[name,labelled_binding (global ~reserved_targets c name (if n>0 && not lexical_slots then Function n else Value)) e]
     | p -> p,e,List.map (fun name -> name,global ~reserved_targets c name Value) (List.sort_uniq String.compare (pattern_names p))) bs in
   let newenv=List.fold_left (fun env (_,_,ns) -> List.fold_left (fun env (s,b) -> add env s b) env ns) oldenv defs in
   let rhsenv=if v recursive then newenv else oldenv in
   let group=List.concat_map (fun (_,_,ns) -> List.map snd ns) defs in
   if c.lexical_prefix<>None then (
     let named=List.for_all (fun (p,_,ns) -> match strip_pattern p,ns with PaLid _,[_,{kind=Function _;_}] -> true | _ -> false) defs in
     let wrap adjacent body =
       let node=if named then
         let functions=List.map (fun (_,e,ns) ->
           let b=snd (List.hd ns) in let ps,fnbody=split_function e in
           let args,fnbody=compile_function c rhsenv ps fnbody in l [a b.printed;l args;fnbody]) defs in
         let head=runtime c "labelsc" in
         if adjacent then combine_module_functions head functions body else form head [l functions;body]
       else if List.for_all (fun (p,_,_) -> match strip_pattern p with PaLid _ -> true | _ -> false) defs then
         let binds=List.map (fun (_,e,ns) -> l [a (snd (List.hd ns)).printed;emit_initializer c rhsenv (v recursive) group e]) defs in
         if v recursive then
           let_form "let" (List.map (function List [name;_] -> l [name;a "nil"] | _ -> assert false) binds) [
             form "setf" (List.concat_map (function List [name;value] -> [name;value] | _ -> assert false) binds);body]
         else let_form "let" binds [body]
       else (
         let pe=List.fold_left (fun env (p,_,_) -> bind_pattern c env p) rhsenv defs in
         let binds=List.concat_map (fun (_,_,ns) -> List.map (fun (name,b) -> l [a b.printed;a (reference c (find pe loc name))]) ns) defs in
         let patterns=List.map (fun (p,_,_) -> emit_pattern c pe p) defs in
         let expressions=List.map (fun (_,e,_) -> emit c rhsenv e) defs in
         let input,pattern=match expressions,patterns with [e],[p] -> e,p | _ -> form (runtime c "tuple") expressions,form (runtime c "tuple") patterns in
         form (runtime c "match") [input;l [pattern;let_form "let" binds [body]]]) in
       mark c loc "local-module-binding" node in
     wrappers:= !wrappers@[named,wrap]
   ) else (
   if v recursive then (
     let values=List.filter (fun (b:binding) -> b.kind=Value) group in
     if values<>[] then push loc "recursive-global-value-declaration"
       (form "cl:declaim" [form "cl:special" (List.map (fun b -> a b.printed) values)]));
   List.iter (fun (p,e,ns) -> match strip_pattern p,ns with
    | PaLid _,[_,b] -> (match b.kind with
       | Function _ -> let ps,body=split_function e in let args,body=compile_function c rhsenv ps body in
         push loc "global-function" (form (runtime c "defunc") [a b.printed;l args;body])
       | _ -> push loc "global-value" (form "defparameter" [a b.printed;emit_initializer c rhsenv (v recursive) group e]))
    | _,[] -> push loc "global-effect" (emit c rhsenv e)
    | _ ->
      List.iter (fun (_,b) -> push loc "global-pattern-storage" (form "defparameter" [a b.printed;a "nil"])) ns;
      let pe=bind_pattern c rhsenv p in
      let assignments=List.concat_map (fun (name,b) -> [a b.printed;a (reference c (find pe loc name))]) ns in
      push loc "global-pattern" (form (runtime c "match") [emit c rhsenv e;l [emit_pattern c pe p;form "setf" assignments]])
   ) defs);
   env:=newenv;List.iter (fun (_,_,ns) -> List.iter (fun (n,b)->export n b) ns) defs
 | StTyp (_,_,ds) ->
   let named_payloads=List.filter_map (fun d -> match d.tdDef with TySum _ | TyRec _ ->
     let _,name=v d.tdNam in Some (v name) | _ -> None) (v ds) in
   let rec non_tuple_type = function
   | TyLid (_,name) -> let name=v name in
     List.mem name (named_payloads@["int";"string";"bool";"float";"char";"unit";"list";"array";"ref"]) ||
       SM.exists (fun _ record -> record.type_binding.source_name=name) !env.records
   | TyApp (_,head,_) -> non_tuple_type head
   | TyRec _ | TyArr _ -> true
   | _ -> false in
   List.iter (fun d ->
   let _,name=v d.tdNam in let name=v name in
   match d.tdDef with
   | TySum (_,constructors) ->
     let family=c.package^"::"^Option.value c.lexical_prefix ~default:""^"."^name^"@"^string_of_int (Ploc.first_pos loc) in
     let cs=List.map (fun ((loc,n,tyvars,types,result,attrs) as con) ->
       if v tyvars<>[] || v result<>None || v attrs<>[] then error loc "GADT/attributed constructor is unsupported";
       let record_fields=match v types with [TyRec (_,fields)] -> Some (record_labels (v fields)) | _ -> None in
       let s=constructor_name con and fields=match record_fields with Some fields -> List.length fields | None -> List.length (v types) in
       let private_=match signature with Some s -> Option.value (SM.find_opt (v n) s.constructors) ~default:false | None -> v d.tdPrv in
       let b=global c s Value in let maker,maker_logical=maker_spelling b in
       c.makers<-SS.add maker c.makers;
       let tuple_payload=match v types with [TyTup (_,xs)] -> Some (List.length (v xs)) | _ -> None in
       let previous=match SM.find_opt s !env.values with Some ({kind=Constructor _;_} as b) -> Some b | _ -> None in
       let non_tuple_payload=match v types with [t] -> non_tuple_type t | _ -> false in
       let b={b with kind=Constructor {fields;tuple_payload;record_fields;private_;maker;maker_logical;exception_=false;family;non_tuple_payload;previous}} in
       (* Slot symbols are macro-local parameters, not source bindings.  Their
          names still determine the original record keywords. *)
       let slot s=a ("#:"^Sexp.symbol s) in
       let slots=match record_fields with None -> List.init fields (fun n -> slot ("field"^string_of_int n))
       | Some fields -> [form ":record" (List.map (fun (s,m) -> if m then l [slot s;a ":mutable"] else slot s) fields)] in
       publish s b; l (a b.printed::slots)) (v constructors) in
     push loc "variant-declaration" (form (runtime c "defvariant") (a (Sexp.symbol (match c.lexical_prefix with None -> name | Some prefix -> prefix^"."^name))::cs))
   | TyRec (_,fields) ->
     let labels=record_labels (v fields) in
     let type_binding=global c name Value in
     let info={type_binding;labels;private_record=v d.tdPrv} in
     let record_key=type_binding.package^"::"^type_binding.printed in
     env:={ !env with records=SM.add record_key info !env.records};
     record_members:=SM.add record_key info !record_members;
     export ("%record-type:"^name) type_binding;
     let printed,logical=maker_spelling type_binding in
     c.makers<-SS.add printed c.makers;
     export ("%record-maker:"^name) {type_binding with printed;logical};
     let slot s=a ("#:"^Sexp.symbol s) in
     push loc "record-declaration" (form (runtime c "defrecord") (a type_binding.printed::List.map (fun (s,m) -> if m then l [slot s;a ":mutable"] else slot s) labels))
   | TyLid _ | TyAcc _ | TyApp _ | TyTup _ | TyArr _ | TyQuo _ -> () (* Transparent OCaml type aliases are erased. *)
   | t -> error (MLast.loc_of_ctyp t) "Unsupported type declaration") (v ds)
 | StExc (_,ext,_) -> (match v ext with
   | EcTuple (_,con) -> let _,name,tyvars,types,result,attrs=con in
     if v tyvars<>[] || v result<>None || v attrs<>[] then error loc "Unsupported exception declaration";
     let name=v name and fields=List.length (v types) in
     let b=global c name Value in let maker,maker_logical=maker_spelling b in
     c.makers<-SS.add maker c.makers;
     let tuple_payload=match v types with [TyTup (_,xs)] -> Some (List.length (v xs)) | _ -> None in
     let previous=match SM.find_opt name !env.values with Some ({kind=Constructor _;_} as b) -> Some b | _ -> None in
     let b={b with kind=Constructor {fields;tuple_payload;record_fields=None;private_=false;maker;maker_logical;exception_=true;family="ocaml.exn";non_tuple_payload=false;previous}} in
     publish name b;push loc "exception-declaration" (form (runtime c "define-exception") (a b.printed::List.init fields (fun i -> a ("#:field"^string_of_int i))))
   | _ -> error loc "Exception rebinding is unsupported")
 | StMty (_,name,mt,_) -> env:={ !env with signatures=SM.add (v name) (read_signature !env mt) !env.signatures}
 | StMod (_,recursive,ms) ->
   if v recursive then error loc "Recursive modules are unsupported";
   List.iter (fun (name,me,_) ->
     let name=match v name with Some s -> v s | None -> error loc "Anonymous module" in
     let m,wrap,ps=resolve_module c !env name me in
     children:= !children@ps;
     if c.lexical_prefix<>None then wrappers:= !wrappers@[false,(fun _ body -> wrap body)]
     else (match ps with [] -> () | _ ->
       let owner=List.hd (List.rev ps) in
       forms:= !forms@[form "in-package" [a (":"^m.package)]] @
         owner.ctx.metadata @ owner.forms @ [form "in-package" [a (":"^c.package)]]);
     env:={ !env with modules=SM.add name m !env.modules};members:=SM.add name m !members) (v ms)
 | StInc (_,me,_) ->
   let m,wrap,ps=resolve_module c !env (fresh c "include") me in
   children:= !children@ps;
   if c.lexical_prefix<>None then wrappers:= !wrappers@[false,(fun _ body -> wrap body)]
   else (match ps with [] -> () | _ ->
     let owner=List.hd (List.rev ps) in
     forms:= !forms@[form "in-package" [a (":"^m.package)]]@
       owner.ctx.metadata @ owner.forms@[form "in-package" [a (":"^c.package)]]);
   SM.iter (fun name b -> ignore (reference c b);export name b) m.public.values;
   members:=SM.union (fun _ n _ -> Some n) m.public.modules !members;
   record_members:=SM.union (fun _ n _ -> Some n) m.public.records !record_members;
   env:=union m.public !env
 | StOpn (_,_,me,_) ->
   let path=match module_path me with Some path -> path | None -> error loc "Dynamic open is unsupported" in
   let m=find_module !env loc path in env:=union m.public !env
 | StExp (_,e,_) ->
   (match ident (fst (expression_spine e)),snd (expression_spine e) with
    | Some "needs",[ExStr (_,file)] -> c.dependencies<-c.dependencies@[decode_string loc (v file)]
    | _ -> if c.lexical_prefix=None then push loc "toplevel-expression" (emit c !env e)
      else let effect=emit c !env e in wrappers:= !wrappers@[false,(fun _ body -> form "progn" [effect;body])])
 | StDcl (_,items) -> error loc "Nested declaration block needs an explicit lowering rule"
 | StDir _ -> error loc "Toplevel directives are not executed by the translator"
 | _ -> error loc "Unsupported structure item (functor, external, object, extension or include form)"
 ) items;
 let public={ !env with values=c.exports;modules= !members;records= !record_members} in
 {environment= !env;public;wrap=(fun body ->
    (* Only adjacent function declarations merge: even an erased module alias
       is a barrier, and the continuation is not part of this structure. *)
    fst (List.fold_right (fun (named,wrap) (body,adjacent) ->
      wrap adjacent body,named) !wrappers (body,false)));
  packages= !children @ [{ctx=c;forms= !forms}]}
and resolve_module c env name me : modul * (Sexp.t -> Sexp.t) * package_result list =
 let loc=MLast.loc_of_module_expr me in
 match me with
 | MeUid _ | MeAcc _ -> let path=Option.get (module_path me) in find_module env loc path,(fun x -> x),[]
 | MeFun (_,param,body) ->
   let parameter=match v param with Some (name,_) -> (match v name with Some n -> v n | _ -> error loc "Anonymous functor parameter") | _ -> error loc "Unit functors are unsupported" in
   {package="";public=empty;template=Some {parameter;body;captured=env;origin=c.source;original_text=c.text;api=None}},(fun x -> x),[]
 | MeApp (_,factory,arg) ->
   let path=match module_path factory with Some path -> path | None -> error loc "Dynamic functor factory is unsupported" in
   let f=find_module env loc path in
   let t=match f.template with Some t -> t | None -> error loc ("Not a static functor: "^path) in
   let m,_,ps=resolve_module c env (name^"_argument") arg in
   if ps<>[] then error loc "Inline functor arguments need a separate static declaration";
   let captured={t.captured with modules=SM.add t.parameter m t.captured.modules} in
   let instance={c with source=t.origin;text=t.original_text;metadata=[]} in
   let m,wrap,ps=resolve_module instance captured name t.body in
   let m=match t.api with None -> m | Some names ->
     let values=SM.filter (fun name _ -> List.mem name names) m.public.values in
     List.iter (fun (p:package_result) -> if p.ctx.package=m.package then p.ctx.exports<-values) ps;
     {m with public={m.public with values}} in
   c.metadata<-c.metadata@instance.metadata;
   m,wrap,ps
 | MeTyc (_,body,mt) ->
   let sg=read_signature env mt in let m,wrap,ps=resolve_module c env name body in
   let public=restrict sg m.public in
   List.iter (fun (p:package_result) -> if p.ctx.package=m.package then p.ctx.exports<-public.values) ps;
   {m with public},wrap,ps
 | MeStr (_,items) ->
   let lexical_prefix=match c.lexical_prefix with None -> None | Some prefix -> Some (if prefix="" then name else prefix^"."^name) in
   let package=if lexical_prefix=None then c.package^"."^String.lowercase_ascii (Sexp.symbol name) else c.package in
   let reader_owner=if lexical_prefix=None then None else Some (reader_owner c) in
   let child=context ~counter:c.next ~reference_observer:c.reference_observer ?lexical_prefix ?reader_owner package c.source c.text (v items) in
   let out=structure child env None (v items) in
   if lexical_prefix<>None then c.metadata<-c.metadata@child.metadata;
   let packages=if lexical_prefix=None then out.packages else [] in
   {package;public=out.public;template=None},out.wrap,packages
 | _ -> error loc "Only static modules and functors are supported"
let () = local_module_emitter:=Some (fun c env name me ->
 let lexical={c with lexical_prefix=Some (Option.value c.lexical_prefix ~default:"");
   reader_owner=Some (reader_owner c);metadata=[]} in
 let m,wrap,ps=resolve_module lexical env name me in
 if ps<>[] then error (MLast.loc_of_module_expr me) "Unexpected global package in local module";
 c.metadata<-c.metadata@lexical.metadata;
 m,wrap)


let package_declaration ?(initial=false) ?(internals=[]) ?(dependencies=[]) ?(same_file=SS.empty) c =
 let shadow=List.sort_uniq String.compare
   (List.map (fun s -> fst (spelling c s)) c.own @
    SS.elements c.local_symbols @ SS.elements c.local_functions @ SS.elements c.makers) in
 let imports=SM.fold (fun _ (b:binding) pkgs -> SM.add b.package (b::Option.value (SM.find_opt b.package pkgs) ~default:[]) pkgs) c.imports SM.empty in
 let imports=SM.bindings imports |> List.map (fun (pkg,bs) ->
   form ":shadowing-import-from" (a (":"^pkg)::List.map (fun b -> a b.printed) bs)) in
 let exports=SM.fold (fun _ (b:binding) es ->
   if initial && b.package<>c.package then es else
   let s=a b.printed in match b.kind with
   | Constructor k when not k.private_ -> a k.maker::s::es
   | _ -> s::es) c.exports [] |> List.sort_uniq compare in
 let internals=List.filter (fun s -> not (List.mem s shadow || List.mem (a s) exports)) internals in
 let mixed=SS.elements c.used_packages |> List.filter (fun pkg -> pkg<>"cl" && not (SS.mem pkg same_file)) in
 form "uiop:define-package" (a (":"^c.package)::form ":use" [a ":cl"]::
   (if initial || mixed=[] then [] else [form ":mix" (a ":cl"::List.map (fun pkg -> a (":"^pkg)) mixed)]) @
   (if shadow=[] then [] else [form ":shadow" (List.map a shadow)]) @
   (if initial then (if internals=[] then [] else [form ":intern" (List.map a internals)]) else imports) @
   List.map (fun pkg -> form ":import-from" [a (":"^pkg)]) dependencies @
   [form ":export" exports])
