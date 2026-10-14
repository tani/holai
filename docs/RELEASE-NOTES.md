# Holai 1.0.0-percent-names

Production matching no longer depends on Trivia. The new static pattern
compiler validates bindings, OR alternatives, constructor arities and record
keys, and emits standard Common Lisp type tests, field accesses and bindings.
Existing data representations and defunc/lambdac/labelsc/fletc remain unchanged.

Generated guards use runtime:guard. Character literals use character-code
patterns, avoiding synthetic variable collisions. Constructor metadata is
available during compilation and loading; FASLs detect changed declaration
signatures and require rebuilding. OR joins share bodies and guards.

DESIGN30 describes the implementation; holai/tests/pattern.lisp covers semantics,
negative expansion cases, wide/deep patterns and separate compilation. Full
core and timing evidence is recorded in misc/reports/verification.json and
misc/reports/PATTERN-MATCH.md. The old Trivia sources and licenses are available in the historical
Git revision used for comparisons.

Translator-added suffixes are now percent signs instead of stars. Original
operator stars remain unchanged. Curried parameters, MATCH input temporaries
and translated LET/LET* bindings carry IGNORABLE declarations. Scope, bindings
and source algorithms are preserved. Previous timing results are historical.

Obsolete vendor/lisp dependencies and their ASDF search entries are removed.

## Layout and API cutover

Translator sources now live directly in `ml2cl/`; use `bin/ml2cl`. Lisp runtime, generated code and tests live under `holai/`. Production packages are `holai.runtime` and `holai.<input-stem>` (including nested module packages); ASDF systems are `holai-runtime` and `holai-generated`. Update callers and rebuild FASLs; there are no compatibility aliases. Scripts and reports live under `misc/`. This supersedes the earlier organization-only retain-hol2cl policy. Algorithms, data representations, pinned input bytes and source provenance remain unchanged. Historical raw reports retain their measured old paths/names and are not evidence of a new timing run.

Validated in the pinned aarch64-linux Nix shell with `make release`: 46 core
inputs, 1,124 matching differential observations, 51 production units with
zero diagnostics, and 94 identical clean-generated files. Both relocated SBCL
launchers initialized from outside the repository. Historical timings were
not remeasured.

## Shared PROOF tactical notation

`holai.runtime:proof` now provides handwritten and generated infix tactical
composition, preserving the original binary call tree and proof algorithms.
Operators are value symbols (THEN/THENL) or named function references
(`#'ORELSE`); all fold left, with inner PROOF forms for right grouping.
THENL retains ordinary Lisp branch lists. Translation is gated by canonical
binding identity, not spelling; aliases, shadowing, partial applications and
direct goal calls keep their ordinary paths. Fragment output preserves
`proof-tactical` source ranges for joined left prefixes and child operands.
See DESIGN §33 and the README's fully qualified handwritten example.

Completed reader-inclusive validation used `nix develop path:. --command make release` on
aarch64-linux (OCaml 4.14.2, Camlp5 8.02.01, SBCL 2.3.9.nixos): all 46
inputs initialized, 122 existing native and 61 independent PROOF checks
passed, and all 1,132 differential rows matched (1,125 serialized plus seven
actual side-effect rows), including eight new tactical observations.
A separate fresh sharp-backquote handwritten smoke proved the actual closed
identity theorem. The new unit is
compiled/loaded only after observation capture and std_formatter stream
restoration; its `proof_dsl_checks` counter is isolated from observations.

The initial 22/303/263/3 registries and exactly three source axioms are
unchanged. The 5,519 OCaml/5,517 SBCL initialization rows retain the known
exact two OCaml-only differences. Audits passed for 194,839 core/205,472
inclusive map entries and ten output-preserving rejections; generated core
Lisp is 6,943,214 bytes with 9,100 `proof-tactical` map entries. All 51
production units compiled with zero errors/warnings/style warnings, all 94
clean outputs matched and all 55 retained input hashes were unchanged.
The verified ZIP includes the new unit, translator, design, generated
Lisp/maps, reports and matching streams. Version remains
1.0.0-percent-names; no publication or new performance result is claimed.

### Authorized sharp-backquote reader

Runtime `sharp-backquote-lambda-reader` now installs #` dispatch in the active
`*readtable*` at compile/load/execute time, alongside unchanged standard `#'`.
Load the runtime before reading consumer files. Copies inherit the extension;
fresh standard readtables made from NIL do not. `readtable-case` and source
identifier atoms remain unchanged.

Where `#'name` denotes a named function, sharp-backquote wraps one read
value/expression form in `CL:LAMBDA` with a gensym rest parameter. Each call
evaluates the expression anew and uses `CL:APPLY` to preserve all arguments
and multiple values. The README shows a real PROOF using
``#`holai.tactics:DISCH_TAC`` and ``#`holai.tactics:ACCEPT_TAC``.
The wrapper is an operand, not directly a PROOF operator reference; bind it
to a lexical value symbol for that role. Grammar and translator output do not
change.

The runtime-only compile/load smoke passed, covering per-call evaluation,
dynamic rebinding, zero/multiple/NIL arguments, multiple values, gensym hygiene
and unchanged `#'`. The completed reader-inclusive release measured 61 PROOF
checks, including thirteen permanent reader checks with actual zero-argument
sum, positional decimal calculation, NIL classification, floor quotient/
remainder and lexical-argument hygiene computations. This runtime addition
leaves the 1,132 differential rows, 205,472 inclusive maps and 51 production
units unchanged; no publication or performance result is claimed.

## Pending discussion

- TODO: Start a discussion of potentially excessive `funcall` usage in this project. Distinguish `holai.runtime:funcall` and curried application from native `CL:FUNCALL`; measure actual call hotspots and allocation before proposing changes. This is an investigation topic, not a demonstrated performance problem or an optimization included in this layout/API cutover.
