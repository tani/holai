module type Visible = sig type t = Shared of int end;;
module Hidden : Visible = struct
  type hidden = Shared of int * int
  type t = Shared of int
end;;
open Hidden;;
let hidden_constructor = function Shared(a,b) -> a+b;;
