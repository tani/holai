let example () =
  let rec walk n = if n = 0 then saved else walk (n-1)
  and saved =
    let module Hidden = struct let captured = walk end in
    Hidden.captured 0 in
  walk 1;;
