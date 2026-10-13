# Unescaped star-suffix names: 1.0.0-star-names

Generated source identifiers use ordinary Common Lisp reader atoms. The readtable
and default case conversion are unchanged. This intentionally changes public
Lisp spellings; source OCaml bindings and HOL strings keep their original names.

| OCaml example | Generated example |
|---|---|
| mk_comb | mk_comb |
| MK_COMB in the same owned namespace | MK_COMB* |
| Abs constructor / ABS rule | Abs / ABS* |
| x' / x'' | x* / x** |
| t / t' | t* / t** |
| nil / pi | nil* / pi* |

The final number of stars depends on other visible/owned names. If name, name'
and name'' already occupy NAME, NAME* and NAME**, NAME becomes NAME***.
Safe ordinary names stay unchanged. Unsafe reader characters become stars;
reserved T/NIL/PI and numeric-looking stems add an extra star. Reserved primed
stems also include that extra star, making record fields t and t' distinct.
Names are compared after uppercase reader normalization. Add stars until a free
logical symbol exists. Owned global names are planned with lowercase first,
then mixed case, then all-uppercase; ties use deterministic source spelling.
Local names respect visible bindings, imports and owned global names, retaining
their source binding order where there is no planned global group.

Bindings store their allocated printed/logical names; definitions, references,
imports and exports use these records. Makers derive from allocated names and
match runtime macro construction. Existing ~n global versioning and macro-private
fresh identifiers remain. Primed module package names are encoded consistently.
Fixed foreign targets retain their native names: CL:T/NIL/PI do not become
source-binder names. Literal strings/comments are never rewritten.

## Verification

- 19 isolated atom/allocation/native-link checks.
- 9 observations from a new OCaml fixture match SBCL exactly.
- 9 expected exports, including NAME*** and reserved primed names, are checked.
- Fixture covers local/parallel case collisions, primes, reserved binders,
  record fields/update, constructor/value collisions, primed modules and a
  literal string containing vertical bars.
- All46generated core files have zero escaped-symbol delimiters outside
  strings/comments. Existing namespace and constructor collision regressions pass.
- Full fresh corpus:122native,27protocol,84OPTIONAL,16tuple checks;1124matching
  OCaml/SBCL observations. Counts22/303/263/3 and original axiom set preserved.
- All94outputs match a clean source build; maps and source pins pass. Ten
  rejection checks and deterministic regeneration pass.
- The final foreign-name preservation refinement changes no generated core
  bytes; all94outputs were compared and naming checks rerun afterward.

The runtime and pinned upstream inputs are unchanged. No new optimization,
fixed worker, call-site routing or performance measurement is introduced.
Earlier benchmark results refer to the previous naming version.

Reproduce with `make test` and `make clean-build`; the naming fixture runs as
part of tests/run.py. Its raw observation/allocator result is star-names.json.
