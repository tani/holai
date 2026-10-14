> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname.

# Percent suffix identifiers

The translator uses % for added primes/reserved-name/reader-atom encoding and
case/scope collision suffixes. Original operator stars, HOL strings, native
CL targets and genuine runtime special-variable names remain unchanged.

| Source | Generated |
|---|---|
| x' / x'' | x% / x%% |
| t / t' | t% / t%% |
| nil / pi | nil% / pi% |
| mk_comb / MK_COMB in one namespace | mk_comb / MK_COMB% |
| *-> with a colliding local binding | *->% |

Append % until the reader-normalized symbol is free. References, exports,
constructors, makers and record keywords retain binding-aware allocation.
Existing ~n versions and internal fresh names remain. The regression fixture
checks21 atom/allocator/native-target cases and9 OCaml/SBCL observations plus
9 expected exports. Original-star preservation is explicitly checked.

Unused values are retained with IGNORABLE declarations in generated LET/LET*,
defunc/lambdac/labelsc/fletc parameter entries and MATCH input temporaries.
The input expression is still evaluated once for wildcard matches. Single-let
flattening retains its prior behavior with the new declarations. No source
algorithm, evaluation order, data representation, SPECIAL declaration or
compiler optimization option changes. No diagnostics are globally muffled.

Production diagnostics are audited independently using a fresh ASDF cache:
python3 misc/scripts/check-compile-diagnostics.py. Raw output and classified counts
are saved as compile-diagnostics.txt/JSON. Full corpus evidence is recorded
in verification.json and clean-build.json. Earlier structural/OPTIONAL/native
timings are historical and have not been remeasured for percent naming.

The source ZIP includes DESIGN.md, AGENTS.md, all translator/runtime sources,
generated Lisp/maps, tests and reports. Existing star-names fixture filenames
are retained as regression identifiers; their expected names now use %.

## Completed validation

All46 production inputs and1124 differential rows pass, as do122 native,27
protocol,84 OPTIONAL,16 tuple and46 structural-pattern checks. The94 generated
outputs match a clean source build, with unchanged upstream pins/maps.

Fresh-cache compilation of all51 production files completes with:

| Diagnostic | Count |
|---|---:|
| Compile errors | 0 |
| WARNING | 0 |
| STYLE-WARNING | 0 |
| Warning notices | 0 |

Packaging requires the completion marker and matching code fingerprints.
