# Holai 1.0.0-star-names

Replace escaped source symbols with ordinary reader atoms. Primes/reserved
names and case/scope collisions receive star suffixes. Definitions, references,
exports, constructor makers and primed module packages remain consistent.
Public Lisp names change intentionally; runtime behavior and HOL strings do not.

19allocator checks and9new OCaml/SBCL observations pass; zero escaped symbols
in46generated core files. Full122native/27protocol/84OPTIONAL/16tuple checks,
1124differential rows,10rejections and94clean-generated outputs pass.
Previous timing/memory results remain historical. See reports/STAR-NAMES.md.
