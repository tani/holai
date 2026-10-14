let checks = ref 0
let check x = incr checks; if not x then failwith "Star allocator check"
let () =
 List.iter (fun (source,target) -> check (Sexp.symbol source=target))
   ["foo","foo";"x'","x%";"x''","x%%";"t","t%";"t'","t%%";
    "nil","nil%";"nil'","nil%%";"pi","pi%";"pi'","pi%%";
    "nan","nan%";"nan'","nan%%";"|!","%!";"1.0","1.0%";"&","%"];
 let used=Scope.SS.of_list ["FOO";"FOO%"] in
 check (Scope.allocate_suffix (fun name -> Scope.SS.mem name used) "foo"=("foo%%","FOO%%"));
 check (Scope.allocate_suffix (fun _ -> false) "Foo"=("Foo","FOO"));
 List.iter (fun name -> let b=Scope.external_binding "cl" name Scope.Value in
   check (b.printed=name && b.logical=String.uppercase_ascii name)) ["t";"nil";"pi"];
 check (Sexp.symbol "*->"="*->");
 check (Scope.allocate_suffix (fun s -> s="*->") "*->"=("*->%","*->%"));
 print_endline ("Star allocator checks passed: " ^ string_of_int !checks)
