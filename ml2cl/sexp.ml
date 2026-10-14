(* Output syntax and deterministic, source-aware formatting. *)
type origin = { id:int; source:string; first:int; last:int; line:int; rule:string }
type t = Atom of string | DeferredAtom of string ref | List of t list | ReaderPrefix of t | Fragment of t list | Origin of origin * t | Comment of string
type mapping = { origin:origin; output_first:int; output_last:int }
let a s = Atom s
let l xs = List xs
let reader_prefix x = ReaderPrefix x
let fragment xs = Fragment xs
let form h xs = l (a h :: xs)
let rec unwrap = function Origin (_,x) -> unwrap x | x -> x
let rec flat_length = function
  | Atom s -> String.length s
  | DeferredAtom s -> String.length !s
  | List xs -> 2 + max 0 (List.length xs-1) + List.fold_left (fun n x -> n + flat_length x) 0 xs
  | Fragment xs -> max 0 (List.length xs-1) + List.fold_left (fun n x -> n + flat_length x) 0 xs
  | ReaderPrefix x -> 2 + flat_length x
  | Origin (_,x) -> flat_length x
  | Comment _ -> 1000000
let symbol s =
  let safe = function
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' | '-' | '+' | '*' | '/' | '='
    | '<' | '>' | '?' | '!' | '~' | '^' | '%' | '@' | '.' -> true
    | _ -> false in
  let stem=String.concat "" (String.split_on_char '\'' s) in
  let reserved=List.mem (String.lowercase_ascii stem) ["t";"nil";"pi"] in
  let printed=String.map (fun c -> if safe c then c else '%') s in
  let printed=if printed="" then "%" else printed in
  let numeric=try ignore (float_of_string stem); true with Failure _ -> false in
  if reserved || numeric || printed="." then printed^"%" else printed
let string s =
  let b=Buffer.create 16 in Buffer.add_char b '"';
  String.iter (fun c -> if c='"' || c='\\' then Buffer.add_char b '\\'; Buffer.add_char b c) s;
  Buffer.add_char b '"'; Atom (Buffer.contents b)
let json_string s =
  let b=Buffer.create 16 in Buffer.add_char b '"';
  String.iter (function
    | '"' -> Buffer.add_string b "\\\"" | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n" | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.code c < 32 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"'; Buffer.contents b
let render ?(width=90) ?(prefix="") forms =
  let b=Buffer.create 4096 and maps=ref [] and col=ref 0 in
  let put s = Buffer.add_string b s;
    (match String.rindex_opt s '\n' with None -> col:= !col+String.length s | Some n -> col:=String.length s-n-1) in
  let newline n = put ("\n" ^ String.make n ' ') in
  let rec emit ?leading_override indent x = match x with
    | Origin (o,x) -> let first=Buffer.length b in emit ?leading_override indent x;
      maps:={origin=o;output_first=first;output_last=Buffer.length b}:: !maps
    | Atom s -> put s
    | DeferredAtom s -> put !s
    | ReaderPrefix x -> put "#`"; emit indent x
    | Comment s -> String.split_on_char '\n' s |> List.iter (fun line -> put (";; "^line);newline indent)
    | Fragment _ -> emit_fragment indent (flat_length x + !col > width) x
    | List xs when flat_length x + !col <= width ->
      put "("; List.iteri (fun i x -> if i>0 then put " "; emit indent x) xs; put ")"
    | List [] -> put "()"
    | List [head;body] when
        (match unwrap head with
         | Atom ("proof" | "holai.runtime.core:proof") -> true
         | DeferredAtom s -> !s="proof" || !s="holai.runtime.core:proof"
         | _ -> false) &&
        (match unwrap body with Fragment _ -> true | _ -> false) ->
      put "("; emit indent head; put " ";
      emit_fragment (indent+2) true body; put ")"
    | List (h::xs) ->
      put "("; emit indent h;
      let head=match unwrap h with Atom "cl:lambda" -> "lambda" | Atom s -> s | DeferredAtom s -> !s | _ -> "" in
      let leading=match leading_override with Some n -> n | None -> match head with
        | "defun" | "defunc" -> 2 | "lambda" | "lambdac" | "labelsc" | "fletc" | "let" | "let*" | "labels" | "match" | "if" | "defvariant" | "define-exception" -> 1
        | "defparameter" | "defpackage" | "in-package" -> 1 | _ -> 0 in
      List.iteri (fun i x ->
        if i<leading && flat_length x + !col+1<=width then put " " else newline (indent+2);
        if i=0 && (head="labelsc" || head="holai.runtime.core:labelsc") then emit_definitions (indent+2) x
        else emit (indent+2) x) xs; put ")"
  and emit_definitions indent x = match x with
    | List definitions when flat_length x + !col > width ->
      put "(";
      List.iteri (fun i definition ->
        let depth=if i=0 then indent else indent+2 in
        if i>0 then newline depth;
        emit ~leading_override:1 depth definition) definitions;
      put ")"
    | _ -> emit indent x
  and emit_fragment indent broken x = match x with
    | Origin (o,x) ->
      let first=Buffer.length b in emit_fragment indent broken x;
      maps:={origin=o;output_first=first;output_last=Buffer.length b}:: !maps
    | Fragment [] -> ()
    | Fragment (left::pairs) ->
      (match unwrap left with
       | Fragment _ -> emit_fragment indent broken left
       | _ -> emit indent left);
      let rec emit_pairs = function
        | [] -> ()
        | operator::right::rest ->
          if broken then newline indent else put " ";
          emit indent operator;
          if broken && flat_length right + !col+1 > width then (
            newline (indent+2); emit (indent+2) right
          ) else (put " "; emit indent right);
          emit_pairs rest
        | _ -> invalid_arg "Sexp.Fragment: expected operand/operator pairs" in
      emit_pairs pairs
    | _ -> emit indent x
  in
  put prefix;
  List.iter (fun x -> emit 0 x; put "\n\n") forms;
  Buffer.contents b, List.sort (fun a b -> compare a.origin.id b.origin.id) !maps
let mappings_json maps =
  let one m = let o=m.origin in
    Printf.sprintf "{\"id\":%d,\"source\":%s,\"source_start\":%d,\"source_end\":%d,\"line\":%d,\"rule\":%s,\"output_start\":%d,\"output_end\":%d}"
      o.id (json_string o.source) o.first o.last o.line (json_string o.rule) m.output_first m.output_last
  in "[\n" ^ String.concat ",\n" (List.map one maps) ^ "\n]\n"
