type holder = { contents:int };;
let ambiguous = function {contents = n} -> n;;
