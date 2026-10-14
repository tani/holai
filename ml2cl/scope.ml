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
 reference_observer:(binding -> unit) ref; mutable owned_logicals:SS.t option }
let context ?(counter=ref 0) ?(reference_observer=ref (fun (_:binding) -> ())) ?lexical_prefix package source text items =
 let own=own_names items in
 let totals=List.fold_left (fun m s -> SM.add s (1+Option.value (SM.find_opt s m) ~default:0) m) SM.empty own in
 let spellings,_=List.fold_left (fun (names,used) source ->
   let printed,logical=allocate_suffix (fun logical -> SS.mem logical used || List.mem logical control_names)
       (Sexp.symbol (source_spelling source)) in
   SM.add source (printed,logical) names,SS.add logical used)
   (SM.empty,SS.empty) (List.sort_uniq compare_source_names own) in
 {package;source;text;own;spellings;totals;occurrences=SM.empty;globals=SS.empty;local_functions=SS.empty;local_symbols=SS.empty;makers=SS.empty;next=counter;
  imports=SM.empty;exports=SM.empty;dependencies=[];rules=SM.empty;lexical_prefix;metadata=[];reference_observer;owned_logicals=None}
let fresh c stem = incr c.next; stem^"~"^string_of_int !(c.next)
let spelling c s =
 match SM.find_opt s c.spellings with Some spelling -> spelling | None ->
 let printed=Sexp.symbol (source_spelling s) in printed,String.uppercase_ascii printed
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
   let occupied logical = SS.mem logical reserved_targets || SS.mem logical c.local_symbols in
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
 let printed,logical=spelling c source_name in
 let forbidden logical =
   SS.mem logical reserved_targets ||
   List.mem logical control_names || SS.mem logical c.globals || SM.mem logical c.imports ||
   SM.exists (fun _ (b:binding) -> b.logical=logical) env.values ||
   List.exists (fun source -> snd (spelling c source)=logical) c.own in
 let printed,logical=allocate_suffix forbidden printed in
 (match kind with Function _ -> c.local_functions<-SS.add printed c.local_functions | _ -> ());
 c.local_symbols<-SS.add logical c.local_symbols;
 incr c.next; {id= !(c.next);source_name;package="";printed;logical;kind;labels=[];proof_combinator=false}
let external_binding package name kind =
 (* Fixed foreign targets retain their native spelling, including CL constants. *)
 let printed=name in
 {id=0;source_name=name;package;printed;logical=String.uppercase_ascii printed;kind;labels=[];proof_combinator=false}
let reference c (b:binding) =
 !(c.reference_observer) b;
 if b.package="" || b.package=c.package then b.printed
 else if c.lexical_prefix<>None then b.package^":"^b.printed
 else
 let owned=match c.owned_logicals with Some set -> set | None ->
   let set=List.fold_left (fun set s -> let _,k=spelling c s in SS.add ("MAKE-"^k) (SS.add k set)) SS.empty c.own in
   c.owned_logicals<-Some set;set in
 let own_conflict=SS.mem b.logical c.local_symbols || SS.mem b.logical owned in
 match SM.find_opt b.logical c.imports with
 | Some old when old.package<>b.package || old.printed<>b.printed -> b.package^":"^b.printed
 | _ when own_conflict -> b.package^":"^b.printed
 | _ -> c.imports<-SM.add b.logical b c.imports; b.printed
let runtime c name = reference c (external_binding "holai.runtime" name Value)
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
  "+","cl","+",2; "-","cl","-",2; "*","cl","*",2; "/","holai.runtime","int-div",2;
  "~-","cl","-",1; "~-.","cl","-",1; "mod","holai.runtime","int-mod",2;
  "+.","cl","+",2; "-.","cl","-",2; "*.","cl","*",2; "/.","cl","/",2;
  "=","holai.runtime","=",2; "<>","holai.runtime","<>",2;
  "==","holai.runtime","==",2; "!=","holai.runtime","!=",2;
  "<","holai.runtime","<",2; ">","holai.runtime",">",2;
  "<=","holai.runtime","<=",2; ">=","holai.runtime",">=",2;
  "compare","holai.runtime","compare",2; "not","cl","not",1;
  "String.compare","holai.runtime","compare",2;
  "Num.mod_num","holai.runtime","mod-num",2; "Num.quo_num","holai.runtime","quo-num",2;
  "is_integer_num","cl","integerp",1; "succ_num","cl","1+",1;
  "Char.code","cl","char-code",1; "Char.chr","holai.runtime","char-chr",1;
  "String.make","holai.runtime","string-make",2; "String.escaped","holai.runtime","string-escaped",1;
  "int_of_string","holai.runtime","int-of-string",1;
  "Array.make","holai.runtime","array-make",2; "Array.get","holai.runtime","array-get",2; "Array.set","holai.runtime","array-set",3;
  "Array.fold_left","holai.runtime","array-fold-left",3;
  "Array.of_list","holai.runtime","array-of-list",1; "Array.map","holai.runtime","array-map",2;
  "minus_num","cl","-",1; "int_of_num","holai.runtime","int-of-num",1;
  "Gc.get","holai.runtime","gc-get",1; "Gc.set","holai.runtime","gc-set",1;
  "Sys.catch_break","holai.runtime","catch-break",1;
  "List.fold_left","holai.runtime","list-fold-left",3; "List.exists","holai.runtime","list-exists",2;
  "||","holai.runtime","bool-or",2; "or","holai.runtime","bool-or",2;
  "&&","holai.runtime","bool-and",2; "&","holai.runtime","bool-and",2;
  "@","cl","append",2; "^","holai.runtime","string-concat",2;
  "ref","holai.runtime","ref",1; "!","holai.runtime","deref",1;
  ":=","holai.runtime","assign",2; "raise","holai.runtime","raise",1;
  "failwith","holai.runtime","failwith",1; "invalid_arg","holai.runtime","invalid-arg",1;
  "fst","holai.runtime","fst",1; "snd","holai.runtime","snd",1;
  "abs","cl","abs",1; "max","cl","max",2; "min","cl","min",2;
  "land","cl","logand",2; "lor","cl","logior",2; "lxor","cl","logxor",2; "lnot","cl","lognot",1;
  "lsl","holai.runtime","int-lsl",2;
  "lsr","holai.runtime","int-lsr",2;
  "asr","holai.runtime","int-asr",2;
  "incr","holai.runtime","ref-incr",1;"decr","holai.runtime","ref-decr",1;
  "ignore","holai.runtime","ignore-value",1;
  "print_endline","holai.runtime","print-endline",1;
  "Lazy.force","holai.runtime","lazy-force",1;
  "float_of_int","holai.runtime","float-of-int",1;
  "int_of_float","holai.runtime","int-of-float",1;
  "floor","holai.runtime","float-floor",1;"sqrt","cl","sqrt",1;"float_sqrt","cl","sqrt",1;
  "log","cl","log",1;"exp","cl","exp",1;"**","cl","expt",2;
  "Random.init","holai.runtime","random-init",1;
  "Random.bits","holai.runtime","random-bits",1;"Random.int","holai.runtime","random-int",1;
  "Hashtbl.create","holai.runtime","table-create",1;"Hashtbl.clear","holai.runtime","table-clear",1;
  "Hashtbl.add","holai.runtime","table-add",3;"Hashtbl.replace","holai.runtime","table-replace",3;
  "Hashtbl.find","holai.runtime","table-find",2;
  "Hashtbl.remove","holai.runtime","table-remove",2;
  "Hashtbl.fold","holai.runtime","table-fold",3;
  "String.length","holai.runtime","string-length",1; "String.sub","holai.runtime","string-sub",3;
  "String.concat","holai.runtime","string-join",2; "String.get","holai.runtime","string-get",2;
  "num","holai.runtime","num",1; "numdom","holai.runtime","numdom",1;
  "gcd_num","holai.runtime","gcd-num",2; "abs_num","holai.runtime","abs-num",1;
  "power_num","holai.runtime","power-num",2; "quo_num","holai.runtime","quo-num",2;
  "mod_num","holai.runtime","mod-num",2; "Num.int_of_num","holai.runtime","int-of-num",1;
  "string_of_num","holai.runtime","string-of-num",1;
  "string_of_int","holai.runtime","string-of-int",1; "string_of_float","holai.runtime","string-of-float",1;
  "+/","cl","+",2; "-/","cl","-",2; "*/","cl","*",2; "//","cl","/",2;
  "=/","holai.runtime","=",2; "</","holai.runtime","<",2; ">/","holai.runtime",">",2;
  "<=/","holai.runtime","<=",2; ">=/","holai.runtime",">=",2; "<>/","holai.runtime","<>",2;
  "Format.print_string","holai.runtime","print-string",1;
  "Format.print_newline","holai.runtime","print-newline",1;
  "Format.pp_print_string","holai.runtime","pp-print-string",2;
  "Sys.time","holai.runtime","cpu-time",1; "Printexc.to_string","holai.runtime","exception-string",1;
  "Hashtbl.hash","holai.runtime","structural-hash",1;
  "open_in","holai.runtime","open-in",1; "open_in_bin","holai.runtime","open-in-bin",1;
  "open_out","holai.runtime","open-out",1; "input_line","holai.runtime","input-line",1;
  "close_in","holai.runtime","close-channel",1; "close_out","holai.runtime","close-channel",1;
  "output_string","holai.runtime","output-string",2;
  "in_channel_length","holai.runtime","channel-length",1;
  "really_input_string","holai.runtime","really-input-string",2
 ] in
 let env=List.fold_left (fun env (source,pkg,name,n) -> add env source (external_binding pkg name (Function n))) empty spec in
 let env=add env "max_int" (external_binding "holai.runtime" "ocaml-max-int" Value) in
 let gc_type={type_binding=external_binding "holai.runtime" "gc-control" Value;
   labels=["stack_limit",false];private_record=false} in
 let gc_public={empty with records=SM.singleton "Gc.control" gc_type;
   values=SM.of_seq (List.to_seq ["get",SM.find "Gc.get" env.values;"set",SM.find "Gc.set" env.values])} in
 let env={env with records=SM.add "Gc.control" gc_type env.records;
   modules=SM.add "Gc" {package="holai.runtime";public=gc_public;template=None} env.modules} in
 let env=add env "Sys.Break" {id=0;source_name="Sys.Break";package="holai.runtime";
   printed="sys_break";logical="SYS_BREAK";labels=[];proof_combinator=false;
   kind=Constructor {fields=0;tuple_payload=None;record_fields=None;private_=false;
    maker="make-sys_break";maker_logical="MAKE-SYS_BREAK";exception_=true;family="ocaml.exn";
    non_tuple_payload=false;previous=None}} in
 let list_functions=["length",1;"hd",1;"tl",1;"nth",2;"rev",1;"rev_append",2;
   "map",2;"map2",3;"mapi",2;"rev_map",2;"iter",2;"concat",1;"fold_left",3;"fold_right",3;
   "fold_left2",4;"fold_right2",4;"exists",2;"for_all",2;"for_all2",3;"mem",2;"mem_assoc",2;"assoc",2;"find",2;
   "filter",2;"filter_map",2;"partition",2;"sort",2] in
 let list_env=List.fold_left (fun env (name,n) -> add env name
   (external_binding "holai.runtime" ("list-"^String.map (fun c -> if c='_' then '-' else c) name) (Function n))) empty list_functions in
 let env={env with modules=SM.add "List" {package="holai.runtime";public=list_env;template=None} env.modules} in
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
 let format_env=List.fold_left (fun env (name,target,arity) -> add env name (external_binding "holai.runtime" target (Function arity))) empty format_functions in
 let format_env=add format_env "std_formatter" (external_binding "holai.runtime" "std-formatter" Value) in
 let env={env with modules=SM.add "Format" {package="holai.runtime";public=format_env;template=None} env.modules} in
 let env=List.fold_left (fun env (name,b) -> add env ("Format."^name) b) env (SM.bindings format_env.values) in
 let env=List.fold_left (fun env (name,target) -> add env name (external_binding "holai.runtime" target (Function 1))) env
   ["Printf.printf","printf-printf";"Printf.sprintf","printf-sprintf"] in
 let env=List.fold_left (fun env (name,target,arity) -> add env name (external_binding "holai.runtime" target (Function arity))) env ["Buffer.create","buffer-create",1;"Buffer.contents","buffer-contents",1;"Buffer.reset","buffer-reset",1] in
 List.fold_left (fun env (name,n) ->
   let b=external_binding "holai.runtime" name Value in
   let maker,maker_logical=maker_spelling b in
   let family=if name="Some" || name="None" then "holai.runtime.option" else "ocaml.exn" in
   add env name {b with kind=Constructor {fields=n;tuple_payload=None;record_fields=None;private_=false;maker;maker_logical;exception_=true;family;non_tuple_payload=(n=1 && name<>"Some" && name<>"Assert_failure");previous=None}})
   env ["Failure",1;"Invalid_argument",1;"Sys_error",1;"End_of_file",0;"Not_found",0;"Some",1;"None",0;"Assert_failure",1]
