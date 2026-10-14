open MLast
open Scope
let read_file filename =
 let ch=open_in_bin filename in
 Fun.protect ~finally:(fun () -> close_in ch) (fun () -> really_input_string ch (in_channel_length ch))
let parse ?(original=false) filename text =
 Pcaml.input_file := filename;
 let previous= !(Pa_j.jrh_lexer) in
 Pa_j.jrh_lexer := not original;
 let stream=Stream.of_string text in
 let rec loop acc =
  let items,status= Pcaml.parse_implem stream in
  let acc=acc @ List.map fst items in
  match status with Some _ -> acc | None ->
   (* The parser pauses at a directive. It is parsed, never executed. *)
   match Stream.peek stream with None -> acc | Some _ -> loop acc
 in Fun.protect ~finally:(fun () -> Pa_j.jrh_lexer:=previous) (fun () -> loop [])
type inventory = { mutable expressions:int; mutable patterns:int; mutable declarations:int;
 mutable kinds:int SM.t; mutable dependencies:string list; mutable quotations:int;
 mutable unsupported:(Ploc.t*string) list }
let inventory () = {expressions=0;patterns=0;declarations=0;kinds=SM.empty;dependencies=[];quotations=0;unsupported=[]}
let count i kind = i.kinds<-SM.add kind (1+Option.value (SM.find_opt kind i.kinds) ~default:0) i.kinds
let rec expression i e =
 i.expressions<-i.expressions+1;
 let branch (p,g,e) = pattern i p;Option.iter (expression i) (v g);expression i e in
 (match e with
 | ExLid _ | ExLong _ -> count i "identifier"
 | ExInt _ -> count i "integer" | ExFlo _ -> count i "float"
 | ExStr _ -> count i "string" | ExChr _ -> count i "character"
 | ExApp (_,f,x) -> count i "application";expression i f;expression i x
 | ExFun (_,cs) -> count i "function";List.iter branch (v cs)
 | ExAsr (_,e) -> count i "assertion";expression i e
 | ExLaz (_,e) -> count i "lazy-expression";expression i e
 | ExWhi (_,condition,body) -> count i "while-loop";expression i condition;List.iter (expression i) (v body)
 | ExFor (_,p,a,b,_,body) -> count i "for-loop";pattern i p;expression i a;expression i b;List.iter (expression i) (v body)
 | ExLmd (_,_,me,body) -> count i "local-module";module_expr i me;expression i body
 | ExLab (_,fields) -> count i "labelled-argument";List.iter (fun (_,e) -> Option.iter (expression i) (v e)) (v fields)
 | ExLet (_,r,bs,e) -> count i (if v r then "let-rec" else "let");
   List.iter (fun (p,e,_) -> pattern i p;expression i e) (v bs);expression i e
 | ExMat (_,e,cs) -> count i "match";expression i e;List.iter branch (v cs)
 | ExTry (_,e,cs) -> count i "try";expression i e;List.iter branch (v cs)
 | ExIfe (_,q,t,f) -> count i "if";List.iter (expression i) [q;t;f]
 | ExSeq (_,es) -> count i "sequence";List.iter (expression i) (v es)
 | ExTup (_,es) -> count i "tuple";List.iter (expression i) (v es)
 | ExArr (_,es) -> count i "array-literal";List.iter (expression i) (v es)
 | ExAre (_,_,e,es) | ExSte (_,_,e,es) -> count i "indexed-access";expression i e;List.iter (expression i) (v es)
 | ExRec (_,fields,base) -> count i "record-expression";Option.iter (expression i) base;List.iter (fun (_,e) -> expression i e) (v fields)
 | ExTyc (_,e,_) -> count i "annotation";expression i e
 | ExFle (_,e,_) -> count i "field-or-qualified-value";expression i e
 | ExAss (_,l,r) -> count i "assignment";expression i l;expression i r
 | ExOpen (_,_,e) -> count i "local-open";expression i e
 | _ -> count i "unsupported-expression";i.unsupported<-(MLast.loc_of_expr e,"Unsupported expression family")::i.unsupported)
and pattern i p =
 i.patterns<-i.patterns+1;
 match p with
 | PaPfx (_,_,p) -> count i "qualified-pattern";pattern i p
 | PaLab (_,fields) -> count i "labelled-parameter";List.iter (fun (p,b) -> pattern i p;Option.iter (pattern i) (v b)) (v fields)
 | PaTup (_,ps) -> count i "tuple-pattern";List.iter (pattern i) (v ps)
 | PaArr (_,ps) -> count i "array-pattern";List.iter (pattern i) (v ps)
 | PaRec (_,fields) -> count i "record-pattern";List.iter (fun (_,p) -> pattern i p) (v fields)
 | PaApp (_,p,q) | PaAli (_,p,q) | PaOrp (_,p,q) -> count i "compound-pattern";pattern i p;pattern i q
 | PaTyc (_,p,_) -> count i "pattern-annotation";pattern i p
 | PaLid _ | PaLong _ | PaAny _ | PaInt _ | PaStr _ | PaChr _ | PaFlo _ -> count i "atomic-pattern"
 | _ -> count i "unsupported-pattern";i.unsupported<-(MLast.loc_of_patt p,"Unsupported pattern family")::i.unsupported
and structure i items = List.iter (fun item ->
 i.declarations<-i.declarations+1;
 match item with
 | StVal (_,_,bs) -> count i "value-declaration";List.iter (fun (p,e,_) -> pattern i p;expression i e) (v bs)
 | StExp (_,e,_) -> count i "expression-declaration";
   (match ident (fst (Compiler.expression_spine e)),snd (Compiler.expression_spine e) with
    | Some ("needs"|"loads"|"loadt"),[ExStr (_,s)] -> i.dependencies<-i.dependencies@[v s]
    | _ -> ());expression i e
 | StMod (_,_,mods) -> count i "module-declaration";List.iter (fun (_,me,_) -> module_expr i me) (v mods)
 | StTyp _ -> count i "type-declaration" | StExc _ -> count i "exception-declaration"
 | StMty _ -> count i "module-signature" | StInc _ -> count i "include" | StOpn _ -> count i "open"
 | StDir _ -> count i "directive"
 | StDcl (_,is) -> count i "declaration-block";structure i (v is)
 | _ -> count i "unsupported-declaration";i.unsupported<-(MLast.loc_of_str_item item,"Unsupported declaration family")::i.unsupported) items
and module_expr i = function
 | MeStr (_,items) -> structure i (v items)
 | MeTyc (_,me,_) -> module_expr i me
 | MeFun (_,_,body) -> count i "static-functor";module_expr i body
 | MeUid _ | MeAcc _ -> count i "module-alias"
 | MeApp (_,_,_) -> count i "static-functor-application"
 | _ -> count i "unsupported-module"
let json i =
 let kinds=SM.bindings i.kinds |> List.map (fun (k,n) -> Sexp.json_string k^":"^string_of_int n) in
 Printf.sprintf "\"declarations\":%d,\"expressions\":%d,\"patterns\":%d,\"constructs\":{%s},\"dependencies\":[%s],\"unsupported_families\":%d"
  i.declarations i.expressions i.patterns (String.concat "," kinds)
  (String.concat "," (List.map Sexp.json_string i.dependencies)) (List.length i.unsupported)
