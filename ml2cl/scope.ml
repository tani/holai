open MLast
module SM = Map.Make(String)
module SS = Set.Make(String)
let v = function Ploc.VaVal x -> x | Ploc.VaAnt s -> failwith ("Unexpected antiquotation: "^s)
exception Diagnostic of Ploc.t * string
let error loc msg = raise (Diagnostic (loc,msg))
let rec longid = function
 | LiUid (_,s) -> v s | LiAcc (_,p,s) -> longid p ^ "." ^ v s
 | x -> error (MLast.loc_of_longid x) "Functor/extended long identifier is unsupported"
let longlid (p,s) = match p with None -> v s | Some p -> longid (v p)^"."^v s
let rec pattern_names = function
 | PaLid (_,s) -> [v s]
 | PaAli (_,p,q) | PaApp (_,p,q) -> pattern_names p @ pattern_names q
 | PaTup (_,ps) | PaArr (_,ps) -> List.concat_map pattern_names (v ps)
 | PaTyc (_,p,_) -> pattern_names p
 | PaOrp (_,p,_) -> pattern_names p
 | PaRec (_,fields) -> List.concat_map (fun (_,p) -> pattern_names p) (v fields)
 | _ -> []
let rec ident = function
 | ExLid (_,s) -> Some (v s) | ExLong (_,p) -> Some (longid p)
 | ExFle (_,_,s) when longlid (v s)="val" -> None
 | ExFle (_,_,_) as e -> (match e with ExFle (_,p,s) -> Option.map (fun p -> p^"."^longlid (v s)) (ident p) | _ -> assert false)
 | _ -> None
type ctor = { fields:int; tuple_payload:int option; record_fields:(string * bool) list option; private_:bool; maker:string; maker_logical:string; exception_:bool; family:string; non_tuple_payload:bool; previous:binding option }
and kind = Function of int | Value | Constructor of ctor
and binding = { id:int; source_name:string; package:string; printed:string; logical:string; kind:kind; labels:string option list; proof_combinator:bool }
type signature = { values:SS.t; constructors:bool SM.t }
type record_type = { type_binding:binding; labels:(string * bool) list; private_record:bool }
type env = { values:binding SM.t; modules:modul SM.t; signatures:signature SM.t; records:record_type SM.t }
and modul = { package:string; public:env; template:functor_template option }
and functor_template = { parameter:string; body:MLast.module_expr; captured:env; origin:string; original_text:string; api:string list option }
let empty = {values=SM.empty;modules=SM.empty;signatures=SM.empty;records=SM.empty}
let add env name b = {env with values=SM.add name b env.values}
let union newer older = {
 values=SM.union (fun _ n o -> match n.kind,o.kind with
   | Constructor k,Constructor _ when n.package<>o.package || n.printed<>o.printed -> Some {n with kind=Constructor {k with previous=Some o}}
   | _ -> Some n) newer.values older.values;
 modules=SM.union (fun _ n _ -> Some n) newer.modules older.modules;
 signatures=SM.union (fun _ n _ -> Some n) newer.signatures older.signatures;
 records=SM.union (fun _ n _ -> Some n) newer.records older.records }
let rec find env loc name =
 match String.index_opt name '.' with
 | None -> (match SM.find_opt name env.values with Some b -> b | None -> error loc ("Unresolved identifier: "^name))
 | Some n -> let m=String.sub name 0 n and rest=String.sub name (n+1) (String.length name-n-1) in
   match SM.find_opt m env.modules with Some m -> find m.public loc rest
   | None -> (match SM.find_opt name env.values with Some b -> b | None -> error loc ("Unresolved module/value: "^name))
let rec find_module env loc name = match SM.find_opt name env.modules with
 | Some m -> m | None ->
   (match String.index_opt name '.' with
   | Some n -> let prefix=String.sub name 0 n and rest=String.sub name (n+1) (String.length name-n-1) in
     let m=find_module env loc prefix in find_module m.public loc rest
   | None -> error loc ("Unresolved module: "^name))
let constructor_name (_,name,_,_,_,_) = v name
let constructors = function TySum (_,cs) -> v cs | _ -> []
let rec own_names items = List.concat_map (function
 | StVal (_,_,bs) -> List.concat_map (fun (p,_,_) -> pattern_names p) (v bs)
 | StTyp (_,_,ds) -> List.concat_map (fun d -> match d.tdDef with
     TyRec _ -> let _,name=v d.tdNam in [v name]
     | _ -> List.map constructor_name (constructors d.tdDef)) (v ds)
 | StExc (_,ec,_) -> (match v ec with EcTuple (_,c) -> [constructor_name c] | _ -> [])
 | StDcl (_,is) -> own_names (v is) | _ -> []) items
let source_spelling = function
 | "f_f_" -> "F_F" | "then_" -> "THEN"
 | "thenc_" -> "THENC" | "thenl_" -> "THENL" | "orelse_" -> "ORELSE"
 | "orelsec_" -> "ORELSEC" | "then_tcl_" -> "THEN_TCL" | "orelse_tcl_" -> "ORELSE_TCL"
 | s -> s
let name_priority s =
 if String.lowercase_ascii s=s then 0
 else if String.exists (function 'a'..'z' -> true | _ -> false) s then 1 else 2
let compare_source_names a b =
 let p=compare (name_priority a) (name_priority b) in
 if p=0 then String.compare a b else p
let allocate_suffix forbidden printed =
 let rec choose printed =
   let logical=String.uppercase_ascii printed in
   if forbidden logical then choose (printed^"%") else printed,logical in
 choose printed
let control_names = ["LAMBDA";"FUNCTION";"PROGN";"FLET";"LABELS";"QUOTE";
 "BLOCK";"RETURN-FROM";"CATCH";"THROW";"UNWIND-PROTECT";"HANDLER-CASE";
 "DECLARE";"THE";"DEFUN";"DEFPARAMETER";"DEFPACKAGE";"IN-PACKAGE";
 "EVAL-WHEN";"LET";"LET*";"SETF";"IF";"COND";"DEFUNC";"LAMBDAC";
 "LABELSC";"FLETC"]
type context = {
 package:string; source:string; text:string; own:string list; spellings:(string * string) SM.t;
 totals:int SM.t; mutable occurrences:int SM.t; mutable globals:SS.t;
 mutable local_functions:SS.t; mutable local_symbols:SS.t; mutable makers:SS.t;
 next:int ref; mutable imports:binding SM.t; mutable exports:binding SM.t;
 mutable dependencies:string list; mutable rules:int SM.t;
 lexical_prefix:string option; mutable metadata:Sexp.t list;
 reference_observer:(binding -> unit) ref; mutable owned_logicals:SS.t option;
 reader_owner:context option; mutable used_packages:SS.t; mutable proof_head:string ref option }
let context ?(counter=ref 0) ?(reference_observer=ref (fun (_:binding) -> ())) ?lexical_prefix ?reader_owner package source text items =
 let own=own_names items in
 let totals=List.fold_left (fun m s -> SM.add s (1+Option.value (SM.find_opt s m) ~default:0) m) SM.empty own in
 let spellings,_=List.fold_left (fun (names,used) source ->
   let printed,logical=allocate_suffix (fun logical -> SS.mem logical used || List.mem logical control_names)
       (Sexp.symbol (source_spelling source)) in
   SM.add source (printed,logical) names,SS.add logical used)
   (SM.empty,SS.empty) (List.sort_uniq compare_source_names own) in
 {package;source;text;own;spellings;totals;occurrences=SM.empty;globals=SS.empty;local_functions=SS.empty;local_symbols=SS.empty;makers=SS.empty;next=counter;
  imports=SM.empty;exports=SM.empty;dependencies=[];rules=SM.empty;lexical_prefix;metadata=[];reference_observer;owned_logicals=None;
  reader_owner;used_packages=SS.empty;proof_head=None}
let reader_owner c = Option.value c.reader_owner ~default:c
let use_package c package =
 let owner=reader_owner c in
 if package<>"" && package<>owner.package then owner.used_packages<-SS.add package owner.used_packages
let fresh c stem = incr c.next; stem^"~"^string_of_int !(c.next)
let spelling c s =
 match SM.find_opt s c.spellings with Some spelling -> spelling | None ->
 let printed=Sexp.symbol (source_spelling s) in printed,String.uppercase_ascii printed
(* Synthetic lexical binders share the same reader-package shadow authority,
   without allocating a source binding or consuming another source-map ID. *)
let synthetic_local c printed =
 let owner=reader_owner c in
 let printed,logical=allocate_suffix (fun logical ->
   SS.mem logical owner.globals || SM.mem logical owner.imports ||
   List.exists (fun source -> snd (spelling owner source)=logical) owner.own) printed in
 owner.local_symbols<-SS.add logical owner.local_symbols;
 printed
let global ?(reserved_targets=SS.empty) c source_name kind =
 let n=1+Option.value (SM.find_opt source_name c.occurrences) ~default:0 in
 c.occurrences<-SM.add source_name n c.occurrences;
 let total=Option.value (SM.find_opt source_name c.totals) ~default:1 in
 let base,_=spelling c source_name in
 let printed=if n<total then base^"~"^string_of_int n else base in
 let printed=match c.lexical_prefix with None -> printed | Some prefix -> Sexp.symbol prefix^"."^printed in
 let printed,logical=match c.lexical_prefix with
 | None -> printed,String.uppercase_ascii printed
 | Some prefix ->
   let owner=reader_owner c in
   let occupied logical =
     SS.mem logical reserved_targets || SS.mem logical c.local_symbols ||
     SS.mem logical owner.globals || SM.mem logical owner.imports in
   let printed,logical=
     if not (occupied (String.uppercase_ascii printed)) then printed,String.uppercase_ascii printed
     else (
       (* A reused local-module prefix must not capture an inherited entry.
          Also reserve future declarations' ordinary prefixed/versioned names,
          so a collision suffix cannot steal a later source binding's target. *)
       let planned=SM.fold (fun source total targets ->
         let base,_=spelling c source in
         let rec versions n targets =
           if n>total then targets else
           let version=if n<total then base^"~"^string_of_int n else base in
           versions (n+1) (SS.add (String.uppercase_ascii (Sexp.symbol prefix^"."^version)) targets) in
         versions 1 targets) c.totals SS.empty in
       allocate_suffix (fun logical -> occupied logical || SS.mem logical planned) printed) in
   c.local_symbols<-SS.add logical c.local_symbols;
   let owner=reader_owner c in owner.local_symbols<-SS.add logical owner.local_symbols;
   printed,logical in
 incr c.next;
 let proof_combinator =
   c.package="holai.tactics" && c.source="tactics.ml" && c.lexical_prefix=None && n=1 &&
   (match source_name,kind with
    | "then_",Value | "thenl_",Value | "orelse_",Function 3 -> true
    | _ -> false) in
 let b={id= !(c.next);source_name;package=(if c.lexical_prefix=None then c.package else "");printed;logical;kind;labels=[];proof_combinator} in
 (match kind with Value -> c.globals<-SS.add logical c.globals | _ -> ()); b
let local ?(reserved_targets=SS.empty) c env source_name kind =
 let owner=reader_owner c in
 let printed,logical=spelling c source_name in
 let forbidden logical =
   SS.mem logical reserved_targets ||
   List.mem logical control_names || SS.mem logical c.globals ||
   SS.mem logical owner.globals || SM.mem logical owner.imports ||
   SM.exists (fun _ (b:binding) -> b.logical=logical) env.values ||
   List.exists (fun source -> snd (spelling c source)=logical) c.own ||
   List.exists (fun source -> snd (spelling owner source)=logical) owner.own in
 let printed,logical=allocate_suffix forbidden printed in
 (match kind with Function _ -> owner.local_functions<-SS.add printed owner.local_functions | _ -> ());
 c.local_symbols<-SS.add logical c.local_symbols;
 owner.local_symbols<-SS.add logical owner.local_symbols;
 incr c.next; {id= !(c.next);source_name;package="";printed;logical;kind;labels=[];proof_combinator=false}
let external_binding package name kind =
 (* Fixed foreign targets retain their native spelling, including CL constants. *)
 let printed=name in
 {id=0;source_name=name;package;printed;logical=String.uppercase_ascii printed;kind;labels=[];proof_combinator=false}
let reference c (b:binding) =
 !(c.reference_observer) b;
 use_package c b.package;
 let owner=reader_owner c in
 if b.package="" || b.package=owner.package then b.printed
 else
 let owned=match owner.owned_logicals with Some set -> set | None ->
   let set=List.fold_left (fun set s -> let _,k=spelling owner s in SS.add ("MAKE-"^k) (SS.add k set)) SS.empty owner.own in
   owner.owned_logicals<-Some set;set in
 let own_conflict=SS.mem b.logical owner.local_symbols || SS.mem b.logical owned in
 match SM.find_opt b.logical owner.imports with
 | Some old when old.package<>b.package || old.printed<>b.printed -> b.package^":"^b.printed
 | _ when own_conflict -> b.package^":"^b.printed
 | _ -> owner.imports<-SM.add b.logical b owner.imports; b.printed
let runtime_owner name = match name with
 | "!=" | "<" | "<=" | "<>" | "="
 | "==" | ">" | ">=" | "abs-num" | "array-get"
 | "array-make" | "array-set" | "bool-and" | "bool-or" | "channel-length"
 | "char-chr" | "close-channel" | "compare" | "cpu-time" | "define-exception"
 | "defrecord" | "defunc" | "defvariant" | "End_of_file" | "end_of_file" | "exception-string"
 | "Failure" | "failure" | "failwith" | "fletc" | "funcall" | "function-value"
 | "gcd-num" | "input-line" | "int-div" | "int-mod" | "int-of-num"
 | "int-of-string" | "invalid-arg" | "Invalid_argument" | "invalid_argument" | "labelsc" | "lambdac"
 | "list-exists" | "list-fold-left" | "make-end_of_file" | "make-failure"
 | "make-invalid_argument" | "make-none" | "make-not_found" | "make-some" | "make-sys_error"
 | "mod-num" | "None" | "none" | "Not_found" | "not_found" | "num" | "numdom"
 | "open-in" | "open-in-bin" | "open-out" | "output-string" | "partial"
 | "power-num" | "proof" | "quo-num" | "really-input-string" | "record-assign"
 | "record-field" | "record-update" | "Some" | "some" | "string-concat" | "string-escaped"
 | "string-get" | "string-join" | "string-length" | "string-make" | "string-of-float"
 | "string-of-int" | "string-of-num" | "string-sub" | "structural-hash" | "Sys_error" | "sys_error"
 | "variant-fields" | "variant-tag" | "variant-type" | "variant-value" -> "holai.runtime.core"
 | "assign" | "deref" | "fst" | "match-failure" | "ocaml-condition"
 | "raise" | "ref" | "ref-contents" | "snd" | "tuple"
 | "tuple-items" | "tuple-ref" | "unit" | "unit-value" -> "holai.runtime.data"
 | "buffer-contents" | "buffer-create" | "buffer-reset" | "close-box" | "format-asprintf"
 | "format-fprintf" | "format-printf" | "formatter-of-buffer" | "get-margin" | "open-box"
 | "open-vbox" | "pp-close-box" | "pp-get-max-boxes" | "pp-open-box" | "pp-open-hbox"
 | "pp-open-hvbox" | "pp-open-vbox" | "pp-print-as" | "pp-print-break" | "pp-print-char"
 | "pp-print-cut" | "pp-print-flush" | "pp-print-int" | "pp-print-newline" | "pp-print-space"
 | "pp-print-string" | "pp-set-margin" | "pp-set-max-boxes" | "print-break" | "print-flush"
 | "print-newline" | "print-string" | "printf-printf" | "printf-sprintf" | "set-margin"
 | "set-max-boxes" | "std-formatter" -> "holai.runtime.format"
 | "character-code" | "guard" | "match" -> "holai.runtime.pattern"
 | "array-fold-left" | "array-map" | "array-of-list" | "assert-true" | "Assert_failure" | "assert_failure"
 | "catch-break" | "float-floor" | "float-of-int" | "gc-control" | "gc-get"
 | "gc-set" | "ignore-value" | "int-asr" | "int-lsl" | "int-lsr"
 | "int-of-float" | "lazy-create" | "lazy-force" | "lazy-undefined" | "list-assoc" | "list-concat"
 | "list-filter" | "list-filter-map" | "list-find" | "list-fold-left2" | "list-fold-right"
 | "list-fold-right2" | "list-for-all" | "list-for-all2" | "list-hd" | "list-iter"
 | "list-length" | "list-map" | "list-map2" | "list-mapi" | "list-mem"
 | "list-mem-assoc" | "list-nth" | "list-partition" | "list-rev" | "list-rev-append"
 | "list-rev-map" | "list-sort" | "list-tl" | "make-assert_failure" | "make-gc-control"
 | "make-lazy-undefined" | "make-sys_break" | "ocaml-max-int" | "print-endline" | "random-bits"
 | "random-init" | "random-int" | "ref-decr" | "ref-incr" | "sys_break"
 | "table-add" | "table-clear" | "table-create" | "table-find" | "table-fold"
 | "table-remove" | "table-replace" -> "holai.runtime.stdlib"
 | name -> invalid_arg ("Unknown runtime support symbol: "^name)
let runtime_binding name kind = external_binding (runtime_owner name) name kind
let runtime c name = reference c (runtime_binding name Value)
(* Synthetic macro heads must not reserve imports while source names are still
   being allocated. Lexical modules share this cell with their reader owner. *)
let deferred_proof_head c =
 let owner=reader_owner c in
 let head=match owner.proof_head with
 | Some head -> head
 | None -> let head=ref "holai.runtime.core:proof" in owner.proof_head<-Some head;head in
 Sexp.DeferredAtom head
let finalize_proof_head c =
 let owner=reader_owner c in
 match owner.proof_head with
 | None -> ()
 | Some head ->
   (* REFERENCE handles source-owned/local names and foreign imports; makers
      are also shadowed by the final package declaration. *)
   if SS.mem "PROOF" owner.makers then use_package owner "holai.runtime.core"
   else head:=runtime owner "proof"
let mark c loc rule form =
 incr c.next;
 c.rules<-SM.add rule (1+Option.value (SM.find_opt rule c.rules) ~default:0) c.rules;
 Sexp.Origin ({id= !(c.next);source=c.source;first=Ploc.first_pos loc;last=Ploc.last_pos loc;
               line=Ploc.line_nb loc;rule},form)
let maker_spelling (b:binding) =
 let logical="MAKE-"^b.logical in
 "make-"^b.printed,logical
let maker c (b:binding) k = reference c {b with printed=k.maker;logical=k.maker_logical;kind=Function k.fields}
let base_environment () =
 let spec=[
  "+","cl","+",2; "-","cl","-",2; "*","cl","*",2; "/","holai.runtime.core","int-div",2;
  "~-","cl","-",1; "~-.","cl","-",1; "mod","holai.runtime.core","int-mod",2;
  "+.","cl","+",2; "-.","cl","-",2; "*.","cl","*",2; "/.","cl","/",2;
  "=","holai.runtime.core","=",2; "<>","holai.runtime.core","<>",2;
  "==","holai.runtime.core","==",2; "!=","holai.runtime.core","!=",2;
  "<","holai.runtime.core","<",2; ">","holai.runtime.core",">",2;
  "<=","holai.runtime.core","<=",2; ">=","holai.runtime.core",">=",2;
  "compare","holai.runtime.core","compare",2; "not","cl","not",1;
  "String.compare","holai.runtime.core","compare",2;
  "Num.mod_num","holai.runtime.core","mod-num",2; "Num.quo_num","holai.runtime.core","quo-num",2;
  "is_integer_num","cl","integerp",1; "succ_num","cl","1+",1;
  "Char.code","cl","char-code",1; "Char.chr","holai.runtime.core","char-chr",1;
  "String.make","holai.runtime.core","string-make",2; "String.escaped","holai.runtime.core","string-escaped",1;
  "int_of_string","holai.runtime.core","int-of-string",1;
  "Array.make","holai.runtime.core","array-make",2; "Array.get","holai.runtime.core","array-get",2; "Array.set","holai.runtime.core","array-set",3;
  "Array.fold_left","holai.runtime.stdlib","array-fold-left",3;
  "Array.of_list","holai.runtime.stdlib","array-of-list",1; "Array.map","holai.runtime.stdlib","array-map",2;
  "minus_num","cl","-",1; "int_of_num","holai.runtime.core","int-of-num",1;
  "Gc.get","holai.runtime.stdlib","gc-get",1; "Gc.set","holai.runtime.stdlib","gc-set",1;
  "Sys.catch_break","holai.runtime.stdlib","catch-break",1;
  "List.fold_left","holai.runtime.core","list-fold-left",3; "List.exists","holai.runtime.core","list-exists",2;
  "||","holai.runtime.core","bool-or",2; "or","holai.runtime.core","bool-or",2;
  "&&","holai.runtime.core","bool-and",2; "&","holai.runtime.core","bool-and",2;
  "@","cl","append",2; "^","holai.runtime.core","string-concat",2;
  "ref","holai.runtime.data","ref",1; "!","holai.runtime.data","deref",1;
  ":=","holai.runtime.data","assign",2; "raise","holai.runtime.data","raise",1;
  "failwith","holai.runtime.core","failwith",1; "invalid_arg","holai.runtime.core","invalid-arg",1;
  "fst","holai.runtime.data","fst",1; "snd","holai.runtime.data","snd",1;
  "abs","cl","abs",1; "max","cl","max",2; "min","cl","min",2;
  "land","cl","logand",2; "lor","cl","logior",2; "lxor","cl","logxor",2; "lnot","cl","lognot",1;
  "lsl","holai.runtime.stdlib","int-lsl",2;
  "lsr","holai.runtime.stdlib","int-lsr",2;
  "asr","holai.runtime.stdlib","int-asr",2;
  "incr","holai.runtime.stdlib","ref-incr",1;"decr","holai.runtime.stdlib","ref-decr",1;
  "ignore","holai.runtime.stdlib","ignore-value",1;
  "print_endline","holai.runtime.stdlib","print-endline",1;
  "Lazy.force","holai.runtime.stdlib","lazy-force",1;
  "float_of_int","holai.runtime.stdlib","float-of-int",1;
  "int_of_float","holai.runtime.stdlib","int-of-float",1;
  "floor","holai.runtime.stdlib","float-floor",1;"sqrt","cl","sqrt",1;"float_sqrt","cl","sqrt",1;
  "log","cl","log",1;"exp","cl","exp",1;"**","cl","expt",2;
  "Random.init","holai.runtime.stdlib","random-init",1;
  "Random.bits","holai.runtime.stdlib","random-bits",1;"Random.int","holai.runtime.stdlib","random-int",1;
  "Hashtbl.create","holai.runtime.stdlib","table-create",1;"Hashtbl.clear","holai.runtime.stdlib","table-clear",1;
  "Hashtbl.add","holai.runtime.stdlib","table-add",3;"Hashtbl.replace","holai.runtime.stdlib","table-replace",3;
  "Hashtbl.find","holai.runtime.stdlib","table-find",2;
  "Hashtbl.remove","holai.runtime.stdlib","table-remove",2;
  "Hashtbl.fold","holai.runtime.stdlib","table-fold",3;
  "String.length","holai.runtime.core","string-length",1; "String.sub","holai.runtime.core","string-sub",3;
  "String.concat","holai.runtime.core","string-join",2; "String.get","holai.runtime.core","string-get",2;
  "num","holai.runtime.core","num",1; "numdom","holai.runtime.core","numdom",1;
  "gcd_num","holai.runtime.core","gcd-num",2; "abs_num","holai.runtime.core","abs-num",1;
  "power_num","holai.runtime.core","power-num",2; "quo_num","holai.runtime.core","quo-num",2;
  "mod_num","holai.runtime.core","mod-num",2; "Num.int_of_num","holai.runtime.core","int-of-num",1;
  "string_of_num","holai.runtime.core","string-of-num",1;
  "string_of_int","holai.runtime.core","string-of-int",1; "string_of_float","holai.runtime.core","string-of-float",1;
  "+/","cl","+",2; "-/","cl","-",2; "*/","cl","*",2; "//","cl","/",2;
  "=/","holai.runtime.core","=",2; "</","holai.runtime.core","<",2; ">/","holai.runtime.core",">",2;
  "<=/","holai.runtime.core","<=",2; ">=/","holai.runtime.core",">=",2; "<>/","holai.runtime.core","<>",2;
  "Format.print_string","holai.runtime.format","print-string",1;
  "Format.print_newline","holai.runtime.format","print-newline",1;
  "Format.pp_print_string","holai.runtime.format","pp-print-string",2;
  "Sys.time","holai.runtime.core","cpu-time",1; "Printexc.to_string","holai.runtime.core","exception-string",1;
  "Hashtbl.hash","holai.runtime.core","structural-hash",1;
  "open_in","holai.runtime.core","open-in",1; "open_in_bin","holai.runtime.core","open-in-bin",1;
  "open_out","holai.runtime.core","open-out",1; "input_line","holai.runtime.core","input-line",1;
  "close_in","holai.runtime.core","close-channel",1; "close_out","holai.runtime.core","close-channel",1;
  "output_string","holai.runtime.core","output-string",2;
  "in_channel_length","holai.runtime.core","channel-length",1;
  "really_input_string","holai.runtime.core","really-input-string",2
 ] in
 let env=List.fold_left (fun env (source,pkg,name,n) -> add env source (external_binding pkg name (Function n))) empty spec in
 let env=add env "max_int" (runtime_binding "ocaml-max-int" Value) in
 let gc_type={type_binding=runtime_binding "gc-control" Value;
   labels=["stack_limit",false];private_record=false} in
 let gc_public={empty with records=SM.singleton "Gc.control" gc_type;
   values=SM.of_seq (List.to_seq ["get",SM.find "Gc.get" env.values;"set",SM.find "Gc.set" env.values])} in
 let env={env with records=SM.add "Gc.control" gc_type env.records;
   modules=SM.add "Gc" {package="holai/runtime/stdlib";public=gc_public;template=None} env.modules} in
 let env=add env "Sys.Break" {id=0;source_name="Sys.Break";package="holai/runtime/stdlib";
   printed="sys_break";logical="SYS_BREAK";labels=[];proof_combinator=false;
   kind=Constructor {fields=0;tuple_payload=None;record_fields=None;private_=false;
    maker="make-sys_break";maker_logical="MAKE-SYS_BREAK";exception_=true;family="ocaml.exn";
    non_tuple_payload=false;previous=None}} in
 let list_functions=["length",1;"hd",1;"tl",1;"nth",2;"rev",1;"rev_append",2;
   "map",2;"map2",3;"mapi",2;"rev_map",2;"iter",2;"concat",1;"fold_left",3;"fold_right",3;
   "fold_left2",4;"fold_right2",4;"exists",2;"for_all",2;"for_all2",3;"mem",2;"mem_assoc",2;"assoc",2;"find",2;
   "filter",2;"filter_map",2;"partition",2;"sort",2] in
 let list_env=List.fold_left (fun env (name,n) -> add env name
   (runtime_binding ("list-"^String.map (fun c -> if c='_' then '-' else c) name) (Function n))) empty list_functions in
 let env={env with modules=SM.add "List" {package="holai/runtime/stdlib";public=list_env;template=None} env.modules} in
 let env=List.fold_left (fun env (name,b) -> add env ("List."^name) b) env (SM.bindings list_env.values) in
 let format_functions=["print_string","print-string",1;"print_newline","print-newline",1;
  "pp_print_string","pp-print-string",2;"pp_print_as","pp-print-as",3;
  "pp_print_char","pp-print-char",2;"pp_print_int","pp-print-int",2;"pp_print_cut","pp-print-cut",2;
  "open_box","open-box",1;"close_box","close-box",1;"print_break","print-break",2;
  "open_vbox","open-vbox",1;"pp_open_vbox","pp-open-vbox",2;
  "pp_open_box","pp-open-box",2;"pp_open_hbox","pp-open-hbox",2;"pp_open_hvbox","pp-open-hvbox",2;
  "pp_close_box","pp-close-box",2;"pp_print_space","pp-print-space",2;"pp_print_break","pp-print-break",3;
  "pp_print_flush","pp-print-flush",2;"print_flush","print-flush",1;
  "pp_set_margin","pp-set-margin",2;"pp_set_max_boxes","pp-set-max-boxes",2;
  "pp_get_max_boxes","pp-get-max-boxes",2;"pp_print_newline","pp-print-newline",2;
  "formatter_of_buffer","formatter-of-buffer",1;"get_margin","get-margin",1;
  "set_margin","set-margin",1;"set_max_boxes","set-max-boxes",1;
  "printf","format-printf",1;"fprintf","format-fprintf",2;"asprintf","format-asprintf",1] in
 let format_env=List.fold_left (fun env (name,target,arity) -> add env name (runtime_binding target (Function arity))) empty format_functions in
 let format_env=add format_env "std_formatter" (runtime_binding "std-formatter" Value) in
 let env={env with modules=SM.add "Format" {package="holai/runtime/format";public=format_env;template=None} env.modules} in
 let env=List.fold_left (fun env (name,b) -> add env ("Format."^name) b) env (SM.bindings format_env.values) in
 let env=List.fold_left (fun env (name,target) -> add env name (runtime_binding target (Function 1))) env
   ["Printf.printf","printf-printf";"Printf.sprintf","printf-sprintf"] in
 let env=List.fold_left (fun env (name,target,arity) -> add env name (runtime_binding target (Function arity))) env ["Buffer.create","buffer-create",1;"Buffer.contents","buffer-contents",1;"Buffer.reset","buffer-reset",1] in
 List.fold_left (fun env (name,n) ->
   let b=runtime_binding name Value in
   let maker,maker_logical=maker_spelling b in
   (* Stable constructor-family key, not a Lisp package or ASDF system name. *)
   let family=if name="Some" || name="None" then "holai.runtime.option" else "ocaml.exn" in
   add env name {b with kind=Constructor {fields=n;tuple_payload=None;record_fields=None;private_=false;maker;maker_logical;exception_=true;family;non_tuple_payload=(n=1 && name<>"Some" && name<>"Assert_failure");previous=None}})
   env ["Failure",1;"Invalid_argument",1;"Sys_error",1;"End_of_file",0;"Not_found",0;"Some",1;"None",0;"Assert_failure",1]
