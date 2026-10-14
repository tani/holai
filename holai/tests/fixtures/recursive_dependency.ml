let same = 9;;
let rec walk n = if n = 0 then same else walk (n-1)
and same = (fun x -> x) same;;
