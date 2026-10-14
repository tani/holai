# HOL Light → SBCL + Trivia: translation design

Version: 1.0.0-star-names (OPTIONAL common entry experiment; sections 1–22 retain
the 1.0.0 baseline contract and historical results,
2026-10-13).

The original design was saved **before implementation**; the continuation plan
was added before extending the initial release. This document is part of every release,
along with `AGENTS.md`, the complete OCaml translator, runtime sources, and tests.
The implementation status at the end is updated from actual test results.

## 1. Purpose and priority

Translate HOL Light's OCaml source reproducibly into Common Lisp that a person
can read beside the original, inspect in SBCL, and debug. The input is the real
HOL Light grammar, including its Camlp5 `pa_j` extension.

Priority, in order:

1. Preserve source syntax, binding structure, declaration boundaries, names,
   patterns, algorithms, and the direction of recursive calls.
2. Produce ordinary, reasonably shallow Lisp forms, using Trivia for patterns.
3. Make every transformation deterministic and traceable to source locations.
4. Preserve observable behavior where these priorities allow; report differences
   and test the runtime and kernel separately.

Do not insert temporaries to simulate a particular OCaml argument evaluation
order. Common Lisp's left-to-right argument evaluation is accepted. Do not
inline, fuse functions, replace recursion with loops, perform CSE, reorder
declarations, or replace the algorithm with a library implementation.

This is a source translator, not an OCaml VM and not a formally verified
compiler. A successful translation does not constitute a proof of HOL kernel
soundness. Runtime and translation bugs remain in the trusted implementation.

## 2. Deliverable and layout

```text
holai/
  DESIGN.md                 this specification and measured status
  AGENTS.md                 working rules and verification requirements
  README.md                 build, CLI, and limitations
  Makefile                  build, regeneration, test, release
  ml2cl/                    five OCaml translator modules, flattened
  holai/runtime/            Common Lisp compatibility layer
  holai.asd                 single root ASDF definition and provider registry
  holai/all.lisp            inferred terminal-core entry
  holai/generated/          generated Lisp, maps and package-systems.sexp
  holai/tests/fixtures/     small source regression examples
  holai/tests/              compiler, runtime and differential tests
  misc/scripts/             reusable build, release and measurement scripts
  misc/reports/             current evidence and preserved history/
  vendor/                   pinned input files and third-party notices
  docs/                     repository policy, release notes and design history
```

The release target must fail if DESIGN.md, AGENTS.md, any translator source,
runtime source, pinned source inputs, or regression fixtures are absent.
Generated files are never hand-edited. Repair the translator and regenerate.
Temporary compiler outputs and dependency checkout histories are not releases.

Current user-authorized API contract: CLI `bin/ml2cl`, runtime package
`holai.runtime`, generated packages `holai.<input-stem>` and their nested module
packages, ASDF systems `holai`, `holai/runtime` and inferred
`holai/generated/<input-stem>` systems. No compatibility aliases or `rt`
nickname are introduced. This supersedes the earlier AGENTS
retain-hol2cl rule and section 28's organization-only API policy. Algorithms,
data representations, vendor input bytes/digests and source identities do not
change. Generated Lisp and maps must be regenerated together for new names.
Root `_build/`, `bin/`, `dist/`, build files, licensing and vendor inputs remain.
The historical sections below retain old names, paths, archive names and measured
results as facts about their original revisions; raw evidence is relocated, not
rewritten. Their report files now live under `misc/reports/`; old `src/`,
`runtime/`, `generated/`, `tests/` and `scripts/` correspond respectively to
`ml2cl/`, `holai/runtime/`, `holai/generated/`, `holai/tests/` and `misc/scripts/`
only for current candidate code. Baseline checkouts keep their matching old API.
Parsed, lowered, compiled, initialized and differential-tested remain distinct
evidence states; relocation alone does not revalidate or remeasure them.

The layout/API cutover was validated on aarch64-linux inside the pinned Nix
shell with `make release`: all 46 inputs parsed/lowered/compiled/initialized,
1,124 differential rows matched, 51 production units compiled with zero
diagnostics, and 94 clean-generated outputs were identical. All pinned input
hashes remained unchanged. Both relocated SBCL launchers initialized the core
from `/tmp`; the renamed CLI also scanned the semantics fixture there.
The launcher smoke confirmed the new runtime/kernel packages and absence of
the old runtime package. Benchmark cache accounting separately exercised both
historical and relocated generated paths; historical timings were not rerun.

## 3. Front end and supported toolchain

Use OCaml 4.14 and Camlp5 8.02 for the first tested build profile. Load the pinned
HOL Light `pa_j_4.xx_8.02.ml` grammar. Do not silently select a different grammar
when upgrading Camlp5. The CLI must reject an incompatible parser profile or
require an explicit, tested update to the build configuration.

The development environment is declared in `flake.nix`, with its nixpkgs input
pinned by `flake.lock`. The nixpkgs `nixos-23.11` shell supplies OCaml 4.14.2,
Camlp5 8.02.01, camlp-streams 5.0.1, SBCL, Python and GNU Make, with Num
pinned separately to upstream 1.5.
This is a separate development profile from the historical OCaml 4.14.1/
Num 1.5 environment. `make build` remains the translator build entry point.
The shell exports `CAMLPLIB` and `STREAMLIB`; compiler wrappers add Num's include
directory to support existing direct `ocamlc nums.cma` calls without migrating
callers to `ocamlfind`. `CAML_LD_LIBRARY_PATH` exposes Num's runtime stub.
The aarch64-linux shell passed a forced translator build, bytecode/native Num
and SBCL execution, and `make release`: 46 inputs, 1,124 differential rows,
51 production files with zero diagnostics, and 94 identical clean-generated
files. SBCL is 2.3.9. The other three declared platforms were evaluated only.
These checks do not remeasure the historical timing results elsewhere here.

Use Camlp5's **MLast AST**, not a regular-expression approximation and not an
OCaml parser that cannot recognize HOL Light syntax. Separate:

1. Parsing with source locations and the original source text.
2. Binding and constructor resolution in source order.
3. Structural lowering to an annotated Lisp S-expression tree.
4. Deterministic formatting and emission of source maps.

Parsing never evaluates HOL Light code. Directives such as `#use` and dynamic
grammar changes are not executed. A directive outside the declared loading
policy is a diagnostic, not arbitrary code execution.

HOL backtick quotations are parsed by `pa_j`; quotation-expanded expressions
retain their source ranges. The full forty-six-file release executes term
quotations through the translated lexer, parser and type-inference code, and
initializes the complete pinned standard theory stack in manifest order.
Optional HOL Light libraries outside that manifest are not release inputs.

The pinned standard-library Map/Set templates are parsed with the ordinary OCaml
lexer mode of the same grammar, then HOL lexer mode is restored. Neither pass
executes the input. No full OCaml type checker is included: accepted input is
expected to be valid OCaml/HOL Light within the declared structural profile.

## 4. Source-aware representation

MLast remains the source representation. Do not first convert the program into
ANF, CPS, bytecode, or a typed interpreter IR. Use small records for resolved
bindings and modules and an output S-expression type for Lisp.

Each resolved binding records:

- A deterministic binding ID and original spelling.
- Its defining package, emitted symbol, and source location.
- Whether it is a lexical value, global value, named function, or constructor.
- The number of syntactically present leading function parameters, if known.
- Required parameter labels, for statically resolved labelled calls.
- Constructor visibility and module export status, where applicable.

Each emitted source-map entry records an ID, source filename and byte range,
line information, translation rule, and generated byte range. Ranges may nest
or coincide: flattened applications and erased annotations can correspond to
the same Lisp form. Synthetic scaffolding must be distinguished from source
nodes. Never claim that this is a bijection of concrete syntax trees.

The structural audit checks that emitted annotations use declared rules, have
valid source/output ranges, and contain no unsupported placeholders. It is an
engineering check of the declared correspondence, not a semantic proof.

Initial maps cover emitted expressions, patterns and declarations after
lowering, rather than every MLast node: leading parameter syntax, intermediate
application-spine nodes, erased aliases and signature-only nodes are not each
mapped yet. IDs share a counter across a file's child packages. More exhaustive
erased-node tracking is future work, not a claim of this initial audit.

## 5. Binding and symbol rules

Resolve identifiers by lexical scope and declaration order. Nonrecursive `let`
RHSs see the preceding environment; `let rec` functions see the whole recursive
group. Parallel `and` bindings do not see one another's new bindings.

Track different source bindings independently, even if they share a spelling.
Earlier definitions that would be overwritten by a Lisp global definition
receive a deterministic version suffix. References to old definitions keep
their resolved symbol. All ordinary unshadowed definitions keep their names.

Check a lexical binder against the emitted logical symbols of all visible
bindings, including names differing only in case. An inner source r must not
capture an outer source R through the CL reader. Name allocation within a
parallel function group reserves each target symbol before allocating the
next, without changing the source environment used to translate its RHSs.

Local function symbols are tracked for explicit package shadow declarations,
preventing inherited CL names such as ATOM from being used as source binders.
Local functions that would hide generated control syntax instead use the
existing deterministic local suffix. This does not change their source scope.

Normal identifiers are unescaped Lisp symbols and retain underscores. Primes
and reader delimiters become stars; reserved stems add a star. Collisions under
the default CL reader's uppercase normalization add stars until a free target
exists. Owned lowercase names are preferred. Constructor Abs and rule ABS, for
example, become Abs and ABS*. Definitions/references/exports share allocated
binding records. Do not globally change reader case conversion. The explicitly
authorized dispatch extension in section33 does not alter source atoms. See
section29 for the complete allocation contract; earlier escaped spelling is historical.

The grammar encodes some operator identifiers (`F_F` becomes `f_f_`). A fixed
reverse-spelling table restores source-facing names, while binding resolution
uses the authoritative MLast identifiers.

Global values may initially use `defparameter`. Its special-variable behavior
must not infect OCaml lexical variables: a lexical binder sharing a global
value's emitted symbol must receive a distinct local symbol. Record that
rename. A future lexical-global representation must be a documented change.

Package declarations must shadow conflicting CL symbols explicitly. Operators
with reader-hostile names may use descriptive, fixed runtime aliases. Unknown
identifiers are errors; do not invent unresolved Lisp functions and proceed.

## 6. Expression translation

| Source construct | Output / rule |
| --- | --- |
| Literal / identifier | Corresponding Lisp literal or resolved reference |
| `let f x y = e` | `(defun f (x y) ...)` |
| Leading `fun` / `function` | Lambda parameters / one pattern-dispatched argument |
| Nonrecursive local scalar `let` | `let`; a sequential chain may become `let*` |
| Parallel scalar `let ... and ...` | `let`, with RHSs resolved outside the group |
| Local recursive functions | `labels`, preserving the source function group |
| Pattern binding | Trivia destructuring (`match` / `let-match`) |
| `match e with ...` | `match`, with clauses in source order |
| Alias pattern `p as x` | `(and x translated-p)` |
| Guarded branch | `(guard translated-p translated-test)` |
| `if c then a else b` | `if`; missing `else` returns the unit value |
| Sequence | `progn`, flattened only for an actual source sequence |
| `try ... with ...` | Condition handler plus ordered Trivia pattern matching |
| `raise e` | Raise the translated OCaml condition |
| Type annotation | Erased after recording its location and rule |
| Pair / n-tuple | One tuple object, never CL multiple values |
| List / cons | `list` or `cons`; `[]` is `nil` |
| Ref read / write | Small ref-cell runtime operations |
| Rebound prefix `!` | Call its current source binding rather than the default ref reader |
| Required labelled parameter/call | Bind by label, then call ordinary positional parameters |
| `assert e` | Checked condition with source coordinates and unit result |
| Source `while` / `for` | CL loop retaining the source condition, bounds, direction and body |
| `lazy e` | Deferred unit thunk; memoize its value or OCaml exception |
| Local static module | Source-ordered lexical bindings capturing the enclosing scope |
| Record declaration | `defrecord` with source label order and mutability |
| Record literal / copy-update | Keyword construction / `record-update` |
| Record read / write | `record-field` / checked `record-assign` |
| Array literal / pattern | Vector / Trivia vector pattern |
| One-dimensional indexed access / write | Checked runtime array operations |
| String indexed access | Runtime string observation |

Pattern parameters need a generated argument only when CL's lambda list cannot
express the source pattern. These parameters are structural adaptation, not
evaluation-order temporaries. Prefer a short stable name and record the rule.
Do not flatten a pattern binding across a scope boundary where capture could
change. Sequential scalar `let` flattening is allowed only with resolved names.

All wildcard patterns use the `_` spelling recognized by actual Trivia.
Incomplete source
matches must signal an OCaml-compatible match failure, rather than quietly
returning `nil`. Exceptions caught by a wildcard OCaml handler are OCaml
conditions, not every arbitrary Lisp failure.

## 7. Function values and currying

Known, saturated named calls use normal Lisp calls. Underapplication uses
`partial`; overapplication first saturates the syntactic function and then
applies the returned value. Do not infer that a function returns a function
merely because that would make generated calls shorter.

Examples:

```lisp
(defun add (x y) (+ x y))
(add 1 2)
(partial (function-value #'add 2) 1)
```

Higher-order calls use the runtime's `funcall` dispatcher (explicitly imported
instead of CL:FUNCALL). `function-value` registers the known arity of an
escaping named function or lambda and returns an ordinary function. The
dispatcher accepts exact, partial, and excess application; a returned function
is applied only after the preceding syntactic function has been saturated.

This small compatibility boundary is needed because `(funcall f x y)` alone
does not implement OCaml currying when `f` is unknown. Direct first-order calls
remain ordinary `defun` calls. There is no blanket `defcurried` transformation.
Arity metadata must not require nonportable function introspection.

SBCL's arity table uses weak keys to avoid retaining every temporary closure.
If a CL primitive represents different OCaml arities (binary `(-)` and unary
`(~-)`), conflicting registration creates an adapter instead of changing an
existing function value. Source ranges distinguish prefix unary minus from
explicit partial application of binary subtraction.

Tuple and unit parameters each count as **one** OCaml argument. Unit is a
dedicated value. A unit-taking function must not accidentally become a
zero-argument function, especially when passed as a higher-order value.

## 8. Variants, exceptions, and comparison

`defvariant` defines a read-only `defstruct` representation, a positional
constructor, a Trivia constructor pattern, and comparison metadata. Preserve
constructor declaration order and source tuple-versus-multiple-field shape.
For example, `Sequent of (term list * term)` has one tuple payload; the
parentheses affect the AST and must not be discarded opportunistically.

A multiple-field constructor pattern `C _` observes only the constructor tag,
while `C(a,b)` observes its two fields. It does not bind a first-class tuple
payload. A constructor declared with one explicitly parenthesized tuple payload
continues to contain one tuple object. Inline record constructors retain named
keywords, source field order and mutable flags; omitted pattern fields are
Trivia wildcards. General constructor/type checking remains the input compiler's
responsibility.

When source field names do not exist, use deterministic positional names in
the runtime macro expansion; keep that boilerplate out of the generated
translation. Do not manufacture semantic field names from guesswork.

Nullary variants use dedicated canonical objects, not `nil`, so constructors
like `None` and `Empty` remain distinct from empty lists and false.
User exceptions become subclasses of an OCaml-condition base class and have
constructor patterns analogous to variant patterns. `Failure`,
`Invalid_argument`, and match failure have explicit runtime definitions.

Structural equality, physical identity, and comparison are distinct:

- `=` / `<>`: recursive equality for the declared representations.
- `==` / `!=`: identity (`eq`), with CL immediates documented separately.
- `compare`: total ordering for supported numbers, strings, lists, tuples,
  refs, and variants, with tags ordered as OCaml does for each variant type.
- Functional-value structural comparisons are rejected, not mapped to `eq`.

Use CL integers and rationals for the initial `num` compatibility boundary.
Machine-int overflow, float corner cases, cyclic structures, GC-dependent
physical identity, and the exact OCaml hash encoding are not universally
emulated. A compatible structural hash may preserve partial-map correctness
without reproducing the exact shape of OCaml's Patricia tree; disclose and
test this difference. No data-structure algorithm is rewritten by the compiler.

## 9. Modules and the kernel boundary

Each input file has a package. A static nested `module ... = struct ... end`
has a child package. Generate packages before forms that refer to them.
Guarded package shells declare owned exports before full imports are installed,
allowing child/enclosing-package dependencies in both directions. Earlier
versioned owner symbols referenced from a child are interned without making
private constructors public. Source forms still follow declaration order.
`open` modifies source resolution; `include` re-exports resolved public
bindings. Do not blindly put every opened package in `:use`.

Parse module signatures as visibility declarations. For a signature-constrained
module, publish only declared values and visible constructors/patterns. Private
variants expose observation patterns but not their raw constructors. An
external construction of a private variant is a compiler diagnostic.

For `Hol : Hol_kernel`, keep Sequent and its construction functions internal;
publish the declared inference-rule API. `include Hol` must not expose Sequent,
mutable kernel registries, or internal helpers. Common Lisp packages are not
a security boundary against reflective or deliberately privileged code.

Static first-order functors retain the definition-time environment and original
body AST. An application to a named, resolved static module instantiates that
body in a distinct child package. Module aliases reuse the existing public
bindings and runtime values; they do not reinitialize the module. Local modules
retain source-ordered lexical let/flet/labels/pattern scopes. Their values are
initialized at the declaration point on each enclosing invocation, and escaping
closures retain that instance's captured values. Local variant/record metadata
is emitted for compilation while captured values remain lexical.

First-class modules, higher-order/dynamic/unit functors, inline structure
arguments to functors, full generative/abstract-type semantics, GADTs, objects,
polymorphic variants and dynamic include semantics remain outside this untyped
profile. Optional arguments and labelled calls without statically retained
parameter labels are rejected. Declare a functor argument module separately.
Record ownership/explicit module qualifiers are supported; general type-directed
overloaded label selection remains unsupported. Historical Map rules are in
section 14; the expanded Map/Set and 0.6 boundaries are in section 19, and the
0.7 shallow pattern/ref/hash/array rules are in section 20; mixed recursive-group
initialization and the arithmetic checkpoint are in section 21.

Literal `needs "file.ml"` declarations are recognized as static dependency records. They
do not execute the OCaml loader. Multi-file translation follows a declared
ordered manifest and emits package-provider data plus predecessor dependencies
for genuine ASDF package inference (§37). Other file-loading forms remain
unsupported until there is a tested loader design.

## 10. Formatting, comments, and reproducibility

Implement a dedicated OCaml S-expression printer, with two-space block
indentation, a target width of 90 columns, aligned bindings, and stable clause
formatting. Avoid the deep staircase caused by printing every Lisp list using
one generic rule. Width is a target, not a promise to split symbol/string
literals or damage source structure.

Retain upstream licensing and attribution. Retain source comments where they
can be attached to declaration positions without moving code. At minimum,
retain file headers and source references; document any comment-retention
limit. Generated banners must identify the translator version and source
content digest, not nondeterministic build timestamps or absolute paths.

Pin the upstream commit and source file digests. Record the actual tested
OCaml, Camlp5, SBCL, and Trivia versions/commits. Re-running generation with
the same profile must produce identical Lisp and source-map bytes. A release
contains source inputs sufficient to reproduce the measured initial targets.

## 11. CLI and failure policy

Implemented interface (the shorter two-file invocation remains available):

```sh
make build
ocamlrun bin/hol2cl scan vendor/hol-light/lib.ml vendor/hol-light/fusion.ml
ocamlrun bin/hol2cl translate --output-dir example \
  vendor/hol-light/lib.ml vendor/hol-light/fusion.ml
make regenerate
make test
make inventory
make release
```

`scan` distinguishes parsing from translation support, lists source constructs,
dependencies and diagnostics, and provides machine-readable results.
`translate` rejects unsupported nodes and unresolved names. It writes no
partially valid file as a successful result; output is staged until the entire
requested translation succeeds. No placeholder functions, swallowed parser
errors, or unexplained source substitutions are permitted.

## 12. Verification

Meaningful tests must cover semantic fault lines, not just repeat the printer:

1. Parse and lower all 46 pinned static core inputs using `pa_j` in their
   declared order, including the source system.ml host-configuration adapter.
2. Compile/load generated code with SBCL and actual upstream Trivia.
3. Verify curried and higher-order calls, tuple arguments, parallel binding,
   lexical capture/shadowing, case collisions, guarded/as/or patterns,
   incomplete matches, and exception propagation.
4. Exercise kernel type/term constructors, substitution, alpha-equivalence,
   primitive rules, and invalid-rule rejection.
5. Compare serialized observations from original OCaml and generated Lisp for
   a bounded, explicitly listed differential corpus.
6. Audit source-map ranges and reject unsupported-source fixtures.
7. Generate twice and compare all output bytes; ensure generated files are
   current before producing the release.
8. Exercise named/inline records, mutable arrays, Map add/find/union including
   removal on collision, net lookup/merge, type inference, term quotations and
   formatter output against original OCaml.
9. Regress static functor capture/instances, aliases, local module closures,
   rebound prefix operators, required labels, actual source loops, lazy values
   and failures, Map/Set, seeded Random and the finite-width shift boundary.
10. Compare actual METIS/connection-prover results, bounded failures, quotient
    construction/lifting and implicational tactics, restoring search settings.

Differential tests are evidence about the corpus, not an equivalence proof.
Tests must make failures fatal. Do not count a parsed file as translated or a
translated file as kernel-verified merely because it can be read.

## 13. Milestones and measured implementation status

| Milestone | Target | Measured status |
| --- | --- | --- |
| M0 | Real front end and inventory | All 46 core inputs parsed and lowered |
| M1 | lib.ml and runtime | Generated, SBCL-compiled/loaded and differential-tested |
| M2 | fusion.ml and module/private boundary | Generated, SBCL-compiled/loaded and differential-tested |
| M3 | basics/nets/printer/preterm/parser | Complete files compiled/loaded and used by the corpus |
| M4 | equal/bool/drule | Logical initialization, proof operations and definitions compared |
| M5 | tactics/itab/simp | Tactics, intuitionistic search, goals and simplification compared |
| M6 | theorems/ind_defs/class/trivia/canon/meson | Inductive/classical proofs, normalization and MESON compared |
| M7 | firstorder/metis/thecops/quot/impconv | Complete files initialized; first-order provers, quotient/lifting and implicational tactics compared |
| M8 | pair/compute/nums/recursion | Complete files initialized; product operations, CBV, numerals and recursive definitions compared |
| M9 | arith.ml | Complete file initialized; arithmetic proofs and source conversions compared |
| M10 | wf/calculators/normalizers/inductive types/lists | Complete files initialized; representative proofs, numeric/polynomial conversions and datatype principles compared |
| M11 | real/integer arithmetic, sets/iterate/cart/define | Complete files initialized; arithmetic, set identities, finite iteration, Cartesian projections and recursive definitions compared |
| M12 | system.ml and complete release | Host adapters, all 46 inputs, fresh initialization, clean-build regeneration and complete release verified |

Upstream commit: `233b83c3202370e03c54de2bd090e4d34f677e91`.
Tested: OCaml 4.14.1, Camlp5 8.02.01, SBCL 2.2.9, on the 64-bit build profile.
Actual upstream Trivia and its source dependencies are vendored and pinned.
No original HOL Light or OCaml Map/Set source was patched to obtain these results.
The previous 0.5 checkpoint had 19 initialized files, 42 independent checks,
858 output lines and 36,457 core maps. Those test families remain in the
expanded original initialization environment.

`make release` succeeded with the following complete 1.0 profile:

- 46/46 static core inputs parsed, lowered, generated, SBCL-compiled/loaded
  and initialized in the exact vendor/CORE_FILES.json order. The original
  OCaml oracle initializes the same unchanged complete files.
- 194,839 core source-map entries audited; 205,341 with eleven source fixtures.
- 122 independent SBCL checks and 1,124 matching output lines: 1,117 serialized
  observations, three explicit printer/flush lines, two actual benign
  recursive-definition/specification warnings and two Groebner progress lines.
  Forty observations normalize bound names; two initial registry rows normalize
  generated schematic type names; the initial-definition row also normalizes
  generated binders in two schemes. These observer-only rules overlap and are
  reported separately, preserving types, sharing, free names and structure.
- Initial source registries: 22 types, 303 constants, 263 definitions and the
  exact original three axioms. The primitive-kernel fixture separately adds
  one explicit test-only axiom after those initial snapshots.
- Initialization output: 5,519 OCaml rows / 5,517 SBCL rows. CPU durations in two
  timing rows are normalized only for message comparison; the two additional
  OCaml diagnostic occurrences in iterate.ml are retained and disclosed.
  Initialization message equality and raw byte equality are both false.
- Ten rejection checks, unchanged existing output on rejection and identical
  deterministic regeneration. All pinned source digests remained unchanged.
- A separate clean directory builds the translator from source and regenerates
  all 94 core Lisp/map/inventory/ASDF files with identical bytes. An actual
  SIGINT-to-Sys.Break adapter check succeeds in an isolated SBCL process.

The 0.6/0.7/0.8 subsections below retain checkpoint-specific history; section 22
records the completion design and measured host/observer boundaries.

Earlier corpora remain regression evidence in the larger initialized logical
environment: scopes/currying, case collisions, kernel substitution/rules,
arithmetic, records/arrays/Map/nets, parsing/printing, logical/quantifier
inference, matching/unification, definitions, tactics, goal states, ITAUT and
simplification. The foundation fixture still compares 23 initialized theorems,
five classical TAUT proofs, choice/eta operations, twenty normalization
conversions, inductive existence/definition/rules/induction/cases/strong induction,
a schematic path relation and two mutually inductive predicates. Actual
conclusions and hypotheses are checked; no assumed proof replaces a result.

MESON cases retain their explicit focused positive bound 12, source-rule
positive default bound 50 on two small cases, and four negative searches with
bound 2. Depth/refinement/Brand/no-split profiles and restored source settings
are checked. Scope regressions retain CL/control-syntax name collisions and
capture of an earlier enclosing binding from a child module.

### Additional 0.6 corpus

language.ml adds 23 serialized observations for definition-time functor capture,
separate instances and shared aliases, boolean tokens versus True/False tags,
required labels, leading-let recursive closure initialization, escaped local
module closures, local types inside a global nested module, import/local collisions, rebound recursive prefix `!`, source
for/while loops, lazy values/failures, structural hash keys, assertions, vertical
Format boxes, Map/Set operations, standard List callbacks, seeded Random and
six logical right-shift cases. Native checks independently require the expected
captures/state separation, values, exceptions, coordinates and shift sign bit.

provers.ml adds 54 serialized observations:

- Thirteen first-order mapping/reconstruction, substitution/backtracking,
  occurs-check, finite lazy-stream and METIS Option/Formula cases.
- Six positive proofs each from METIS, leanCoP and nanoCoP: conjunction exchange,
  excluded middle, chained implications, quantified existence, and predicate
  propagation through a function. METIS/leanCoP additionally test function
  congruence; nanoCoP's sixth bounded-corpus example is equality symmetry.
  Every result must have no hypotheses and the requested conclusion.
- Three tactic proofs with an actual source assumption, and three wrapper
  rejections of additional hypotheses. Empty METIS saturation and leanCoP's
  empty database with `deepen_to 2` supply finite negative cases. No unrestricted
  connection search is used on an unprovable negative formula.
- Eight quotient cases: equality relation, actual quotient type definition,
  abstraction/representation theorems, lifted boolean negation and lifted
  double-negation theorem. All results are closed, the lifted conclusion must
  be `!x:test_quot. test_qnot (test_qnot x) = x`, and the operator's abstract type
  and quotient arity are compared.
- Seven implicational cases: actual test definitions, IMP_REWRITE_TAC,
  SEQ_IMP_REWRITE_TAC, assumption-bearing forward/target rewriting,
  HINT_EXISTS_TAC and rejection of an unchanged goal. Target rewriting is given
  both its step lemmas and a reachable target theorem. An empty step list does
  not supply a rewrite path. Constant-headed predicates are used where the
  original tactic indexes constants.

Default nanoCoP on the function-congruence goal exceeded the retained process
limit in original OCaml as well as SBCL during corpus development. That case is
excluded from the quick nanoCoP corpus; its algorithm/settings are unchanged,
and the 120-second guard is retained. This release is not a performance or
termination claim for arbitrary first-order inputs. Prover verbosity is restored
on success and failure. Independent SBCL checks require closed quantified
results from all three provers, rejected extra hypotheses, quotient types and
retained surrounding settings.

### Additional 0.7 corpus

execution.ml adds 68 serialized observations and two actual warning lines:

- Six reference-record, alias/copy/mutation, hash shadow/removal/fold, array-fold
  order, partial-record and overloaded-constructor observations. Hash inventory
  entries alone are sorted as an order-independent observation; their source
  callbacks and evaluator operations retain their original order.
- Fourteen product observations: syntax/type/decomposition/roundtrip, an actual
  paired definition, projection, generalized beta and paired let conversion,
  and eight initialized product/curry theorems. Conversion results must be
  closed, have the original input side and the independently expected result.
- Nineteen CBV observations: boolean/implication/conditional/nested/beta/lambda/
  let evaluation, weak and restricted evaluation, explicit LET_END rule
  extension, custom definition/addition/deletion/restoration, compset inventory,
  rejected invalid lambda rules, EVAL_RULE preserving its assumption, EVAL_TAC
  and restored monitoring/stoppers. Original bool_compset leaves LET_END F for
  the let example; adding LET_END_DEF produces F. Restricted evaluation stops
  rewriting the selected head but still evaluates its arguments.
- Twenty natural-number observations: eight numerals including values on both
  sides of 2^24 and 123456789012345678901234567890, eight initialized natural/
  infinity/bit theorems, an actual induction proof, rejected negative/invalid
  numerals and ind/num arities. Construction, destruction, full term structure
  and printed numeral text are compared using the unchanged source algorithms.
- Nine recursive/specification observations: actual recursive-function existence,
  identity definition and induction proof, benign redefinition, a function
  with an extra boolean parameter and its induction proof, specification of zero,
  benign respecification and rejected duplicate names/assumption-bearing input.
  Every successful result has no unproved hypotheses. Original benign warnings
  are compared as actual output lines, not suppressed or serialized as theorems.

Independent SBCL checks additionally require expected constructor-family and
partial-record results, ref/hash/array behavior, closed CBV/generalized-beta
conversions, a beyond-machine-width numeral roundtrip, negative numeral failure,
recursive/specification constant types and restored evaluator flags. The two
new compiler rejection cases protect ambiguous unqualified contents patterns
and hidden constructor lineage after a signature. These changes do not include
arith.ml's equations or claim general arithmetic conversion support.

### Additional 0.8 corpus

arithmetic.ml adds 44 serialized observations, all retaining literal names:

- Seven mixed recursive-group cases: global and standalone independent values,
  a static module, mutual local closures, mixed lexical-module values/functions,
  inner same-spelling shadowing, an escaped closure capturing a local module's
  outer value, and nested recursive initialization. Tuple results independently
  require one initializer invocation, actual captures and correct call dispatch.
- Eighteen closed original arithmetic theorems, including add/multiply/exponent,
  order and well-ordering, cutoff subtraction, parity, division specification,
  zero-divisor behavior, nested modulus and the minimal-number binder.
- Six closed proofs of explicitly requested goals: original-source induction,
  cutoff subtraction, division/modulus by zero, distributivity, antisymmetry and
  the minimum of the singleton predicate. No proof is replaced by an assumption.
- Thirteen conversion/boundary cases: MOD_DOWN_CONV on addition, successor,
  multiplication and exponentiation; NUM_CANCEL_CONV on common and repeated
  summands and zero remainder; BITS_ELIM_CONV on symbolic BIT0/BIT1/NUMERAL,
  unchanged well-formed numerals, unchanged modulus and rejection of a non-equation.
  Successful conversions must be closed equations from the original input to
  an independently specified result.

Fifteen additional independent SBCL checks require actual initialization counts,
mixed-group values/capture/once-only execution, closed conversion results,
invalid cancellation rejection, DIV's natural-number type and an induction proof.
Three additional compiler rejections protect a same-spelling recursive dependency,
cyclic data and a dependency hidden inside a local module. All preserve existing
output. The runtime and original arithmetic inputs need no changes for this
checkpoint. General numerical conversion from calc_num.ml remains outside it.

### Observation and initialization boundary

Forty selected conversion/inductive/quotient/recursive-property observations
serialize bound variables by de Bruijn indices. This includes the previous 38
checkpoint cases and the new standard_tree_induction/standard_tree_recursion
principles. Free names, types, term structure and complete hypotheses/conclusions
remain observable. Two initial registry rows additionally canonicalize only
preterm-generated ?decimal type-variable names per scheme by first structural
occurrence. The initial-definition row canonicalizes GEN%PVAR%decimal bound
names in PCROSS and iterate only. Authored type/bound names and all free names
remain unchanged. No parser, stored theorem or generated program is normalized.
The complete defined observation streams match byte for byte.

Initial snapshots precede test-only extensions. Both executions register 22
types, 303 constants, 263 definitions and exactly INFINITY_AX/SELECT_AX/ETA_AX.
The complete source stack contributes all of its original proofs and definitions.
The initial rewrite/conversion/congruence lists have 34/5/8 entries; monotonicity
has nine entries and there are three registered inductive definitions. Native
checks validate all registered induction triples and preserve the initial source
axioms as the unchanged tail after the one explicitly declared primitive-kernel
fixture axiom. Closure addresses are not meaningful observations.

The original oracle compiles all forty-six unchanged files and the same eleven
fixtures with the original Num prelude. A no-op needs shim reflects the fixed,
already-inlined order; let float_sqrt = sqrt reproduces the alias made by pinned
hol_lib.ml before that prelude. Observation functions are explicitly sequenced
to give registry extensions the same starting state. Generated argument
evaluation remains ordinary left-to-right CL evaluation. Compiler/rejection and
isolated adapter commands retain a 120-second guard; the complete native/oracle
processes use a measured 600-second guard and SBCL starts with a 256 MiB control
stack. Failing proof searches retain their independent small bounds.

Reports include separate raw initialization streams, both observation streams,
counts, digests, all-core inventory, clean-build evidence and per-file timings.
Initialization differs in duration/order and exactly two diagnostic occurrences
from iterate.ml: one inventing-type-variables warning and one solved-at-2 line
appear only in OCaml. Message equality is explicitly false. The harness rejects
any other normalized message difference; it does not fabricate or suppress
messages to claim exact equality. Logical observations and source registries
must match under the separately enumerated observer rules. This is bounded
corpus evidence, not a correctness or kernel-soundness proof.

All 46 manifest inputs participate in the released execution corpus. No
manifest file remains at a parsed-only or uninitialized checkpoint. system.ml
uses the documented logical GC-control record and actual interrupt adapter;
the original load manifest supplies ASDF order. Source stack_limit is logical
configuration, while the native control stack is allocated at SBCL startup.

Comments inside expressions, exhaustive erased-node maps, general type-directed
record selection, full module/type semantics, arbitrary binary I/O, float/NaN
corner cases, cyclic/recursive non-function values and general machine-int
overflow remain outside the profile. See section 19 for finite-width shifts,
seeded Random and source-derived libraries, and section 22 for exact-rational
Num exception boundaries. Optional HOL Light libraries outside the standard
manifest are separate inputs. Generated code and runtime remain trusted code.

## 14. Added structural/runtime rules for the 0.2 checkpoint

### Records and inline record variants

Record declarations become `defrecord`, retaining field declaration order and
mutability flags. A full literal uses its record constructor with
named keywords; a copy/update uses `record-update`; field observation uses
`record-field`. Mutable field assignment is checked by the runtime. Literal
labels must identify one declared record type, otherwise report ambiguity.
This avoids guessing types after erasing annotations. Annotation erasure does
not disambiguate overloaded record labels. Record export resolution through
module signatures is not part of the supported profile. The actual nets.ml
uses a top-level record declaration. Inline record variants are supported as
constructor-specific named fields; Map's original Node declaration exercises
this representation. A record copy has a fresh field vector and preserves
unchanged field values; assignment checks the declared mutable flag.

### Initial 0.2 source-derived Map.Make specialization

The initial 0.2 implementation supported the specific standard-library application
`Map.Make(KeyModule)` as a documented library boundary.
Emit a child package with `empty`, `find`, `add`, and `union`, translated from
the OCaml 4.14.1 persistent balanced-tree algorithms. Keep nets.ml itself unchanged;
do not replace its maps with association lists or a mutable hash table. Retain
the original standard-library map source and notices, and test all exposed
operations against actual OCaml Map.Make. Section 19 expands the public API
and implements static source functors for the 0.6 checkpoint.

The compiler locates the original Make functor, retains its type declarations
and whole function declarations needed by the four public operations, then
instantiates those AST nodes with the already-resolved key module. Helpers
include height, create, singleton, bal, min_binding, remove_min_binding,
add_min_binding, add_max_binding, join, concat, concat_or_join and split. No
function body is rewritten. Empty, Node and those helpers remain internal.
The CLI requires the pinned template under vendor/ocaml-stdlib relative to the
project's bytecode executable. Source maps in nets.map.json distinguish
nets.ml origins from `ocaml-stdlib/map.ml` origins. The latter ranges point to
the included original source, not a fabricated nets.ml location.

### Arrays, strings and standard-library primitives

One-dimensional arrays use Lisp vectors and Trivia vector patterns; Array.make,
get/set and indexed source access retain source operations. Bounds/negative
array sizes are runtime errors. String observation and character operations
cover the APIs used by the original lexer and printer. This is not a general
compatibility layer for every OCaml library function, mutable-string profile,
multi-dimensional arrays or structural comparisons of arrays.

The declared environment also includes required Num aliases, String.compare,
List.fold_left/List.exists and first-class boolean operators. Saturated boolean
operators preserve short circuit behavior; passing an operator as a value uses
the curried function boundary after argument evaluation.

### Buffer and Format boundary

Buffer contents are returned as a fresh string; resetting the buffer must not
erase an already-returned printer result. A formatter accumulates text, breaks
and nested boxes. Flushing renders to a buffer or stream and resets its document.
H boxes remain horizontal; HV boxes choose an all-horizontal or all-vertical
layout by available width; HOV boxes use the next segment when choosing a break.
Indentation, margins, max-box suppression and pp_print_as display widths are
represented explicitly. The default margin is 78.

This implementation covers the bounded API used by printer.ml, including its
buffer-backed string_of_type/term/thm functions. It does not implement OCaml
Format's complete queue algorithm, every printf directive or every box
layout edge case. The bounded 0.3 callback interface is described in section 16.
The corpus checks two HV margins and actual type, lambda and
reflexivity printing; it does not establish layout equivalence for all inputs.
Format.printf is supported in the declared callback profile. A narrow scalar
Printf profile and goal-printing operations are added in section 17. The full
Format/Printf languages and exact general layout equivalence remain future work.

## 15. Primary sources

- HOL Light: https://github.com/jrh13/hol-light (pinned inputs carry its license).
- Camlp5 MLast/Pcaml: https://camlp5.github.io/doc/html/pcaml.html and the
  installed version's `mLast.mli` / `pcaml.mli` are authoritative for APIs.
- Trivia: https://github.com/guicho271828/trivia (actual dependency, not a
  similarly named local replacement).
- OCaml 4.14.1 Map: the pinned `vendor/ocaml-stdlib/map.ml`, with complete
  LGPL-2.1 and OCaml linking-exception notices beside it.

## 16. Plan saved before the 0.3 implementation

Implemented and verified in 0.3.0. The plan below records the agreed scope and
structural rules; measured results are in section 13.

Scope: add the complete, unmodified pinned equal.ml, bool.ml and drule.ml to
the seven-file load order. Do not start tactics.ml or later theory work in this
release. Preserve every existing structural rule and the original recursive
proof algorithms. Expand the runtime only at observed source boundaries.

### Format callback boundary

The first observed blocker is `Format.printf "%a\n" pp_print_qterm t` at the
end of equal.ml. Implement a bounded Format interface for printf/fprintf and
buffer-backed asprintf, retaining the original format string. `%a` invokes an
escaping translated printer with the formatter and value as two curried
arguments; `%t` invokes a formatter-taking callback. Plain text, newlines,
`%%`, `%s`, `%d`, `%b` and `%!` cover the small declared profile. Other format
directives fail explicitly; no claim of complete Format or Printf compatibility.

The format string determines the arity of the resulting ordinary function.
Register that continuation using the existing function-value dispatcher so
partial and excess application obey the same rule as other escaping functions.
Do not insert evaluation-order temporaries, rewrite the source printer call,
or equate OCaml `%a` with a CL FORMAT directive. printf/fprintf append to the
existing formatter and flush only when requested; asprintf flushes its own
buffer before returning a fresh string. Test saturated, partially applied and
zero-field formats, multiple callback arguments, escaped percent and newline.

### Initialization and proof validation

Generate and SBCL-compile/load all ten files in a fresh process. bool.ml must
perform its own syntax registration and construction of logical definitions
and derived theorems; remove the seven-file fixture's manual notation setup.
Compare the same original source load order in OCaml, followed by the same test
fixtures. Do not use serialization code as a substitute for deriving theorems.

Additional binding fault line found by the 0.3 corpus: DISJ_CASES has an outer
source `R` and inner `r`; the CL reader folds them to the same symbol. Before
emitting any lexical binder, check its target logical symbol against every
visible binding, including source names differing only in case. Use the
existing deterministic local version suffix when they collide. This protects
captured outer variables and local function references without a global reader
change or algorithm transformation. Allocate names within a parallel local
function group using a growing reservation environment, while its source RHSs
still see only the preceding environment unless recursive. Regress value,
sequential-function and parallel-function cases.

Add differential cases for BETA_CONV and conversion composition, SYM and
substitution, CONJ/MP/DISCH, SPEC/GEN/EXISTS/CHOOSE, invalid side conditions,
type/term matching and unification, PART_MATCH/MATCH_MP and new_definition.
Compare serialized hypotheses and conclusions, new definitions, and initialized
logical constants/definition theorems. Include initial registry observations
before test-only kernel extensions. Preserve the earlier 585 observations as
regression evidence while allowing the actual logical environment to grow.

Release only after full-file initialization, meaningful differential cases,
negative-input/output protection, valid maps and identical regeneration pass.
Refresh the 46-file inventory; later lowering status is separate from the ten
release inputs. Update DESIGN.md and AGENTS.md from measured results and ship
the complete translator/runtime/tests/pinned input in hol2cl-0.3.0.zip.

## 17. Plan saved before the 0.4 implementation

Implemented and verified in 0.4.0. This section records the scope saved before
implementation; measured results are in section 13.

Add the complete pinned tactics.ml, itab.ml and simp.ml after the ten-file
checkpoint. Do not extend to theorems.ml or later theories in this release.
Preserve all tactic combinators, justification closures, goal-stack operations,
intuitionistic search and rewriting/simplification algorithms from source.

### Runtime and name boundaries

Implement the actual formatter operations needed by goal printing:
pp_get_max_boxes and pp_print_newline, with flush/reset semantics and retained
formatter settings. The default max-box limit is OCaml 4.14.1 max_int for the
tested 64-bit profile (4611686018427387903), verified by the differential getter
observation. Newline flushes the current document, emits a newline and resets
the box state; margins and limits persist. Add a narrow scalar Printf.printf/sprintf interface for
source uses of %d and %s, with ordinary output-channel behavior, not Format
boxes or Format's printer-callback convention. Keep strings unchanged and use
the registered curried-continuation boundary. Reject unsupported directives.
Do not silently treat all Printf functions as aliases of Format functions.
Printf supports only scalar %s/%d/%b, escaped percent and flush in this profile.
Its incompatible %a/%t callbacks are rejected explicitly. Existing formatter
objects retain identity while the test harness redirects their output stream,
so source closures capturing std_formatter remain usable during goal tests.

Audit the grammar's encoded tactical identifiers against the original spelling.
In particular, the public THEN/THENL combinators and the source helper then1_
are separate bindings. Do not merge their Lisp symbols or algorithms. Keep the
existing lexical/case-collision rules and add focused regressions if needed.

### Verification and release boundary

Compile/load all thirteen original-source translations in SBCL and execute the
same original files in OCaml. Compare initialization output where source emits
it, and snapshot registries before test-only extensions. Keep proof-search
diagnostics separate from serialized hypotheses/conclusions in the reports.

Add meaningful cases for prove/TAC_PROOF, THEN/THENL/ORELSE/REPEAT,
DISCH_TAC/GEN_TAC/CONJ_TAC/EXISTS_TAC, valid justification composition, rejected
unfinished goals and invalid tactics, stateful set_goal/refine/rotate/backtrack
and top_thm. Exercise ITAUT on positive propositional/quantifier examples; use
bounded failing tactics for negative cases rather than an unbounded failed
search. Exercise REWRITE_CONV/TAC, SIMP_CONV/TAC, conditional/assumption-based
rewriting, user definitions and rule/conv variants. Compare actual derived
theorems and goal states, not function/closure addresses.

Check goal printing and the new Printf interface against OCaml. Preserve the
0.3 regression corpus, except for the deliberately larger initialized logical
environment. Require fatal checks, valid source maps, no output writes on
translation rejection and identical generation before delivery. Update this
design, AGENTS.md and the 46-file inventory from measured results; package all
source, dependencies, generated files, maps and tests in hol2cl-0.4.0.zip.

## 18. Plan saved before the 0.5 implementation

Saved on 2026-10-13, before changing the translator or runtime for this
checkpoint. Implemented and verified in 0.5.0; measured results are in section 13.

Extend the thirteen-file load order with the complete, unmodified pinned
theorems.ml, ind_defs.ml, class.ml, trivia.ml, canon.ml and meson.ml. This is a
nineteen-file checkpoint; firstorder.ml and later provers/theories are outside
this release. The HOL input trivia.ml is distinct from the actual Lisp Trivia
pattern-matching dependency. Preserve source proof algorithms, recursive search,
continuation closures, theorem reconstruction and declaration order.

### Runtime and initialization boundaries

The first known lowering blocker is Format.print_flush in meson.ml. Add its
one-unit-argument interface to the existing standard formatter, flushing the
document and resetting box state while retaining formatter identity/settings.
Keep it distinct from pp_print_flush's formatter/unit interface. Expand other
runtime or translation boundaries only when an unchanged source input exposes
them; record each additional rule and its evidence here.

Full-file SBCL compilation exposed theorems.ml's local function atom colliding
with inherited CL:ATOM. Track allocated local function symbols per generated
package and include them in its explicit shadow declarations. Preserve their
source names when possible; local functions named like generated Lisp syntax
(lambda, function, progn, flet, labels, quote, etc.) receive the existing local
suffix instead, so protecting a source binder cannot hide generated control
forms. Keep source visibility and recursive groups unchanged. Regress ordinary
CL function-name collisions and a generated-syntax-name collision.

MESON's child module also imports variants and parameters from its enclosing
file package, while the file later imports child functions. Declare all package
shells and their owned exports before adding imports. Intern any earlier
versioned owner symbols referenced by another package, without exporting private
constructors. Emit shells under eval-when only if their packages do not yet exist, so loading
compiled output does not reapply a partial package definition. Then emit the
complete import/export declarations and source forms in their existing order. This resolves package-declaration cycles without
moving OCaml declarations or changing binding resolution. Regress a child
function capturing an enclosing definition that is later shadowed.

Compile and load all nineteen translations in a fresh SBCL process, and execute
the same original OCaml files in the same order. Let class.ml introduce its
original ETA_AX and SELECT_AX, and let trivia.ml introduce its original one
type and definitions. Observe their actual initial registries before test-only
extensions. Original declared axioms are part of this theory boundary; no
test assumption or replacement theorem may be inserted to bypass a failed
proof. Later files install their actual rewrite/congruence rules, so earlier
fixtures must run in and compare the larger initialized environment.

### Differential proof corpus and release conditions

Add cases for derived standard theorems, inductive relation existence and
definition (including rules, induction, cases and strong induction where
applicable), classical excluded middle/choice/extensionality, the one type,
conditional conversions and normal-form conversions. Exercise MESON on
propositional and quantified problems, supplied lemmas, equality and actual
justification reconstruction. Compare serialized hypotheses and conclusions,
registry/state observations and output against original OCaml execution.

Use a small explicit depth limit with GEN_MESON_TAC for failing search cases;
never run unrestricted search on an unprovable negative goal. Restore changed
search parameters and verbosity after focused cases. Add independent SBCL
checks for closed proofs of requested conclusions and rejected invalid inputs.
Retain the existing regression corpus and 120-second process timeout, unless
measured execution establishes and documents a necessary bounded adjustment.

Require full-file compilation/initialization, exact differential observation
output, matching initialization message multisets, valid source-map ranges,
unchanged pinned inputs, unchanged output on translation rejection and
deterministic regeneration. Refresh the separate 46-file parse/lower inventory;
do not count later lowered files as executed. Update DESIGN.md, AGENTS.md and
README.md from measured results, then ship source, runtime, original inputs,
dependencies, generated files, maps and evidence in hol2cl-0.5.0.zip.

## 19. Plan saved before the 0.6 implementation

Saved on 2026-10-13 before changing translator/runtime code for this checkpoint.
Implemented and verified in 0.6.0; section 13 records the measured results.
Add the unchanged pinned firstorder.ml, metis.ml, thecops.ml, quot.ml and
impconv.ml after the nineteen-file load order. This is a twenty-four-file
checkpoint. Pair types, computation, natural numbers and later theories remain
for a subsequent release. Preserve original METIS, leanCoP/nanoCoP, quotient
construction and implicational-rewriting algorithms and their proof
reconstruction. No alternative prover or assumed result may bypass a failure.

### Observed language and library boundaries

firstorder.ml extends the standard List module; metis.ml needs logical right
shift, static functors/aliases, required labelled arguments and further Map/Set
operations. thecops.ml needs assertions, a source while loop, hash tables and
static functor instantiation. impconv.ml packages its closures using local
static modules which capture enclosing lexical values.

Add explicit static module/functor resolution. A functor template retains its
definition-time environment and untouched source AST; an application to a
resolved static module creates a distinct child instance. Resolve module aliases
to existing identities. Keep first-class, dynamic and generative functor/type
semantics outside the untyped profile. Extend source-derived Map/Set templates
only with original declarations required by the observed public API and their
helpers, retaining source maps and original licenses.

Preserve lexical capture for local module declarations. Module values initialized
inside an expression must remain inside its source scope and run at that point;
do not hoist their captured values to top-level globals. Use a documented local
binding representation and resolve module-qualified references to those bindings.
Support required labelled parameters/calls using their names and ordinary
function-value arity; reject optional arguments and ambiguous escaping labelled
calls until explicitly implemented and tested. Reordering supplied labelled
arguments is binding adaptation, not OCaml evaluation-order emulation.

Assertions retain their condition, unit result and OCaml assertion-failure
boundary with source coordinates. Translate only loops actually present in the
source; never turn recursive proof algorithms into loops. Logical right shift
uses the tested OCaml 64-bit host's 63-bit int representation, including negative
operands; document its finite-width boundary rather than claiming general
machine-integer emulation. Add the observed List, Hashtbl, numeric and random
APIs at explicit compatibility boundaries. Random search must have a retained
seed/profile; compare proof results independently of irrelevant internal
search choices, and disclose any nonidentical random/float behavior.

### Verification and release conditions

Further boundaries exposed by the unchanged 0.6 inputs: memoized lazy
expressions (nanoCoP), source function initializers with a leading let before
their recursive closure, module-qualified record labels and inherited record
types sharing a source spelling. Lazy forcing caches both values and OCaml
exceptions. Recursive closure initialization uses slots named by the source
bindings, initialized once before the enclosing body; it does not add anonymous
evaluation-order temporaries. Local variant metadata is declared for compilation,
while captured module values/functions retain their lexical initialization point.
Local type metadata inside a global nested module must be emitted in that
module's own package, before its source forms. Propagate metadata to an enclosing
lexical module only; do not collect unrelated child-package metadata in the root
package. Captured values still initialize at their original source point.

Record metadata is keyed by its owner and emitted binding, and a module exports
its own record information. An explicit record-label module qualifier selects
that namespace; arbitrary type-directed overloaded label resolution remains
unsupported. Required parameter labels are preserved in binding metadata.

Camlp5 represents prefix `!` using its reference-field AST even when the source
operator is locally rebound, as in impconv.ml's recursive conversion operator.
Resolve that syntax through the current `!` binding: the standard binding reads
a ref cell, while a source binding invokes its original function. Do not turn a
source-defined conversion operator into a runtime dereference.

Reserve imported target symbols when allocating locals, and qualify later
foreign references that conflict with allocated locals. Shadow generated
constructor/record/exception makers as well as their source names. Protect the
CL constant PI in lexical lambda lists, and use CL-qualified primitive cons,
vector and short-circuit forms so source names cannot hide their meaning.
Camlp5's True/False names for boolean literals are disambiguated from declared
True/False variants using the original source token. Signature restriction keeps
its actual private-constructor flags; the existing rejection checks remain fatal.

The seeded Random.init/bits/int implementation follows the pinned OCaml 4.14.1
lagged-Fibonacci and raw-byte MD5 algorithms. Its translated runtime section
retains the original LGPL-2.1/linking-exception notice. Additional Format
character/int/cut/vertical-box and standard-channel print_endline operations
cover the newly observed printer calls. Container algorithms remain sourced
from the original Map/Set declarations, not substitute data structures.

| Source-derived template | Selected public API |
| --- | --- |
| Map.Make (15) | empty, find, add, union, is_empty, singleton, cardinal, bindings, mem, filter, merge, remove, fold, map, exists |
| Set.Make (18) | empty, add, fold, mem, union, diff, elements, singleton, is_empty, cardinal, choose, equal, exists, remove, subset, inter, for_all, compare |

Retain complete original helper declarations needed by those operations, not
only the exported functions. Source maps distinguish Map/Set template origins
from HOL file origins, and audits validate against each original source's bytes.
Generated files containing those templates retain an explicit original author,
copyright and LGPL/linking-exception notice in their header. Each instantiation
collects its own new metadata; it must not duplicate preceding root metadata.
The standard List and hash-table adapters are explicit compatibility profiles;
List.sort does not promise identical comparator invocation order, and Hashtbl
does not promise original hash encoding or its full API. General float corner
cases remain outside the profile. Seeded Random init accepts one integer;
the full Random.State/self_init/int64/nativeint/float API is not implemented.

Compile/load/initialize all twenty-four complete translations in fresh SBCL,
and compile/execute the same original OCaml source order. Capture initial
registries and output before test-only extensions. Retain earlier corpora and
add meaningful first-order mapping/unification, METIS and connection-prover
proofs, quotient definition/lifting and public implicational tactic cases.
Compare actual hypotheses/conclusions, persistent/stateful operations and
source rejection. Use explicit bounded search interfaces or finite exhausted
streams for negative prover cases, never unrestricted nonproof search.

Add focused regressions for functor instance separation/definition-time capture,
aliases, local module capture, labels, assertions, source loops, source-derived
containers and library boundaries. Continue to report any bound-name
normalization explicitly; do not normalize free names or term structure away.
Require valid maps, unchanged original digests, unchanged output on translation
rejection and deterministic generation. Keep the existing 120-second process
timeout unless measured evidence justifies a bounded documented change. Update
DESIGN.md, AGENTS.md, README.md and the full inventory from actual results, then
include design, all translator/runtime source, original inputs/dependencies,
generated code/maps and evidence in hol2cl-0.6.0.zip.

## 20. Plan saved before the 0.7 implementation

Saved on 2026-10-13 before changing translator/runtime code for this checkpoint.
Implemented and verified in 0.7.0; section 13 records measured results.
Continue from the verified 0.6.0 release with the complete unchanged pinned
pair.ml, compute.ml, nums.ml and recursion.ml, in their declared load order.
The target is twenty-eight complete inputs. Stop before arith.ml and subsequent
theories. Preserve original pair/type construction, CBV evaluator/database,
natural-number construction, numeral representation and recursive-definition
proof algorithms. Keep real pa_j and Trivia, source scopes and declaration order.

### Observed compatibility boundaries

compute.ml uses the standard ref record notation `{contents = ...}` for patterns
and Hashtbl.remove/fold. Implement ref-content patterns using the existing
ref-cell representation and a real Trivia pattern; match the original stored
value, including tuple patterns and aliases. The standard contents field reads
and writes the ref cell independently of a source-rebound prefix `!`. A literal
allocates a ref cell and record copy/update allocates a fresh cell. Reject
ambiguous unqualified contents literals/patterns when an ordinary declared
record offers the same labels; do not infer its type from a convenient use.

Hashtbl.remove removes the newest matching association and reveals a previous
shadowed association. Hashtbl.fold visits every stored association, including
shadowed keys, with the original curried callback/accumulator interface. Its
iteration order is unspecified: the runtime keeps the existing structural-key
hash boundary rather than claiming exact OCaml hash/bucket layout. Compare
order-independent table inventories in the test serializer, never reorder a
source evaluator or its theorem reconstruction to make a test match. Mutation
during traversal and full Hashtbl API compatibility are outside this profile.

Further syntax/runtime changes must be driven by unchanged inputs, documented
here before implementing their rule, and covered by meaningful source examples.
Do not patch vendored source or replace recursive algorithms with native loops.
Keep source-derived Map/Set licensing and the existing finite-width shift/random
profiles unchanged.

### Initialization and verification

pair.ml introduces its actual product type and lets its original code extend
definitions/rewrites and generalized abstraction support. nums.ml introduces
ind/num, its original INFINITY_AX, inductive representation, induction/recursion
principles and BIT0/BIT1/NUMERAL definitions. These are source extensions, not
assumed test results. Capture the initialized registries before fixtures; compare
all original axioms, types, constants, definitions and stores. Earlier fixtures
must be compared in the larger actual environment, with their meaningful
invariants updated only where source initialization has changed them.

Add product syntax/projections, paired definitions and generalized-let examples;
boolean/beta/conditional CBV conversion, weak/restricted evaluation, compset
extension/deletion and proof reconstruction; natural-number theorems, induction,
large/invalid numeral cases; actual primitive-recursive function existence,
new_recursive_definition, specification/redefinition and invalid-input checks.
Require closed hypotheses and the expected conclusions/converted results.
Retain the previous language, kernel and prover corpora. Additional bound-name
normalization, if needed, must be explicitly scoped and measured; never normalize
free names or whole theorem structure away.

Compile/load/initialize all twenty-eight complete translations in fresh SBCL,
compile/execute the same original OCaml files and fixtures, compare defined
observation streams exactly and initialization message multisets separately.
Retain source-map audits, unchanged pin hashes, rejection output protection,
deterministic regeneration and the 120-second per-process timeout unless measured
source/runtime costs justify a documented bounded adjustment. Update DESIGN.md,
AGENTS.md, README.md and the forty-six-file inventory from measured results.
Package all design, working rules, translator/runtime source, generated code,
maps, pinned inputs/dependencies, tests and reports in hol2cl-0.7.0.zip.

The unchanged compute.ml additionally exposes partial record patterns whose
label (`rws`) occurs in two declared records. Use only shallow source evidence:
the consistent union of root record labels in sibling match/function clauses
that selects one record. Retain that record metadata; do not rewrite the source patterns or add
runtime type guessing. Guards and bodies keep the full environment, and nested
field patterns use their own evidence. Ambiguity without a unique source hint
remains a located diagnostic; this is not general OCaml type inference.

compute.ml also reuses Const/Abs for both kernel terms and its own evaluator
representations. Keep preceding visible constructor bindings in constructor
metadata. For unqualified patterns, intersect the declared variant-family
candidates of sibling cases at each root/tuple component; an unambiguous Var/Comb
case selects the kernel term family for its Const/Abs siblings. Qualified names
remain exact. Without a unique family hint, retain the current binding, except
that a known non-tuple single payload cannot accept a multiple-field pattern
when a preceding visible constructor has the matching declared arity. Unknown
transparent payload aliases retain the existing tuple adaptation. No expression
binding is changed by a sibling pattern hint, and no hidden constructor becomes
visible through signature restriction. Regress overloaded constructors with
both representations and actual CBV conversion. This is bounded syntactic
resolution, not a whole-program type checker.

Add the newly exposed Array.fold_left callback/accumulator boundary with its
original left-to-right element order; retain source evaluator code unchanged.

## 21. Plan saved before the 0.8 implementation

Saved on 2026-10-13 before changing translator/runtime code for this checkpoint.
Implemented and verified in 0.8.0; section 13 now records the completed 1.0 profile.
Continue from 0.7.0 with the complete unchanged pinned arith.ml, after recursion.ml.
The target is twenty-nine initialized inputs; wf.ml and later theories remain
outside this release. Preserve the actual arithmetic definitions, induction,
division/modulus proofs, minimal-number binder and source conversion algorithms.

### Mixed recursive groups and independent initializers

The located blocker at arith.ml:1719 is MOD_DOWN_CONV's local recursive group:
downconv is a syntactic function and upconv is an application of
GEN_REWRITE_CONV to already initialized values. The upconv initializer does not
refer to either binding in that recursive group. Rejecting every non-syntactic
closure initializer is therefore too restrictive.

Keep the existing labels representation when every local RHS is a syntactic
function. For a mixed named group, retain source-named lexical slots, initialize
each once in source order, and let closures capture the whole group. Do not split
the group, reorder declarations, infer arity from an application, or introduce
anonymous evaluation-order temporaries. Leading-let closure initialization keeps
the existing rule. Global declarations retain defun/defparameter according to
their syntactic arity. Mixed lexical module groups use value slots consistently;
their resolved calls must use the ordinary function-value dispatcher.

The mixed global-group regression exposes SBCL's compile-time forward-variable
warning when an earlier function refers to a later defparameter in the same
group. Emit a CL special declaration for the group's global value symbols before
its source forms, with a distinct source-map rule. This is binding scaffolding;
it evaluates no initializer and does not move any source declaration. Never
declare the lexical slots special.

Permit an additional recursive RHS only when its emitted references resolve to
bindings outside the current group. Check resolved binding identities rather
than source spelling: an inner shadowing binder is independent, whereas a new
recursive binder hiding an earlier same-named binding is not. Run this check
while emitting the RHS once, sharing a scoped reference observer through nested
static/local modules and restoring it after success or failure. Nested checks
compose. An independent initializer's reference to the group, including inside
a nested closure/module, remains a located rejection. This is conservative;
cyclic data, arbitrary recursive value dependencies and a general OCaml
let-rec admissibility/type checker remain outside the profile. Recursive pattern
binders other than a simple annotated identifier remain unsupported.

Regress independent scalar/application values, mixed local/global/module groups,
mutually recursive closures, inner shadowing, captured outer values and exactly
once initialization. Protect rejection of same-spelling recursive dependencies,
cyclic data and a dependency hidden inside a local module. Keep prior rejection
output protection and deterministic regeneration.

### Arithmetic initialization and evidence

Compile/load/initialize all twenty-nine complete translations in fresh SBCL and
execute the same original OCaml source order with the same fixtures. Snapshot
actual definitions, constants, axioms, rewrite stores and binder registration
before test-only extensions. Arithmetic must add only its original source
definitions/proved results; no assumed result may bypass a failed proof.

Add closed arithmetic theorem observations and proofs using source induction,
add/multiply/cutoff subtraction, inequalities, division/modulus, well-ordering
and the minimal binder. Exercise MOD_DOWN_CONV on nested modulus expressions
and NUM_CANCEL_CONV on repeated symbolic summands, checking both sides of the
derived equality and rejecting invalid inputs where the source does so. General
numeral evaluation from calc_num.ml is outside this checkpoint. Retain the
earlier corpora in the larger actual initialization environment. Any additional
compatibility boundary must be documented here before its implementation.

Require exact defined observation streams, separately matching initialization
message multisets, unchanged pins, valid maps and deterministic regeneration.
Keep the 120-second per-process guard unless measured costs justify a documented
bounded adjustment. Update the measured status, AGENTS.md, README.md, release
notes and full forty-six-input inventory, then package the design, working rules,
complete translator/runtime, generated code/maps, pinned inputs and evidence in
hol2cl-0.8.0.zip.

## 22. Plan saved before completing the standard core

Saved on 2026-10-13 before changing code for the completion run. The user has
authorized completion of the entire standard core in one continuing task.
Target release: 1.0.0. Translate the complete unchanged forty-six-file pinned
hol_lib.ml load manifest, including system.ml, in its original order. Complete
all forty-five theory files, not only parsing/lowering. Completion requires
fresh SBCL compilation/initialization, original OCaml initialization in the same
order, representative proofs/conversions from every remaining theory family,
matching defined observations and source axiom/definition/type registries.

### Source and runtime contract

Retain real pa_j and Trivia, source declarations/scopes/recursive algorithms,
ordinary CL argument evaluation, immutable pinned input and source-derived
Map/Set/Random algorithms. Do not hand-edit generated code, supply assumed
proofs, replace source search/normalization algorithms, or convert recursion
into loops. Extend syntax resolution only when an unchanged input exposes a
specific boundary; record the rule here before implementing it. Arbitrary
OCaml language/library completeness remains outside the standard-core target.

The observed remaining library boundaries are Array.of_list in calc_num.ml,
Array.map in lists.ml, unary minus_num and unqualified int_of_num from the
original Num prelude. of_list allocates a fresh vector retaining element order
and identities; map allocates a fresh vector and invokes the curried callback
left-to-right once per element. Exact rational Num values continue to use CL
integers/ratios. Add the original aliases without rewriting polynomial, real
or integer proof algorithms. Compare negative/rational/large numeric cases and
fresh-array/callback behavior against the original library.

system.ml's actual source remains translated. Represent its observed Gc.control
stack_limit field as a runtime record with snapshot/copy/update semantics. Gc.get
and set retain the logical configuration, while SBCL stack capacity is established
at process startup; do not claim to reproduce OCaml's collector or resize the
active native stack. Sys.catch_break installs the SBCL SIGINT adapter to the
OCaml-compatible break condition when enabled. Keep source Num printers intact.
Document and test the precise host profile and restored configuration. Loader
order is the immutable manifest/ASDF order rather than executing the OCaml
loader. Verify exactly the three permitted original source axioms after the
complete theory initialization.

### Progression, measurements and tests

Proceed through wf, calc_num/normalizer/grobner, ind_types/lists,
realax/calc_int/realarith/real/calc_rat/int, then sets/iterate/cart/define.
Resolve actual first failures before treating cascaded missing references as
separate defects. Generate deterministic complete inputs and measure compilation
and initialization costs by file. The previous 120-second guard remains for
ordinary focused/rejection/compiler commands. If a complete core process exceeds
it, record measured evidence and choose a bounded core-only limit; keep failing
proof searches independently bounded rather than raising every timeout.

Retain all earlier regression families in the completed source environment.
Add actual well-founded/recursive proofs; numeric arithmetic and rational
conversions; polynomial normalization and Groebner results; a constructed
inductive type and list laws; real/integer arithmetic; set identities, finite
iteration, Cartesian projections and general recursive definition examples.
Every successful proof must have the specified conclusion and appropriate
hypotheses. Conversions compare both sides with independent expected results.
Keep exact names unless a separately documented observer-only bound-name
normalization is required; never normalize free names, types or term structure.

Audit maps and comments, deterministic regeneration, rejection output protection,
unchanged pins, fresh-build reproducibility, ASDF/package boundaries and licenses.
Classify any excluded generic OCaml/runtime behavior explicitly. Update measured
DESIGN.md, AGENTS.md, README.md, release notes and the complete inventory from
actual results, then package design, working rules, all translator/runtime source,
generated code/maps, pinned inputs/dependencies and complete validation evidence
as hol2cl-1.0.0.zip. Do not claim completion until every manifest input has passed
the declared initialization and corpus checks.

### Measured full-core process and timing-output boundary

The unchanged original forty-six-file core initialized in 61.832 wall seconds
and registered 22 types, 303 constants, 263 definitions and exactly three axioms.
The first fresh SBCL attempt compiled/initialized through int.ml, then hit the
existing 120-second guard during sets.ml without an implementation error. Record
per-file compile/load durations and use a 600-second core-process guard for full
initialization/corpus runs. Keep the 120-second compiler/rejection guard and all
explicit small failing-search bounds. Start SBCL with a 256 MiB control stack;
Gc.set retains the source logical stack_limit, not a runtime native-stack resize.

Later core source also calls lib.ml's time wrapper, whose actual CPU durations
vary between processes/implementations. Preserve raw initialization streams.
For initialization message-multiset comparison alone, replace the strictly
recognized numeric duration in successful/failed CPU-time reports with a timing
marker, keeping the report kind, text and occurrence count. Record the number
of normalized timing rows and raw equality separately. Do not normalize other
warnings, proof-search steps or logical observation values.

Original Num probes additionally establish Euclidean division for negative
divisors and rational operands: the remainder is nonnegative and smaller than
the absolute divisor. Use floor for positive divisors and ceiling for negative
divisors; compute the remainder from a - q*b. Num.int_of_num rejects a noninteger
with Failure("integer argument required") and a signed-63-bit overflow with
Failure("int_of_big_int"). Preserve these observed exception boundaries and
test them; the earlier unrestricted CL integer/floor adapters were insufficient
for these newly exercised cases. Nonfinite Num values remain outside the profile.

Full SBCL initialization reached cart.ml after sets/iterate, exposing its source
value named lambda shadowing CL:LAMBDA in the package. Qualify every synthetic
lambda with CL:LAMBDA, including lazy thunks, while preserving actual references
and calls to source bindings named lambda. Retain lambda formatting after that
qualification and regress both value and named-function versions in child
packages. Do not rename the source HOL definition or change the reader.

Development may save a SBCL heap checkpoint after a verified full initialization
to diagnose fixtures without repeating all source proofs. These checkpoints are
scratch-only debugging state. Release verification must start from fresh SBCL and
original OCaml source; never count a restored checkpoint as fresh initialization.

### Full initialization diagnostics and datatype observers

The measured successful full initialization emits 5,519 original OCaml rows and
5,517 SBCL rows. Apart from CPU durations/order, per-file message comparison
locates a two-row occurrence difference in iterate.ml: OCaml has one additional
"Warning: inventing type variables" and one additional "0..0..solved at 2".
Every other normalized message/occurrence matches. Preserve both raw streams and
report this difference explicitly; initialization message equality is false.
The validation accepts only this measured diagnostic delta (or exact equality),
while requiring exact logical observations, source registries and closed proof
results. Do not fabricate messages or add evaluation-order temporaries to erase
the difference. No additional source axiom or replacement proof is introduced.

The two new datatype induction/recursion observations use the existing
observer-only de Bruijn serialization for bound names, preserving free names,
types and full theorem structure. Explicit closed-hypothesis checks apply to
both principles and the newly defined recursive functions. Numeric/rational
iteration and Cartesian projection examples use the original calculation
conversions and explicit index-range lemmas to discharge their genuine side
conditions; no expected result is assumed.

Full observer comparison differs only in initial_constants/initial_definitions
before normalization: preterm.ml's generated schematic type-variable names
(`?` followed by decimal digits) have different fresh counters under the accepted
evaluation profile. For these two registry rows alone, serialize each constant
type/theorem scheme with generated type variables named by first structural
occurrence. Preserve repeated-variable sharing, explicit type-variable names,
concrete type constructors/arities, term free/bound names and full hypotheses/
conclusions. Sequence this observer traversal explicitly in its OCaml fixture;
do not rename types in generated code, parsing, proof algorithms or registries.
Report the two normalized rows separately from bound-name normalization.

The retained primitive-kernel fixture deliberately adds one test-only witness
axiom for new_basic_type_definition after the initial source snapshots. Complete
core initialization still has exactly INFINITY_AX/SELECT_AX/ETA_AX. Final native
checks distinguish that explicit fixture axiom from source axioms and reject
any additional axiom; it is not used to bypass any standard-core proof.

The full-core translator repeatedly checks each foreign target name against
the same immutable list of owned source symbols and maker names. Cache that
exact set of spellings per context, retaining the separate changing local-symbol
set and the existing resolver/reference observer. This compiler-internal lookup
cache changes no source algorithm, name or output form. Require byte-identical
generated core Lisp/maps/inventory before and after the cache and retain all
scope/collision regressions. No input, translated proof or evaluation order is
optimized by this cache.

After schematic type normalization, only two initial definition schemes still
differ: generated GEN%PVAR%decimal binders in PCROSS and iterate. In the registry
observer only, represent these generated bound variables by their structural
binding indices and render their binder with its original (schematic-normalized)
type. Preserve authored bound names, every free name and the complete term
structure. No parser, stored definition or generated program is renamed. Report
the two affected schemes and the one affected registry row explicitly.

### Completion result

The complete fresh-process release run passed on 2026-10-13: all 46 unchanged
manifest inputs, 122 native checks, 1,124 byte-identical observation/output
rows (1,117 serialized), all 194,839 core / 205,341 fixture-inclusive map ranges,
ten protected rejections, unchanged pins and identical deterministic generation.
The added standard fixture contributes 73 serialized observations. A clean
source build reproduced all 94 core outputs; the real isolated SIGINT check
passed. Initial registries and the two measured initialization diagnostic
differences match the documented full-core profile. All standard-manifest
implementation/validation TODOs are complete; generic language/library limits
listed above are explicit exclusions from this target. The release contains
the design, working rules, complete translator/runtime source and full evidence.

## 23. defunc-only experiment: design saved before implementation

User-authorized experiment on 2026-10-13. Preserve the released 1.0 workspace
and use this separate copy. Implement defunc, lambdac and labelsc (and fletc
for nonrecursive source groups) as one curried calling protocol. Each generated
source function accepts &rest arguments and knows its own leading-parameter
arity. Too few arguments return a closure; exact saturation evaluates the body
once; excess arguments apply to the returned protocol function. A three-argument
foo supports (funcall (funcall (foo 1) 2) 3), (funcall (foo 1 2) 3), and
(foo 1 2 3). Lisp operator positions still follow normal CL syntax.

Keep source names, scopes, declaration order, original recursive algorithms,
real Trivia, all upstream digests and existing observers unchanged. Generated
source function references are ordinary CL function objects with no arity-table
lookup. Fixed-arity foreign/constructor functions need an explicit adapter at
the boundary; cache such adapters weakly without retaining dead dynamic
functions. Source lambdas/partial closures implement the protocol directly.

Do not introduce a fixed-arity worker/fast path or specialize source calls by
argument-count cases in this first experiment. Named source calls uniformly use
the defunc entry; function-value calls use normal CL invocation through the
compatibility entry. Native builtins retain their existing boundary lowering.
No tuple/variant representation, type-policy, safety or source algorithm changes.
Runtime macro-private arguments, cursors and result bindings implement calling
conventions; they do not replay or reorder source argument evaluation. Do not
apply dynamic-extent to argument lists captured by partial application.

Verify ordinary/staged/grouped/empty/excess application, arbitrary escaping
anonymous closures, mutual recursion, lexical labels/flet visibility, function
identity and constructor/native boundaries. Retain and run all original fixture,
proof, differential, map/pin/rejection and regeneration checks. Compare fresh
FASL-only startup against the measured 273.191-second baseline and original
61.832-second OCaml bytecode initialization. Keep initial source registries
22/303/263/3, diagnostic comparison and all proof-search bounds unchanged.
Report initialization and GC/allocation timing separately from compilation.
If gains are small, report that result and consider later compile-time case
selection; do not silently combine both experiments. Ship design, updated
working rules, all translator/runtime sources, regenerated files and evidence.

### Experimental implementation and measured result

Source definitions now emit defunc, anonymous/lazy functions emit lambdac,
recursive local/module groups emit labelsc and nonrecursive groups emit fletc.
The macro-private variadic entries know their definition arity locally. Source
function values are plain CL function objects, with no arity lookup/registration
at reference or application. rt:funcall only applies the function. All generated
source named calls use the variadic entry regardless of supplied argument count;
no new fixed-arity worker or call-site saturation specialization is present.

Defunc constructs one self-contained named function object at definition time.
Lambdac uses a private lexical recursive entry. Labelsc preserves mutual lexical
visibility. Fletc constructs closures outside the new function scope and exposes
variadic local names inside it; nonrecursive RHSs retain the prior environment.
Partial closures retain their function/prefix. Macro-private argument/cursor/result
slots implement the protocol, not source argument evaluation-order simulation.
Surplus application checks that the result is a function; applying surplus to a
scalar signals TYPE-ERROR instead of generating spurious compiler type warnings.

Fixed-arity native/constructor function values use adapters with captured arity.
Adapter caching occurs only at that boundary, in per-arity weak-key-and-value
tables; application itself never queries a table. Live adapter identity survives
GC, and the cache does not root dead dynamic foreign functions. No source-function
arity table remains. The foreign adapter cache is not a global source-closure registry.

The separate protocol test passed 27 checks: exact/grouped/staged/empty application,
multiple returned-function stages, escaping lambdas/local functions, mutual
recursion, nonrecursive shadowing, retained function objects and foreign adapter
identity across full GC. The complete corpus also passed all 46 source inputs,
122 native checks, 1,124 matching output rows, unchanged source axioms/initial
registries, ten protected rejections, pins/maps and deterministic regeneration.
The same observer normalization and two initialization diagnostic differences apply.

One fresh FASL-only restart measured 119.039 seconds, with compilation prohibited
and no restored heap. The prior 1.0 FASL measurement was 273.191 seconds: 2.295x
speedup / 56.43% elapsed-time reduction. Summed component CPU time was 118.717
seconds; summed GC time 6.495 seconds; cumulative allocated bytes 123,976,654,272.
The historical sampled baseline allocated about 86.1 GB and spent 38.3 seconds
in GC. These are cumulative allocation figures, not peak resident memory; the
GC/allocation baseline was profiled and is a separate run from the unprofiled
273.191-second timing. No three-run median or fixed-arity fast-path benefit is
claimed. OCaml's measured 61.832-second bytecode initialization remains a reference.

The defunc-only result is a substantial improvement, so this experiment does not
proceed to call-site case specialization. Increased argument-list allocation is
a remaining candidate for a separate future experiment. This copy and ZIP remain
explicitly experimental; the released original 1.0 workspace is untouched.
See reports/history/DEFUNC-EXPERIMENT.md, the JSON evidence and reproducible startup script.

### Peak resident memory measured separately

A sequential fresh-process, FASL-only comparison used Linux wait4.ru_maxrss
for each child separately, avoiding an aggregate maximum across earlier children.
The original 1.0 peak RSS was 245,556 KiB (239.801 MiB); the defunc experiment
peak was 205,384 KiB (200.570 MiB), a 16.36% reduction in this single-run comparison.
Both initialized all 46 files, prohibited compilation, used no restored heap and
verified initial registries 22/303/263/3. RSS covers the process, including code,
heap and resident stack pages; it is not a live-heap measurement. The 256 MiB
control-stack capacity is a reservation, not a claim that all pages are resident.

Cumulative allocation and peak resident memory must be reported independently.
The larger cumulative allocation previously recorded for defunc does not imply
larger peak occupancy; this measured peak is lower. Elapsed times in this run
were 286.730 seconds for 1.0 and 114.337 seconds for defunc. Those are additional
single-run timings, not replacements for a median or for the earlier 119.039-second
experiment result. See reports/history/peak-memory-comparison.json and the raw logs.
Reproduce on Linux with scripts/measure-peak-memory.py --baseline /path/to/1.0
after populating both FASL caches.


## 24. defunc版の次の速度ボトルネック調査


翻訳器・ランタイム・生成コードは変更していない。SBCL 2.2.9、既存FASLのみ、復元ヒープなし、46入力の初期化をCPUサンプリングした。0.01秒間隔、深度128、11,370サンプル。初期状態22型/303定数/263定義/3公理を確認した。

## 結果

| 項目 | 自身のサンプル比率 | 呼出先込み | 解釈 |
|---|---:|---:|---|
| runtime:compare | 6.1% | 13.4% | 汎用構造比較、文字列比較、タグ・フィールド参照 |
| runtime:tuple | 2.2% | 10.4% | &restリスト→coerce vector→構造体 |
| compare-vectors | 1.8% | 9.7% | compareと重複。汎用配列参照・長さ・再帰比較 |
| pthread_sigmask | 11.9% | 11.9% | sets呼出グラフではGC開始経路 |
| make-condition | 0.9% | 4.7% | Failure等の条件構築。ERROR/RAISEと重複 |
| partialの返すクロージャ | 1.3% | 2.7% | appendを含む部分適用処理 |
| runtime:funcall | 1.0% | 1.0% | 以前のアリティ表ロックは上位にない |

包括比率は重複するため加算禁止。関数別サンプルからは、各defuncに分散した&rest形成・length・引数取り出しの総費用は切り出せない。したがって「関数呼出し全体が1%」とは言えない。

プロファイル付き初期化は壁時計125.031秒、CPU124.969秒、GC10.889秒、累積割り当て124,025,193,904バイト。従来の未プロファイル測定119.039秒/GC6.495秒とは採取負荷が異なる。GC時間には開始経路全体が必ず含まれるとは限らず、pthread比率をGC秒数に足しても正しい時間分解にはならない。ピークRSSは今回測定していない。

未プロファイル記録ではsets.mlがCPU35.521秒、iterate.mlが29.206秒で、合計は初期化CPUの54.5%。この2ファイルを改善検証の代表負荷にできる。証明探索やmap等の包括時間は呼出先を含み、ソースアルゴリズムの変更を示唆するものではない。

## GC開始経路の確認

最重量sets.mlのみの別プロファイルは3,312サンプル、壁時計36.729秒/GC3.205秒。pthread_sigmaskは401サンプル（12.1%）。呼出グラフは `interrupt_handle_pending -> maybe_gc -> pthread_sigmask`。例外処理・旧ハッシュ表ロックと誤認してはいけない。GCの開始・割り当て圧が候補だが、サンプラーの影響を含み、ここから改善率は断定できない。SBCLのローカルAPI説明による既定nurseryは53,687,091バイト。閾値を増やす案はピークメモリとの交換になるため未実施。

## タプル生成の因果を確認する小規模実験

現在 `tuple` は `(make-tuple-value (coerce items 'vector))`。setsグラフではtuple→REPLACEのエッジに261サンプル（sets全体の7.9%）があり、リストから汎用ベクタ変換が主要部分。型情報不足のため配列参照・境界検査・汎用REPLACEも残る。

200万個の二要素タプルを作る処理を3回ずつ比較した。現行tuple呼出しと、候補 `(make-tuple-value (vector a b))` は同じ構造体・ベクタ表現を使う。notinlineラッパーとグローバルsinkで結果を保持し、毎回full GC後にCPUとbytes-consedを測定した。

| 構築方法 | CPU中央値 | 累積割り当て/回 |
|---|---:|---:|
| 現行tuple | 0.095996秒 | 159,970,384バイト |
| 直接vector | 0.029002秒 | 95,986,800バイト |

この限定的負荷で3.31倍、割り当て約40%削減。初期化全体の改善率ではない。二要素のみ・非常に短い実験なので大きなタプルや高階利用にも一般化しない。

## 推奨する順番

1. **翻訳時に要素数が分かるタプル式の構築経路**を実験する。直接vectorを構築し、現在のtuple-value表現を維持する。高階関数として渡すtupleは既存関数を残す。ソースの名前・スコープ・再帰・アルゴリズムを変えず、left-to-right評価を保つ。上限の目安は現在tuple包括約10%で、全部を除去できるわけではない。割り当て削減がGCにも波及する可能性は未検証。
2. **compareとフィールド配列の型情報**を調べる。simple-vector等の宣言は表現不変条件を先に確認する。`=` を単にEQUALへ置換するのは数値・例外・可変値などの互換性を壊しうる。専用等値比較は別設計と差分テストが必要。
3. **例外オブジェクトの構築**は二次候補。make-condition約4.7%だが、キャッシュ・軽量化は捕捉範囲、再送出、例外値の同一性を保持する設計が必要。
4. **飽和適用の固定アリティ経路**は引き続き候補。ただし今回のサンプルで効果の総量は測れず、優先順位を上げる根拠はタプルより弱い。本体への採用は行っていない。

## 再現

ツールチェーンのbinをPATHに追加し、プロジェクト直下で実行する。既存FASLが必要。制限600秒、スタック256MiB。

```sh
sbcl --control-stack-size 256 --noinform --non-interactive --load tests/profile-performance.lisp
sbcl --control-stack-size 256 --noinform --non-interactive --load tests/profile-sets.lisp
sbcl --noinform --non-interactive --load tests/probe-tuple.lisp
```

sets診断は当該ファイル終了時にcatch/throwで意図的にロードを打ち切るため、ログ末尾にSBCLのcompilation unit abortedが出る。終了コード0とSETS_PROFILE_COMPLETEを確認する。完全初期化成功の証拠には使わない。完全初期化は別のCPU_PROFILE_COMPLETE/INITIAL_COUNTSログで確認した。

生データはdefunc-cpu-self.txt、defunc-cpu-inclusive.txt、defunc-cpu-startup.txt、defunc-sets-graph.txt、defunc-sets-startup.txt、tuple-probe.txt。機械可読結果はnext-bottlenecks.json。実装変更なしのため既存27プロトコル/122native/1,124比較行の検証は再実行していない。

## 25. Argument-list tuple representation (plan saved before implementation)

User instruction: retain the &rest argument list without conversion to vector.
Keep tuple-value as the distinguishing wrapper, but store a proper list in its
read-only items slot. tuple passes its fresh &rest list directly to the wrapper;
no coerce, copy-list, or vector construction. Do not mutate the stored list.
Use exact-length Trivia list patterns and bounds-checked nth for tuple-ref.
Tuple structural ordering must preserve the existing arity-first comparison,
then compare elements lexicographically; ordinary OCaml-list comparison is
lexicographic and cannot directly replace that rule. Record/variant fields
remain vectors. Hash traversal already accepts sequences and must still agree
with structural equality. Preserve source algorithms and generated syntax.

Validation: focused proper-list/nested tuple/pattern length/index/comparison/
hash checks, full protocol/native/original corpus, regeneration and clean build.
Then one fresh FASL-only process measuring CPU/GC/allocation and per-child peak
RSS together. Keep the preceding vector experiment and measurements historical;
release the list representation as 1.0.0-defunc-list-tuples with complete sources.
No removal of rt:funcall or call-site specialization belongs to this change.

Implementation refinement: direct Trivia LIST expansion caused SBCL compiler
register-allocation heap exhaustion at the existing 1GiB dynamic-space limit.
Use a wrapper type check, one exact-arity guard, and nth access patterns instead
of nested CONS tests. The representation remains the original argument list.
Do not raise the heap limit to mask this compile expansion issue.

### 25.1 Implementation and measured results

# Argument-list tuple representation: 1.0.0-defunc-list-tuples

ユーザー指示に従い、タプルを生成する際の引数リストをそのまま保持するよう変更した。

```lisp
(defstruct (tuple-value (:constructor make-tuple-value (items)))
  (items nil :type list :read-only t))
(defun tuple (&rest items) (make-tuple-value items))
```

coerce/vector/copy-listを使用しない。外側のtuple-valueは通常のOCamlリストとタプルを区別するために残す。内容のリストは破壊的変更をしない。fst/snd/tuple-refはリストを参照し、tuple-refは負の添字・非整数・範囲外でtype-errorを送出する。パターンは長さが一致した場合のみ要素を取り出す。比較は従来どおり先に要素数、その後に要素ごとの辞書式順序を使う。構造ハッシュの値と等値関係は維持される。レコード・variantの内部ベクタは変更していない。

要素参照はnth、要素数取得はlengthとなるため、大きなタプルで添字参照を繰り返す場合はベクタより不利になりうる。対象コアでは今回の実測で高速化した。内部リストは読み取り専用の契約であり、CLの破壊的変更を機械的に禁止する機構ではない。

TriviaのLISTパターンをそのまま使う初回実装では、ネストしたCONS検査の展開によってSBCLのレジスタ割当中に既存1GiBヒープが不足した。最終実装は実際のTrivia guard1を使い、tuple-value型確認・一度の長さ確認・nth要素抽出を行う。ヒープ容量を増やして回避する変更はしていない。

## 検証

- 16項目の集中テスト：proper-list格納、nested tuples、要素数不一致パターン、タプルと通常リストの区別、要素数を優先する比較、辞書式比較、等値とハッシュの整合、添字の異常系、空タプル。
- 27 defunc protocol checks、122 native checks、元のOCamlとの1,124行の出力一致。
- 全46入力、初期22型/303定数/263定義/3公理。公理集合は元の3公理のみ。
- 再生成一致、10 rejection checks、194,839 core/205,341 total map entries。
- ソースからのクリーンビルドで94生成ファイル一致、pin不変。
- 前回の配布ZIPと現在のsrc/*・generated/*のバイト一致を直接確認した。翻訳器・生成構文・HOLのアルゴリズムは変更していない。

## 新しいプロセスでのFASL限定測定

復元ヒープなし、ソースファイルのコンパイル0件、全46入力、SBCLスタック容量256MiB。Linux wait4の子プロセス個別ru_maxrssを使い、ピークRSSと起動時間を同じプロセスで取得した。各値は1回の測定であり、統計的な性能保証ではない。

| 指標 | 以前のdefunc・ベクタ版 | 引数リスト版 |
|---|---:|---:|
| 起動から終了まで | 119.039秒 | 93.567秒 |
| コアload CPU合計 | 118.717秒 | 93.273秒 |
| コアload GC合計 | 6.495秒 | 5.432秒 |
| コアload累積割り当て | 123,976,654,272 bytes | 113,611,745,136 bytes |
| プロセス全体ピークRSS | 200.570 MiB | 199.230 MiB |

起動の基準値119.039秒との比較は1.272倍、21.40%短縮。累積割り当ては8.36%減少。ベクタ版のピークRSSは別の以前の測定プロセス（その起動114.337秒）で得た値であり、119.039秒の測定と同一プロセスではない。114.337秒に対しても約18.2%短縮だが、いずれも過去の単発測定との比較。ピークRSSの差は約1.34MiBなのでメモリ常駐量が大幅に減ったとは言わない。RSSはlive heapや累積割り当てではない。

今回の変更はリスト格納と照合・参照・比較経路の変更を合わせたものなので、速度差のすべてをcoerce削除のみに帰属させない。rt:funcallは変更していない。

## 再現と成果物

`make test` と `python3 scripts/check-clean-build.py` を実行してFASLキャッシュを更新後、`python3 scripts/measure-tuple-list.py` を実行する。600秒guard、コンパイル発生はエラー。機械可読結果はtuple-list-startup.json、生ログはtuple-list-startup.txt。元のベクタ版記録はreports/history/vector-tuples/に保存した。その他の旧defunc/CPU/peakレポートは歴史的結果であり現在の測定と混同しない。

配布ZIPにはDESIGN.md、AGENTS.md、全翻訳器・ランタイム・生成コード・テスト・測定スクリプトを含む。旧ベクタ版の配布はそのまま残し、今回の配布名はhol2cl-1.0.0-defunc-list-tuples.zipとする。

## 26. OCaml native initialization measurement

Measure the unchanged pinned46-file core with OCaml4.14.1 ocamlopt default
optimization settings. Reuse the oracle's needs stub, float_sqrt alias and
Camlp5 lexer transitions around bignum_num.ml; no source algorithms are changed.
Compile a single concatenated initialization-only unit before timing, link
unix.cmxa/nums.cmxa, then launch three fresh executable processes sequentially.
Capture initialization CPU/wall before the count observer; separately capture
start-to-exit wall/user/system and per-child wait4.ru_maxrss in KiB. Require
22types/303constants/263definitions/3axioms and normalized original initialization
messages. Compare to the historical SBCL list-tuples FASL-only run explicitly as
a cross-run comparison. No translator/runtime/generated-source changes.

### 26.1 Results

# OCamlopt initialization measurement

Same unchanged pinned46-file HOL Light core through define.ml; OCaml4.14.1,
Num1.5 and actual Camlp58.02/pa_j. The initialization-only harness uses the
existing oracle's needs stub, float_sqrt alias and lexer transitions around
bignum_num.ml. Core initialization algorithms are unmodified. No fixtures run
inside the timed initialization. Compilation and linking are completed first.
No translator, production runtime or generated Lisp changes.

The native compiler uses default optimization settings, with no -O2/-O3,
flambda, unsafe operations or custom runtime/GC settings. -w -a only suppresses
warnings. Link unix.cmxa and nums.cmxa. A monolithic compilation initially hit
the compiler's stack limit; a64MiB compiler-only stack permits compilation in
21.490s. Timed executable processes use the inherited ordinary
stack limit and the original system.ml settings. Compilation time is excluded.

| Native run | Initialization wall | Initialization CPU | Start-to-exit | Peak RSS |
|---|---:|---:|---:|---:|
| 1 | 13.715s | 13.711s | 13.727s | 42.723MiB |
| 2 | 13.781s | 13.778s | 13.794s | 42.500MiB |
| 3 | 13.562s | 13.555s | 13.577s | 42.348MiB |
| Median | 13.715s | 13.711s | 13.727s | 42.500MiB |

Three sequential fresh native executable processes; no compilation during runs.
Internal wall/CPU timers start before the core and end after flushing its output,
before observing initial counts. Separate start-to-exit wall time is Python
perf_counter and includes process launch/exit plus observer output. Peak RSS is
per-child Linux wait4.ru_maxrss in KiB; it is neither allocation nor live heap.
Every run reaches22types/303constants/263definitions/3axioms. All initialization
messages match the existing original-OCaml transcript after normalization of
only CPU-duration numbers. Every vendor source digest is verified unchanged.
These are initialization checks, not a new full differential proof corpus run.

## Comparison with the restored SBCL version

| Measurement | OCamlopt median of3 | SBCL previous single run |
|---|---:|---:|
| Start-to-exit | 13.727s | 93.567s |
| Peak RSS | 42.500MiB | 199.230MiB |

The historical SBCL/OCamlopt elapsed-time ratio is 6.816x. Thus the earlier
rough1.5x statement relative to the bytecode oracle does not extend to ocamlopt.
The SBCL measurement is the unchanged defunc-list-tuples variant, FASL-only,
without restored heap and with zero compilation. The SBCL result was not rerun
contemporaneously, so this is a cross-run indication, not an interleaved paired
comparison. There are only3native trials and1historical SBCL trial.

Reproduce with `python3 scripts/measure-ocamlopt.py` after `make build` and with
OCaml/Camlp5/Num available. The script defaults to the toolchain on PATH and
accepts CAMLPLIB. Compiler command, source hash, raw logs and all measurements
are retained in ocamlopt-startup.json, ocamlopt-build.txt and run1/run2/run3.txt.
The source harness and executable are regenerable scratch build products.

## 27. Static call optimization — plan only

# 静的な呼び出し契約とカリー化マクロの最適化計画

状態：**計画のみ。未実装・未測定**。2026-10-14。
実装の基準は復元済み1.0.0-defunc-list-tuples。
今回の計画は以前の「defuncだけを試す」段階を次へ進める設計であり、実装開始の指示ではない。

## 1. 目的と不変条件

defunc / lambdac / labelsc / fletcを、すべてのソース関数の共通定義機構として継続する。
翻訳器は呼び出し契約を証明できる場合に限り明示し、マクロ展開後にSBCLが通常の固定引数呼び出しとして処理できる範囲を増やす。
高速化の対象は呼び出し規約の管理であり、HOLのアルゴリズムではない。

- 元の名前・スコープ・関数本体・再帰関係・宣言順序を保持する。
- ソース本体の複製、関数の融合、翻訳器によるインライン展開、再帰のループ化を行わない。
- ソースにない引数評価順序の再現用一時変数を作らない。
- タプルの引数リスト保持、variant/record表現、compare、型安全性、rt:funcallを今回の変数にしない。
- ソース関数のアリティを実行時ハッシュテーブルで引く仕組みを復活させない。
- 公開の関数値は通常のCL関数。関数値の同一性、再定義前に取得した関数値、逃避するクロージャを保持する。
- 名前を指定するグローバル呼び出しは現在の関数定義を呼ぶ。公開入口を迂回してadviceや差し替えを無効化しない。
- 最適化不能なら現行規約へ戻せる。未知の呼び出しは翻訳エラーにしない。

## 2. 現状から確認できること

runtime/core.lispのcurried-definitionは &rest → LENGTH →不足判定→POPでパラメータ取得→本体→余剰処理、という入口を生成する。
lambdacはprivate LABELS、defuncは自己完結したLABELS関数値をFDEFINITIONに設定し、labelscは互いに見える可変長関数群を作る。
fletcはRHSを外側の環境でlambdacとして作り、内側のFLET入口からAPPLYする。
partialは捕捉した引数リストと次の引数リストをAPPENDし、捕捉した関数値へAPPLYする。
rt:funcallはCL:APPLYする薄い入口である。アダプタキャッシュは固定引数の外部関数が関数値になる境界だけに存在する。

src/compiler.mlにはsplit_function/arity、Function n、名前解決後のcallable、expression_spineがあり、src/scope.mlにはbinding.idがある。
しかしFunction nには「その入口の振る舞いが変わらないか」「固定入口が現在の字句環境から参照できるか」の区別がない。
このため、アリティと渡した引数個数だけでグローバルの内部workerへ切り替えるのは不十分である。

前回のcompare結果への型宣言実験は撤回済み。今回その実装は戻さない。
OCamlopt中央値約13.7秒とSBCL過去の約93.6秒の差を、この呼び出し規約だけで説明できたとはまだ言えない。

## 3. 静的に確定する事実を分離する

| 情報 | 意味 | 最適化への利用 |
|---|---|---|
| binding_id | 解決済みの束縛。文字列名だけではない | シャドーイング・旧定義・モジュール別名を区別 |
| entry_arity | 現在の定義規約で、最初に本体を実行するまでの引数個数 | 完全・部分・余剰の分類 |
| argument_count | その適用ノードで渡す引数個数 | entry_arityと比較 |
| entry_protocol | source-curried / fixed-foreign / unknown | 既存の境界処理を混同しない |
| binding_stability | stable-lexical / captured-object / replaceable-global / unknown | 公開入口を省けるかを判定 |
| worker_visibility | 内部入口が同じ字句環境から参照可能か | 固定入口を呼べるかを判定 |
| parameter_labels | 既存の必須ラベル並び | 解決後の引数列で個数を数える |
| result_contract | 返り値が関数だと証明できるか、その次の入口アリティ | 余剰適用の段階を特定する。初期段階では推測しない |
| evidence | ソース位置・束縛・適用規則・未知となる理由 | 静的判断を監査・集計する |

「アリティ既知」と「呼ぶ関数本体が不変」は異なる。
固定入口の直接呼び出しは、十分な個数の引数だけでなく、束縛が安定し内部入口が見えることを必要とする。
グローバル関数は、その名前・ソース上のアリティが既知でも差し替え可能なので、標準モードでは公開入口へ呼ぶ。
型注釈が関数型でも、実際にどの関数値か不明なら固定入口は選べない。
unitパラメータも引数1個と数え、タプルパラメータもソースで1個なら1個と数える。

## 4. 4マクロに共通する入口設計

### 4.1 最初の候補：OPTIONALとsupplied-pによる入口

&restだけから個数を数える方式に代えて、既知の各パラメータを &optional とsupplied-pで受け、余剰だけ &restで受ける案を最初に評価する。
アリティ3のfooの説明用展開は以下。まだ実装仕様が確定した実行コードではない。

```lisp
(lambda (&optional (a nil a-p) (b nil b-p) (c nil c-p)
         &rest excess)
  ;; c-pが真：必要な3個がそろっている。
  ;; c-pが偽：supplied-pで実際のprefixを決め、部分適用を返す。
  ;; NILを渡した場合と、引数を省略した場合は区別する。
  ;; 本体を一度だけ実行し、excessがあれば返り値へ適用する。
  ...)
```

通常の完全適用では引数リストの走査・POPを不要にし、不足時と余剰時だけ必要なprefix/tailを扱う。
SBCLが完全適用用入口でsupplied-p判定まで除去できるかは、逆アセンブルで判定する。OPTIONALを使えば必ず除去される、とは仮定しない。
公開関数は全個数を受け続け、異なるアリティの関数への再定義も既存の呼び出しを壊さない。
ゼロ引数、引数NIL、アリティ0、非常に大きいアリティ、関数値からのAPPLYにも対応する。
多数の引数でコード量が増える場合は、測定に基づいて旧入口との境界を決める。

### 4.2 次の候補：内部固定入口と汎用入口

4マクロの内部で本体を一度だけ固定パラメータworkerに置き、通常の関数値としての入口はそのworkerに接続する。
worker名はマクロ内部の非公開名とし、ソースの関数名を公開名として保持する。
完全適用が証明できる字句呼び出しだけworkerに直接入る。それ以外は共通のカリー化入口へ入る。
OPTIONAL案と独立に比較する。公開入口を毎回通るだけのworker追加は、効果がなければ採用しない。

| マクロ | 固定入口を使える範囲 | 必ず保つ点 |
|---|---|---|
| defunc | 自分の定義内で、元から捕捉されている自己関数への証明済み呼び出し | 外からのグローバル呼び出しは現在の公開FDEFINITIONを使う |
| lambdac | 同じ字句環境内で対象クロージャとworkerを共に特定できる場合 | 捕捉する環境・クロージャ生成時点・逃避・関数値の同一性 |
| labelsc | グループ内と本体の安定した名前付き呼び出し。相互再帰も対象 | グループ全体の相互可視性、名前のシャドーイング |
| fletc | 新しい関数群を導入した後の本体の呼び出し | 各RHSでは新しい関数名を見せない。外側の同名関数を保持 |

labelscはworker群も相互に見えるようにする。汎用入口とworkerの対応はその展開内で完結させる。
fletcは関数本体の作成を外側の環境で行い、後で名前を導入する。単純にLABELSへ置き換えない。
defuncの自己再帰は現在の実装が捕捉する古い自己関数と一致させる。別のグローバル関数への呼び出しまで固定化しない。
関数を返す本体の実行位置と実行回数を維持し、ソース関数の返り値は現行同様にprimary valueとして扱う。

## 5. 翻訳器とマクロの間の契約

関数本体全体をLispマクロが名前だけで探索・書換えする方式は使わない。
束縛を正しく解決しているOCaml側で、適用ノードに契約を付ける。QUOTE、FUNCTION、特殊形式、同名ローカル関数を文字列のwalkで誤認しない。

段階1では生成される `(foo a b)` を維持し、4マクロの入口だけ変える。
段階2で字句workerを使うために、呼び出しノードの情報をマクロに渡す必要が生じる。
候補構文は次のようにソースの対象名と引数を保持する小さなDSLとする。

```lisp
;; 計画上の構文。callcは現在存在せず、今回は実装しない。
(rt:callc (:exact foo :binding 17) a b c)
(rt:callc (:partial foo :binding 17) a)
(rt:callc (:excess foo :binding 17) a b c d)
```

展開時の環境には、4マクロが用意した非公開の束縛ID→worker対応を字句的に渡す。
対応はマクロ展開時だけ利用し、実行時のハッシュ表・探索・ロック・関数オブジェクトへの属性参照を追加しない。
対象ID・workerの可視性・個数が一致する場合だけ直接展開し、それ以外は公開のfooへフォールバックする。
binding17のfooと、同名でも別IDのfooは別物として処理する。

この構文は候補であり、workerへの直接呼び出しに必要な最小限の情報だけを採用する。
ソース対照の読みやすさを比較し、標準の名前付き呼び出しを保ったまま安全に同等の展開が可能ならそちらを優先する。
グローバルcompiler-macroだけで字句関数も安全に扱えるとは仮定しない。compiler environmentとの遮蔽関係を検証する。
ソースマップでは契約の追加も元の適用ノードに対応させ、workerの詳細を元のソース上の別関数とは数えない。

## 6. 完全・部分・余剰・不明の処理

### 完全適用

```ocaml
let foo a b c = ...
foo x y z
```

安定した字句fooなら固定入口へ。差し替え可能なグローバルfooなら公開入口へ。
本体の計算を展開せず、呼び出し規約の管理だけ省く。

### 部分適用

```ocaml
let p = foo x
p y z
```

不足個数が確定しても、本体を先に実行してはいけない。
部分関数は、その時点のfooの関数オブジェクトとxを捕捉する。後からfooを再定義しても新しいfooへ切り替わらない。
xがNIL相当でも「与えた引数」として保持する。
段階1は既存partialを残す。段階2以降で、既知prefixをクロージャのスロットに捕捉し、完全適用時のAPPEND/APPLYを省けるか独立に評価する。
pが逃避する、別関数に渡る、参照セルに入る場合は残りアリティだけからworker可視性を推測しない。
`((foo x) y) z`相当、まとめて渡す場合、0個追加する場合にも同じ結果と捕捉契約を維持する。

### 余剰適用

```ocaml
let foo a = effect (); fun b -> a + b
foo x y
```

最初の入口アリティは1。返り値が関数だとしても、fooをアリティ2の関数へ融合しない。
fooの本体を一度実行して得た関数にyを適用する。
第一段階の対象が確定していればその段階だけ直接化し、返り値の入口が不明ならカリー化規約へ戻す。
返り値が関数でない場合のTYPE-ERROR、effectの回数、例外の伝播、返されたクロージャの環境を保持する。
異なる「戻り値への適用」と「最初から連続したleading lambdas」を、型の矢印の本数だけで同一視しない。

### 不明な関数値

```ocaml
let apply f x = f x
```

fの型や呼び出し箇所の引数個数だけでは対象関数と残りアリティは決まらない。
rt:funcallと共通カリー化入口を使う。型だけから固定アリティと宣言しない。
高階引数への多版化や呼び出し元別の本体複製は今回は範囲外。

## 7. メタデータの伝播と保守性

- 明示的関数定義：既存split_functionが返す入口アリティを使う。
- 安定した名前付き字句束縛：binding.idと定義のスコープを保持する。
- 不変の別名：取得した関数値の捕捉を保持でき、workerが同じ環境で見える場合だけ情報を引き継ぐ。
- if/matchの合流：各枝が同じ契約である証拠がある場合だけ情報を維持。それ以外はunknown。
- mutation、refからの読出し、未知のコールバック、外部関数からの返り値：初期実装はunknown。
- 必須ラベル：現行解決後の実引数列で分類。optionalや未解決の動的ラベルは既存の拒否契約を維持。
- ローカルモジュール：現行の定義時環境・逐次初期化・再帰値初期化の制約を保持する。
- ファイル間：アリティだけを保持しても、本体不変やworker可視性の証明には使わない。
- 依存契約にABI版とfingerprintを設け、変更された入口契約と古いFASLが混在した場合は再コンパイルを要求する。

将来の封印モードならグローバル直接化は考えられるが、通常の差し替え可能モードの最適化に混ぜない。
毎回のguardや世代番号の照合は、それ自体がコストを持つので初期案には入れない。

## 8. 段階と完了条件

| 段階 | 作業 | 完了条件 |
|---|---|---|
| P0 基準・分類 | 現行の呼び出しを束縛種別/アリティ/適用モード/位置で数える。基準の新規測定 | 不明の理由を含む全適用ノードの分類。新しいSBCLとOCamloptの同時期基準 |
| P1 共通入口 | curried-definitionを4マクロ共通でOPTIONAL候補へ。外部適用規約は保持 | 全規約テストとコーパス通過。完全適用で走査/POPが減る実機証拠 |
| P2 字句固定入口 | labelsc/fletc、自分のdefunc内の自己呼び出し、可視なlambdacへの契約付き呼び出し | 対象固定入口にREST cons/LENGTH/APPEND/APPLY/個数分岐がない。ソース本体一個 |
| P3 部分・余剰 | 確定prefix用の部分関数と余剰の第一段階だけを独立に実験 | 段階的適用・逃避・再定義・例外・副作用回数が一致 |
| P4 統合評価 | 選択した候補のコア全体、起動、コンパイル、RSS、割り当てを比較 | 得られた改善を測定範囲内で報告し、効果のない候補を外す |

P1とP2はそれぞれ単独候補と組合せを評価する。入口変更と呼び出し直接化の効果を分離する。
P3はP1/P2が有効な場合にだけ進める。比較やデータ表現の変更は別計画で扱う。
速度の目標値を保証しない。最初に最適化可能な呼び出しが実時間のどの程度を占めるかを見る。

## 9. 正しさの検証計画

現在の27規約チェック、16タプルチェック、122nativeチェック、1124差分観測、46初期化、pin・map・拒否・再生成一致を維持する。
必要な追加ケースは、既存実装と新候補の相違が生じうる境界に限る。

- 4マクロそれぞれで0個/不足/完全/余剰、NIL実引数、空追加、3段階適用。
- fletcの非再帰RHSが外側同名関数を参照する例と、labelscの相互再帰。
- ローカル同名関数、変数と関数の同名、モジュール別名、旧定義の捕捉。
- fooの再定義前に取得した関数値と部分関数は旧定義、名前付き呼び出しは新定義。
- 同じアリティだけでなく異なるアリティへのグローバル再定義、公開入口へのadvice。
- escaping lambdac/部分関数の捕捉、GC後の生存と回収、同じ関数値のEQ契約。
- 余剰適用で本体が一度だけ実行されること、関数を返さない場合のTYPE-ERROR、途中の例外。
- Native/constructor adapterとの相互運用、既存weak-cacheの保持・回収契約。
- 高階引数とmutationがunknownに落ちること、ラベル対応が現行と同じこと。
- 計画上の固定呼び出し証拠とマクロ内対応が食い違う場合に安全なfallbackまたは明示的ABIエラーになること。

## 10. 逆アセンブルと性能判定

代表例はアリティ1/2/3/大、自己再帰、相互再帰、fletc、捕捉lambdac、部分関数、余剰適用、unknownな高階適用。
呼び出し側と呼ばれる入口の両方を見る。機械語のサイズだけで改善と判定しない。
固定入口候補は直接の字句CALL、必要な環境の受渡し、引数リストの非生成を確認する。
公開グローバルのFDEFN呼び出しは差し替えを保つために残ってよい。そこを間接であるだけで失敗とはしない。
LENGTH、REST list生成、POP/リスト参照、APPEND、APPLY、個数比較、callee探索がどこに残るかを記録する。
内部関数の引数個数が確定しても、その引数がFIXNUM等とは推論しない。根拠なしのFTYPEやsafety0は使わない。
コンパイラが通常行う最適化は観察するが、ソース本体を展開するINLINE指定は初期案に加えない。

マイクロ測定は同じ本体・同じ引数・同じ呼び出し個数・同じ結果検査で、生成時間と実行時間を分ける。
完全適用と部分関数作成、作成済み部分関数の呼び出し、余剰、高階callbackを分けてCPU/割り当てを測る。
コア測定はコンパイルを別工程とし、FASLのみ・復元ヒープなし・初期化完了の境界をそろえる。
候補と基準を交互に複数回、新しいプロセスで測り、CPUジョブを並行させない。
同時期のOCamlopt実行も参考として測る。過去の93.567秒を候補の唯一の基準にしない。
wall/user/system、コアCPU/GC、累積割り当て、子プロセス個別ピークRSS、cold compile時間/容量、コードサイズを区別する。
高速化が測定のばらつき内、コンパイルやRSSの増加が大きい、差し替えや可読性が損なわれる場合は採用しない。
全体の速度差を単一のマイクロ測定から外挿しない。

## 11. 成果物と現時点の状態

DESIGN.md、更新済みAGENTS.md、この計画、翻訳器・ランタイム・生成コード・既存検証結果を一式に含める。
将来の実装時はP0分類表、変更前後のmacroexpand/disassemble、規約テスト、差分結果、独立した速度/メモリ測定を追加する。
今回変更するのは設計・作業規則・配布メタデータだけ。P0の集計からP4まで全て未実施。
現在の性能やサポート範囲が改善したとは記載しない。

### 27.1 Accepted scope supersedes broader proposal

## 採用範囲の確定：共通入口の改善のみ

2026-10-14、ユーザーが前回答の「1のみ採用」を指定。
採用するのは4.1のOPTIONAL/supplied-p方式を、defunc/lambdac/labelsc/fletcの
共通入口へ適用する案のみ。完全適用の引数リスト走査とPOPを減らすことを目標とする。
不足時のpartial、余剰時の返り値への適用、関数値・再定義・スコープの契約を維持する。

4.2の固定引数worker、契約付きcallc、翻訳器での静的呼び出し経路の切替、
部分関数の専用化、グローバル封印モードは採用しない。
以下に残すこれらの記述は検討履歴であり、実装対象ではない。
現行の生成呼び出し形とrt:funcallを保ち、4マクロ共通の入口変更だけを比較する。

実装開始前の計画状態を維持する。今後の作業範囲は、現行基準の確認、
OPTIONAL候補の実装・境界テスト、逆アセンブル、独立した性能比較に限る。
supplied-pによる分岐や余剰RESTがSBCLでどこまで消えるかは未確認。
元の27規約チェックとコア全体検証を通し、完全適用・部分適用・余剰適用の
速度/割り当て、コンパイル時間、ピークRSSを評価してから採否を確定する。


### 27.2 OPTIONAL implementation authorized before code changes

The user now requests implementation. Adopt only the common entry change.
Each parameter receives an OPTIONAL supplied-p flag; only the last flag is
checked on the complete-application branch. Short prefixes are materialized
only in the insufficient branch. A NIL parameter is distinct from omission.
Only surplus arguments use REST. Arity0 keeps a REST-only surplus entry.
Evaluate the original body once, bind its primary result, and apply surplus to
that result with the same functional-value check as before.
Fletc retains its outer closure initializers, but its inner forwarding names
also use the common entry generator and CL:FUNCALL with complete parameters;
no complete-application forwarding REST list/APPLY is needed at that boundary.
Partial closures capture the initializer closure, preserving old flet semantics.
No fixed worker, callc, compiler metadata, call-site routing, source algorithm,
comparison declaration, representation change or unsafe optimization is added.
An independent copy with the old macros supplies contemporaneous FASL-only
baseline runs; compilation is outside all timed runs. Use2GiB capacity for cold
native compilation, default1GiB/256MiB stack for benchmark processes. Capacity
is not peak RSS. Retain all protocol/corpus checks and paired measurements.

### 27.3 OPTIONAL implementation and measured results

# OPTIONAL/supplied-p curried entries: 1.0.0-defunc-optional

Only the shared calling-entry implementation changes. defunc, lambdac, labelsc
and fletc retain ordinary CL function values and the same curried protocol.
No fixed worker, callc, call-site specialization, global arity lookup, compare
annotation, optimization-policy change or data-representation change is added.
The OCaml translator and all94generated files match the restored list-tuples
release byte for byte. rt:funcall, partial and native adapter caching are unchanged.

## Implementation

A three-argument function conceptually receives:

```lisp
(&optional (a nil a-p) (b nil b-p) (c nil c-p) &rest excess)
```

The complete branch checks only c-p, evaluates the original body exactly once,
retains its primary value and applies excess arguments to that returned value.
The insufficient branch selects the supplied prefix and invokes existing partial
with the captured function object. NIL arguments are distinct from omission.
Arity0 uses REST only and executes its body immediately as before.
Fletc closure initializers remain outside the new function-name scope; forwarding
entries use this same generator and CL:FUNCALL with complete parameters. Partial
applications retain the initializer closure, as in the original fletc protocol.
Global named calls still go through the replaceable FDEFINITION; old function
values and old partial closures continue to use their captured definitions.

## Validation

27existing protocol checks +84additional OPTIONAL boundary checks +16tuple
checks +122native checks passed. All46core inputs initialize, with exactly
22types/303constants/263definitions/3axioms and unchanged source axioms.
All1124OCaml/SBCL observation rows match. The existing documented initialization
message difference remains accepted; raw OCaml/SBCL transcripts are not equal.
All94clean-generated files match; source pins, map validation,10rejections and
deterministic regeneration pass. Baseline initializes independently from its
own old-macro FASLs and is not a runtime override of new generated FASLs.

## Disassembly

Displayed function-body sizes for a three-argument addition example:

| Entry | Before | OPTIONAL |
|---|---:|---:|
| defunc | 329 bytes | 211 bytes |
| named caller | 40 bytes | 40 bytes |
| lambdac | 329 bytes | 211 bytes |
| labelsc | 329 bytes | 211 bytes |
| fletc forwarding | 78 bytes | 382 bytes |

LENGTH/list walking and POP parameter extraction are removed from source-function
entries. Supplied-p checks remain in the displayed generic entry; complete calls
are not universally transformed into branch-free fixed calls. Fletc forwarding
code grows. SBCL optional-argument dispatch/XEP code is not fully accounted for
by these displayed body sizes; this table is not total code-image size.
Use optional-before.asm/optional-after.asm and optional-inspect.lisp for evidence.
Actual allocation measurements, not body size alone, determine the benefit.

## Whole-core measurements

Sequential fresh processes in OPTIONAL→baseline→baseline→OPTIONAL order.
FASL-only, no saved heap, zero source compilation,46loaded files, same final counts.
No compiler or other benchmark ran in parallel with these measurements.

| Run | Start-to-exit | Core CPU | Core GC | Peak RSS | Cumulative core allocation |
|---|---:|---:|---:|---:|---:|
| optional 1 | 81.876s | 81.574s | 3.261s | 243.492MiB | 55,728,067,232 bytes |
| baseline 1 | 98.261s | 97.978s | 5.650s | 208.262MiB | 113,611,753,552 bytes |
| baseline 2 | 97.419s | 97.121s | 5.730s | 209.562MiB | 113,611,417,920 bytes |
| optional 2 | 82.039s | 81.748s | 3.250s | 243.969MiB | 55,728,246,304 bytes |

| Median metric | Baseline | OPTIONAL |
|---|---:|---:|
| Start-to-exit | 97.840 s | 81.957 s |
| Core CPU | 97.549 s | 81.661 s |
| Core GC | 5.690 s | 3.255 s |
| Peak RSS | 208.912 MiB | 243.730 MiB |
| Cumulative allocation | 113611585736.000 bytes | 55728156768.000 bytes |

Elapsed-time median shortened **16.23%**; cumulative core allocation
fell **50.95%**. Median peak RSS changed **+16.67%**.
Allocation is not resident memory or peak memory. Peak RSS is per-child Linux
wait4.ru_maxrss in KiB. An observed RSS increase must not be described as a
memory reduction merely because fewer bytes were allocated.
Two trials per variant do not establish statistical significance. Independent
roots/caches may affect layout; the comparison is not a universal speed claim.
The already-recorded OCamlopt native timing remains a historical comparison,
not a new contemporaneous native measurement in this experiment.

## Isolated calling-protocol benchmarks

Three trials per variant in separate processes; same addition bodies and counts.
Function construction/warmup are outside the loop except explicitly named
partial-create-call and excess cases. Result checks require6 in all cases.
The body still uses ordinary generic arithmetic and default SBCL optimization.
Whole process order is baseline then OPTIONAL, so these are diagnostic rather
than fully interleaved statistical benchmarks. Full GC precedes each loop.

| Case | Baseline CPU median | OPTIONAL CPU median | CPU ratio baseline/OPTIONAL | Baseline allocated | OPTIONAL allocated |
|---|---:|---:|---:|---:|---:|
| excess | 0.014351s | 0.006698s | 2.143x | 33,562,112 bytes | 9,568,256 bytes |
| flet-complete | 0.034453s | 0.017738s | 1.942x | 95,993,216 bytes | 0 bytes |
| global-complete | 0.037393s | 0.017251s | 2.168x | 95,975,424 bytes | 0 bytes |
| labels-complete | 0.033409s | 0.015448s | 2.163x | 95,993,216 bytes | 0 bytes |
| lambda-complete | 0.038623s | 0.016630s | 2.322x | 95,975,424 bytes | 0 bytes |
| partial-create-call | 0.022976s | 0.013800s | 1.665x | 47,964,928 bytes | 28,750,336 bytes |
| partial-existing | 0.038326s | 0.028637s | 1.338x | 95,975,424 bytes | 47,987,712 bytes |
| runtime-funcall | 0.029154s | 0.012021s | 2.425x | 47,987,712 bytes | 0 bytes |

## Reproduction and build capacity

Use make test to compile/initialize/check the complete corpus. The full native
compile+corpus validation process and compile-core.sh use2GiB dynamic-space
capacity; the minimum necessary compiler capacity is not established here.
There are no compiler-GC hooks or NOTINLINE workarounds. Timed whole-core
processes use default1GiB capacity and256MiB control stack. These capacities
are not measured RSS. Compilation is outside timing.

For this historical OPTIONAL baseline preparation, first check out commit
`1730c0299f7d677ba25be29d2dfbff0538fea354`; the old commands below apply there.
Prepare a fresh independent baseline with
`python3 scripts/prepare-optional-baseline.py --output /absolute/new-baseline`.
Then run `python3 scripts/measure-optional.py --baseline /absolute/new-baseline`.
The included optional-baseline-core.lisp is the exact runtime used for the
baseline; the rest of production sources/generated files are shared identical
bytes. Baseline/candidate SHA256 hashes and raw logs accompany the report.
The package retains DESIGN.md, AGENTS.md and all translator/runtime sources.


## 28. Holai repository organization

Historical organization-only contract (superseded by the current layout/API contract in section 2): the user requested organization and publication to https://github.com/tani/holai.
The source/runtime/generated-Lisp algorithms and public hol2cl identifiers
remain unchanged. README is rewritten around the current supported profile;
AGENTS retains applicable invariants and removes superseded conversation state.
Historical measurement evidence moves into reports/history/. Current benchmark
scripts and ZIP requirements follow those paths. See docs/REPOSITORY-LAYOUT.md.
Generated Lisp stays versioned for readable source comparison. Source-map JSON
is generated by make regenerate and excluded from Git, but remains mandatory
in complete source release ZIPs. Build output, binary translator, ZIPs and caches
are excluded. Pinned vendor inputs, licenses and exact validation evidence remain.
The ZIP root/name uses holai; executable and ASDF/package names remain hol2cl.

## 29. Star suffix names — design saved before implementation

User adopts readable unescaped symbols and requests implementation/push.
Keep ordinary names unchanged. Convert apostrophes and other reader delimiters
to stars; T/NIL/PI and other unreadable atom stems receive an extra star.
For reserved stems, primed spellings include the reserved-name star as well:
t→t*, t'→t**, preventing record-label collisions. Package/readtable case remains
unchanged. Resolve collisions using the CL reader's uppercase logical name,
appending one star until a free target exists. Top-level owned-name allocation
is planned deterministically with lowercase names before mixed/all-uppercase
names. Local allocation respects visible bindings and reserved owned/imported
symbols; it is deterministic in source binding order where no group is planned.
No name-based string replacement of references: binding records carry the one
chosen printed/logical name through definitions, references, imports and exports.
Maker names derive from the allocated constructor/type name, consistently with
runtime macros. Preserve existing ~n global-version identities and macro-private
fresh variables; use stars instead of ~local suffixes for new local conflicts.
Ordinary unsafe record-slot names use the same deterministic atom encoder in
slot declarations, keywords and field access. Add regression cases for names
with primes, T/NIL/PI, case collisions and multi-star allocation; retain all
existing namespace, closure, module, constructor and rejection checks. Verify
no escaped symbols outside strings/comments remain in generated core code,
full OCaml/SBCL corpus equality, source maps/pins and clean regeneration.
Public Lisp spellings change intentionally; HOL strings and original pinned
OCaml inputs do not change. Recorded performance measurements remain historical.

### 29.1 Validated implementation

# Unescaped star-suffix names: 1.0.0-star-names

Generated source identifiers use ordinary Common Lisp reader atoms. Default
case conversion is unchanged; section33's authorized runtime dispatch extension
does not affect these atoms. This intentionally changes public Lisp spellings;
source OCaml bindings and HOL strings keep their original names.

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

## 30. Standard Common Lisp structural match — implementation specification

Replace the production Trivia dependency with runtime/pattern.lisp. Preserve
Tuple lists, Variant/Record vectors, refs and condition subclasses. Keep the
existing match DSL, replacing trivia:guard with exported guard. Compile patterns
to a validated expansion-only tagged IR and then IF/LET/DESTRUCTURING-BIND.
Evaluate the scrutinee once; type-check before field access. Exact tuple/vector
arity is checked once. Constructor/record indexes are embedded constants.

Declarations register symbol-keyed descriptors in EVAL-WHEN at compile/load/
execute time. Registering a variant family removes its previous descriptors;
versioned symbols and package identities remain independent. Every expansion
records its descriptor signature and checks it when loading the compiled unit,
so changed declarations require dependent FASLs to be rebuilt, rather than
silently using stale field indexes. Dependencies must load declarations first.
Load order: package, pattern registry/compiler, core, format, stdlib.

The IR validates constructor arity, record keys, duplicate pattern bindings and
identical OR binding sets. Guards may refer to outer lexical variables: their
free names are not rejected. Source character patterns use a dedicated literal
DSL node (character code), avoiding repeated synthetic char~value bindings.
Integers/floats use EQL (including the existing representation-sensitive float
behavior), strings STRING= with STRINGP, characters CHAR= with CHARACTERP,
booleans EQ. NaN is not an OCaml source literal; direct Lisp float matching
retains EQL semantics, rather than inventing numeric coercion.

Clause failures use lexical BLOCK/RETURN-FROM. OR joins use a local function
with explicit bound values, sharing the remaining pattern/guard/body once. A
guard after an OR selection fails to the next clause, never to another OR arm;
exceptions propagate. Neither bodies nor guards are duplicated for OR arms.
Simple patterns introduce no continuation function. Pattern metadata and IR
are never looked up or allocated by a running match. No source algorithms,
function entry protocols, argument order or data representations change.

Regression coverage must include the supplied semantic matrix, macro errors,
OR/guard side effects, lexical capture, compile-file/load descriptor visibility
and stale-ABI rejection. Run the whole unchanged 46-file corpus, source-map and
clean-build checks before packaging all sources, DESIGN.md and AGENTS.md.
Historical Trivia benchmark support may retain its pinned dependency in an
isolated historical baseline; the production ASDF system must not require it.

### 30.1 Validation and boundary details

All46 unchanged source files compile/load,122 native checks and1124 differential
observations pass. The94 outputs match clean regeneration; source pins/maps
and ten negative translation cases pass. 46 additional backend checks cover
OR binding joins, guard side effects/exceptions and outer lexical references,
alias identity, records, refs, exceptions, exact tuple/vector sizes, literal
type mismatch, signed zero and SBCL NaN EQL compatibility, duplicate/invalid
patterns,128-wide tuples and60-deep constructors. Compile-file/load works for
declarations and dependent matches. Changing a descriptor after loading does
not affect execution (no registry lookup), but loading the stale FASL rejects.

Character patterns are the one additional DSL spelling change: character-code
with the source byte code, instead of a Trivia guard with a repeated helper
variable. Literal validation does not coerce floats to integers. Guard free
variables remain governed by ordinary Common Lisp lexical scope. Structural
nodes access each field once; this initial compiler does not construct a
cross-clause decision tree or deduplicate repeated explicit AND type tests.
The sample expansion/disassembly is retained in pattern-expansion-and-assembly.txt.
Performance evidence and its measurement scope are in reports/PATTERN-MATCH.md.

### 30.2 Expansion contract

| Surface pattern | Expansion-only IR | Runtime operations |
|---|---|---|
| `_`, variable | wildcard, bind | none; lexical binding at success |
| scalar literal, `(character-code n)` | literal | typed STRING=/CHAR=, EQL or EQ |
| `(cl:type type)` | type | TYPEP |
| `(cl:cons head tail)` | cons | CONSP before CAR/CDR |
| `(tuple ...)` | tuple | TYPEP, one LENGTH, DESTRUCTURING-BIND |
| `(cl:vector ...)` | vector | VECTORP, one LENGTH, fixed AREF |
| `(ref-contents p)` | ref | TYPEP before DEREF |
| constructor/exception | constructor plus descriptor | TYPEP before fixed AREF/readers |
| record keyword subset | constructor plus selected indexes | TYPEP before selected AREF |
| `(cl:and ...)` | and | ordered composition on the same value |
| `(cl:or ...)` | or | left-priority alternatives, fixed-argument FLET join |
| `(guard p expression)` | guard | lexical bindings, one IF after structural success |

`parse-pattern` produces tagged lists at expansion time. `pattern-bindings`
validates duplicate bindings and OR equality recursively. Constructor parsing
also checks arity/keywords, using exact resolved symbols as registry keys.
`compile-pattern` takes IR, an evaluated-value symbol, a static binding alist,
a compile-time success callback and a generated failure form. These callbacks
run only while constructing code. Values extracted from structures live in
fresh lexical temporaries; no field list or environment object is allocated
for matching. Tuple DESTRUCTURING-BIND does not copy its existing item list.

Each clause has a fresh failure BLOCK. Success returns directly from the outer
MATCH block, preserving multiple return values and body forms. An OR's local
FLET join receives its bound values explicitly and closes over only the earlier
structural values required by the remaining pattern. The join contains the
remaining guard/body once. Its failure after selection exits the clause block;
it cannot enter a sibling OR arm. Failed structural alternatives instead enter
the next arm. No HANDLER-CASE surrounds matching: errors in guards and bodies
propagate unchanged. Clause order and source algorithms remain unchanged.

Descriptors contain class, arity, accessor or exception readers, record-kind
flag and ordered keyword keys. The vector index for each selected key is
resolved during parsing. Family refresh removes the previous member names and
re-registers every declaration in source order. ASDF loads pattern helpers
before core declarations; EVAL-WHEN exposes registration at compile/load time.
Dependent expansion embeds a read-only LOAD-TIME-VALUE signature check. It is
not evaluated on each function invocation. Loading a dependent FASL requires
its declaration provider to be loaded first and fails clearly on a changed ABI.
Exact package-symbol keys retain module/version identities. Metadata does not
provide a runtime reflection interface or a global source-name cache.

The compiler trusts tuple instances built by the retained runtime to contain
proper lists, and vector-backed classes to have their declared field counts.
Malformed objects constructed outside this data profile are not repaired.
There is no arbitrary user-defined pattern protocol, dynamic pattern input,
full Common Lisp guard free-variable analysis, clause reordering, generic
pattern library API, or static direct-call worker added by this replacement.

### 30.3 Wildcard access refinement

The first measurement exposed many unused-binding style warnings and unnecessary
reads for wildcard fields. The finalized expansion omits field/ref/head/tail
reads whose entire subpattern is wildcard, and omits tuple destructuring when
only the exact arity is required. Named pattern bindings and tuple temporaries
carry IGNORABLE declarations, without changing types or optimization settings.
This is pattern compilation, not a source algorithm rewrite. Type/arity checks
remain before every used access. The initial measurement is retained as
history/pattern-initial-performance.json; final validation/measurement is rerun.

### 30.4 Final measured status

Final refinement again passes the complete46-file/1124-row corpus and46 pattern
checks. Single serial measurements compare the unchanged Trivia baseline with
the final backend: all compile operations33.857→24.181s; core compile operations
32.685→23.797s; cold compile/load process peakRSS1822.102→1079.875MiB. This peak
includes prerequisite/core initialization, not just compilation. Fresh FASL-only
start-to-exit80.927→82.044s and peakRSS239.762→205.594MiB. Core allocation is
55,727,650,256→55,734,329,328bytes, effectively unchanged. No startup speed gain
is established. Total FASL bytes20,903,888→21,817,272. Final STYLE diagnostics97
vs baseline324, ordinary caught WARNING diagnostics0 for both. Capacity and
per-child peak-metric details, hashes and raw logs are in PATTERN-MATCH.md/JSON.
The earlier86.351s prototype result is historical, not the final implementation.

## 31. Percent suffixes and explicit ignorable bindings — before implementation

User replaces all translator-added star suffixes with percent signs, including
case/scope collisions, source primes and reserved/numeric reader atoms. Source
operator stars, native CL names, literal strings and runtime special variables
remain their original symbols. Examples: x'→x%, t→t%, t'→t%%, ABS collision→ABS%,
*-> collision→*->%. Append another percent until the reader-normalized symbol
is free. Preserve binding identity, record keywords, constructor maker names,
module names and import/reference handling; do not perform generated-text
replacement. Existing ~n versioning and private fresh variables stay unchanged.

All defunc/lambdac/labelsc/fletc parameter binding forms receive IGNORABLE
declarations; MATCH's once-evaluated input temporary also receives IGNORABLE.
Keep the input expression evaluated even if a wildcard makes its value unused.
No compiler warning muffling or SPECIAL declarations are added. Naming removes
the accidental *->* lexical/special-convention warning. Compile everything from
a fresh cache, classify remaining diagnostics, run the original complete corpus
and clean regeneration, then deliver DESIGN/AGENTS/translator in the new ZIP.

Local value/module LET and LET* binding forms also receive IGNORABLE. Retain
the existing single-binding flattening rule when an inner form includes the
new declaration, merging binding lists and rebuilding their declaration.
Source-named unused module slots are not removed, moved or made special.

### 31.1 Final validation

Percent encoding passes21 isolated atom/allocation/native-target checks and9
OCaml/SBCL observations, including9 expected percent-suffix exports and original
operator-star preservation. Full46-file initialization,122 native checks,27
protocol checks,84 OPTIONAL checks,16 tuple checks,46 pattern checks and1124
differential rows pass. All94 clean generated outputs and source pins match.

A separate fresh-cache compile audit completes all51 production units (5runtime
plus46core) with zero errors, caught WARNING, caught STYLE-WARNING and warning
notices. The diagnostic driver captures output before saving it and requires
an explicit completion marker; a partial log is never accepted. Source hashes
are recorded and checked at packaging time. make release runs the fresh audit
after the normal corpus tests. Existing timing reports are historical; no new
performance result is asserted for percent naming or IGNORABLE declarations.

## 32. Remove obsolete vendored Lisp dependencies — before changes

The user requests vendor cleanup. Delete vendor/lisp (Trivia and all four
transitive libraries), since production ASDF matching is standard CL. Remove
its source-registry search entries from current launchers/tests/probes and
remove obsolete dependency revision keys from the active SOURCES lock. Retain
all unchanged HOL Light inputs, parser/oracle support, OCaml Map/Set templates,
Random provenance, associated licenses and their exact hashes.

Historical comparisons use an independent checkout of commit1730c0299f7d677ba25
be29d2dfbff0538fea354, which contains the former dependencies and notices. The
current notices/README/layout must describe only shipped material. Retain
historical measured reports with clear provenance. Source algorithms/runtime
representations are unchanged. Run the full release validation with the vendor
Lisp tree absent, including fresh-cache compilation, before delivering the ZIP.

### 32.1 Completed validation

Removed117 obsolete Lisp-library files (607054 source bytes), leaving59 vendor
files including the new explanatory README. All55 retained original-input
hashes are unchanged. Current test/launcher scripts have no vendor/lisp search
entries. Full46-file loading,1124 differential rows, the existing122 native
checks and all calling/pattern/naming checks pass without those libraries.
Fresh-cache compilation completes51 production units with0 errors,0 warnings
and0 style warnings. All94 clean regenerated outputs match. The cleanup is
continued on the previously requested tani/holai main destination.

## 33. Shared PROOF tactical notation

### 33.1 Public syntax and expansion

`holai.runtime:proof` is an exported macro for both handwritten proofs and
generated tactical compositions. Its grammar is one operand followed by zero
or more operator-reference/operand pairs. Operands are ordinary Lisp forms;
the macro does not walk them. A single operand is returned unchanged, including
NIL. Empty input is rejected.

An operator reference is either a value symbol or exactly `(cl:function name)`
with a symbol name (reader spelling `#'name`). Value symbols expand through
`holai.runtime:funcall`; FUNCTION references expand to named calls, preserving
Common Lisp's separate value and function namespaces, including lexical
bindings. Keywords, CL:T and CL:NIL are not operator names. THEN and THENL
are tactic-combining values; ORELSE is a named function and uses `#'ORELSE`.
Function-valued aliases instead use the value-symbol form. Function operands
likewise need `#'` where the generated declaration is a function, not a value.

All operators have equal precedence and fold left. Explicit inner PROOF forms
preserve right grouping: `(proof A THEN (proof B #'ORELSE C))` is different
from `(proof A THEN B #'ORELSE C)`. THENL takes an ordinary list expression or
list variable; compositions inside literal list elements use their own PROOF.
There is no implicit branch-list syntax or conversion.

Expansion-time diagnostics are:

- Empty input: `PROOF: expected a tactic expression`.
- Incomplete alternating sequence:
  `PROOF: expected alternating operands and operator references`.
- Invalid operator:
  `PROOF: operator must be a value symbol or #'function-name: ~S`.

The compile/load-visible helper folds tokens into the existing binary call
tree. It adds no runtime parser, registry, dispatcher, temporaries or thunks.
Operands retain ordinary left-to-right Lisp evaluation and lexical capture.
Unbound/nonfunction values and tactic exceptions remain errors at their
existing boundaries. PROOF does not parse goals or declare theorems: prove,
TAC_PROOF and interactive e retain their existing algorithms, justification
checks and kernel. Runtime sources do not reader-reference generated packages,
so runtime-only compilation/loading remains possible.

#### Authorized sharp-backquote reader

At the user's explicit request, runtime `sharp-backquote-lambda-reader` installs
`(set-dispatch-macro-character #\# #\` #'sharp-backquote-lambda-reader)` in the
active `*readtable*` at compile, load and execute time. Load the runtime before
reading files containing this syntax. Copies of that readtable inherit it;
a fresh standard `(copy-readtable nil)` does not. Standard `#'` dispatch and
`readtable-case` are unchanged; source atom allocation is unchanged.

Standard `#'name` references a named function. In contrast, sharp-backquote
reads the next Lisp form once and returns a `CL:LAMBDA` wrapper with a gensym
rest-argument variable. The wrapper evaluates that function-value expression
on every invocation, not at construction, and forwards its arguments through
`CL:APPLY`, including zero arguments, NIL arguments and multiple return values.
Thus ``#`holai.tactics:DISCH_TAC`` wraps a value-held tactic, and
``#`holai.tactics:ACCEPT_TAC`` wraps its current value when invoked.

The reader supports handwritten wrappers and generated direct value calls
(§34). It can appear as an operand, but its lambda form is not a PROOF operator
reference. Bind the wrapper to a lexical value symbol to use it as an operator;
the value-symbol/exact FUNCTION-symbol grammar above remains unchanged.

### 33.2 Binding-identity translation boundary

The translator's private `binding.proof_combinator` flag is true only for a
new global binding in package `holai.tactics`, source `tactics.ml`, with no
lexical prefix, at source-name occurrence 1, and with exactly one of these
name/kind pairs: `then_`/Value, `thenl_`/Value, `orelse_`/Function 3.
Local, external and directly constructed Sys.Break bindings are false.
Record copies and open/include/module aliases that reuse the same binding
retain its identity and flag. A newly bound value alias does not inherit it;
neither do shadowing declarations, same-spelled bindings in other modules,
then1_, THENC or other conversion/theorem tacticals.

Recognition first requires an identifier head accepted by qualified_value,
then resolves it with find. Only a flagged binding with exactly two arguments,
neither labelled nor optional, becomes PROOF. References, partial applications,
three-or-more-argument direct goal applications, aliases and computed heads
retain ordinary lowering; eligible nested expressions still lower recursively.
No source-text, uppercase-name or output-symbol heuristic is used. The macro
head is always fully qualified `holai.runtime:proof`; source functions named
proof are not renamed for this feature.

References continue through reference/function_ref, preserving imports,
binding IDs and recursive-reference observers. Lowering processes lhs and its
origin, then rhs, then the operator reference, retaining existing symbol
allocation order. Only an eligible left child is joined to the same flat
column; rhs is emitted normally, hence eligible right groups become inner
PROOF forms. LET, lambda and annotations are not crossed. The MLast tree,
not textual parentheses, determines grouping and the restored binary call tree.

### 33.3 Fragment formatting and source provenance

The output tree adds `Fragment of t list` and its fragment constructor solely
for PROOF bodies. A Fragment emits sibling tokens without parentheses and
counts inter-token spaces in flat_length. Short sequences stay space-separated.
Beyond the 90-column limit, operator/right-operand pairs break after the first
operand; an oversized pair indents its right operand another two spaces.
Left-prefix Fragments inherit the sequence's break mode; independent right
PROOF operands format as ordinary lists. Other form formatting and existing
LET flattening are unchanged.

The `proof-tactical` source-map rule marks the root macro once with the root
application's Ploc.t, and each joined left-prefix Fragment with that original
binary application's Ploc.t. Child operand origins remain inside those spans.
The private binding flag is not a new JSON field. Generated Lisp and maps are
regenerated together; neither generated-text rewriting nor hand-edited maps
are part of this translation.

### 33.4 Verification boundary and current evidence

The preceding reader-inclusive PROOF variant was validated on aarch64-linux with
`nix develop path:. --command make release` using OCaml 4.14.2,
Camlp5 8.02.01 and SBCL 2.3.9.nixos. All 46 inputs compiled, loaded and
initialized. The run passed 122 existing native checks, 61 independent PROOF
checks, 46 structural-pattern, 27 calling-protocol, 84 OPTIONAL-entry and
16 tuple checks. All 1,132 differential rows matched: 1,125 serialized
observations and seven actual side-effect rows.

Initial registries remain exactly 22 types, 303 constants, 263 definitions
and the three source axioms INFINITY_AX, SELECT_AX and ETA_AX. Initialization
retains 5,519 OCaml and 5,517 SBCL message rows: the exact two OCaml-only
messages (`0..0..solved at 2` and `Warning: inventing type variables`) remain
the documented profile, not an identical-transcript claim. Source-map audits
passed for 194,839 core and 205,472 fixture-inclusive entries; the generated
core contains 6,943,214 Lisp bytes and 9,100 `proof-tactical` entries.
All ten rejection checks retained the previous output.

The native `holai/tests/proof-dsl.lisp` matrix covers real closed theorems,
literal/dynamic THENL branches, left/right grouping, interactive state
restoration, failure/justification boundaries, lexical value/function capture,
once-only evaluation and syntax errors. It is compiled/loaded after observation
capture and restoration of std_formatter's stream, outside the differential
stream. The runner records its measured `proof_dsl_checks` separately; release
requires a positive count and packages the unit. Eight fixture observations
exercise capture, branches, grouping, shadowing, a local function named proof,
partial application and direct goals. A separate fresh sharp-backquote
handwritten proof smoke produced the actual closed identity theorem.

Fresh-cache compilation of all 51 production units reported zero errors,
warnings and style warnings. Clean regeneration reproduced all 94 outputs
identically; all 55 retained source hashes were unchanged. Release packaging
and ZIP integrity checks passed, including the new proof unit, complete
translator, DESIGN/AGENTS, generated Lisp/maps, reports and matching observation
streams. See `misc/reports/verification.json`, `clean-build.json` and
`compile-diagnostics.json` for reproducible evidence.
The version remains 1.0.0-percent-names. No publication or PROOF performance
measurement is claimed; earlier baseline counts and timings remain historical.

The reader's runtime-only compile/load smoke also passed: per-call expression
evaluation and dynamic rebinding, rest argument forwarding, multiple values,
gensym hygiene and unchanged standard `#'` behavior. The completed release
measured all 61 PROOF checks, including 13 permanent reader checks with actual
zero-argument sum, positional decimal calculation, NIL classification, floor
quotient/remainder and lexical-argument hygiene computations. This runtime-only
addition leaves the differential fixture count (1,132), inclusive map inventory
(205,472) and production unit count (51) unchanged.

## 34. Reader-headed value applications

### 34.1 Indentation-driven translation boundary

Generated ordinary function-value application uses ``(#`f arg1 arg2)`` rather
than `(holai.runtime:funcall f arg1 arg2)`. This is a notation cutover to reduce
deep indentation, not an algorithm or performance optimization. The reader
prefix is attached directly to the structurally lowered head, whether an atom
or a computed expression: ``(#`(if condition left right) argument)``.
All value-application paths through compiler.call_value use this notation,
including computed heads and applying excess arguments to the result of a
foreign call. Translator-added forwarding calls that apply values use the same
boundary.

Direct calls to resolved named Function bindings remain ordinary named calls.
Named function references remain `#'`; foreign partial-application adapters
retain their existing construction. Plain function-value references passed as
arguments or captured in bindings remain eager references, not reader wrappers:
the cutover changes application heads, not the meaning of stored function
values. PROOF recognition, operator grammar and tactical emission (§33) are
unchanged. Runtime-internal `funcall` expansions and the public
`holai.runtime:funcall` API remain intact, as do manually authored semantic
tests of that API.

### 34.2 Intentional late acquisition of the head

In a direct reader-headed call, Common Lisp evaluates arguments left to right,
then invokes the reader-produced lambda. That lambda evaluates its function
expression once for that invocation and forwards the already evaluated
arguments through `CL:APPLY`, preserving multiple returned values. Consequently
an argument that rebinds a function value changes the function acquired by that
same call. This late-head timing is intentional; it is not eager acquisition
of the head as the first argument to `holai.runtime:funcall`. Repeated calls
re-evaluate a computed head once per call. Ordinary values passed or captured
without a reader prefix retain eager acquisition at their original expression.

No source algorithm, inlining, loop replacement, ANF conversion or evaluation
order temporaries are introduced. Existing lowering order, reference and
function_ref resolution, binding IDs, import handling and recursive-reference
observers remain the source of symbol identity and allocation order.

The runtime must be compiled/loaded before generated consumer files are read:
its compile/load/execute installation in the active `*readtable*` supplies
sharp-backquote dispatch. Readtable copies inherit the extension; a fresh
standard readtable made from NIL does not. Standard `#'`, `readtable-case`
and source atom allocation remain unchanged.

### 34.3 Structural rendering and evidence boundary

The dedicated `Sexp.ReaderPrefix of t` node and `reader_prefix` constructor
apply #` to an annotated atom or list. Rendering places the prefix adjacent to
the head without an extra parenthesis layer and counts it in flat_length.
Child Origin spans exclude the prefix; the enclosing application span includes
the complete call. Fragment remains reserved for PROOF bodies. This is
structural output, not generated-string postprocessing; Lisp and maps must
be regenerated together.

The existing native PROOF unit now also checks direct reader-headed lexical
curried partial/full calls, computed-head evaluation once per invocation after
argument-time rebinding, exact argument/head traces, and actual floor quotient
and remainder values. The completed integrated release measured 69 PROOF
checks. Its marker remains outside the observation stream after std_formatter
restoration. Existing fixtures already cover value
partials, returned-function excess calls and formatted foreign applications;
one added `reader_computed_head` observation covers a structurally computed
head and its evaluation count without duplicating those rows.

No fixture or production component is added: the 11 fixture and 51 production
unit boundaries remain. The combined §34/§35 release passed
`nix develop path:. --command make release`; its final measured inventory is
recorded in §35.3. §33's 61 checks, 1,132 differential rows, map inventories
and generated-byte measurements remain historical evidence for that variant.
No new performance result is claimed.

## 35. Shallow staged local named-function groups

Historical implementation and measurements only. Section 36 supersedes this
entry grammar, decoder and nested expansion; the results in §35.3 describe
the previous variant, not validation of the plain-entry cutover.

### 35.1 Printed groups, not broadened lexical scope

Alongside §34's shallow value-call heads, adjacent local named-function
groups print in one shallow `labelsc` definition list. This is a readability
change, not a claim that sequential source functions are parallel or mutually
recursive. The staged entry grammar is:

```lisp
(:nonrecursive stage name (parameters...) body)
(:recursive stage name (parameters...) body)
```

The tag and stage precede the function name, so metadata cannot be confused
with an ordinary function body form. The stage integer starts at zero and
increases by one per original adjacent source let; members of a source `and`
group share its stage and mode. The translator emits one body expression per
entry; the runtime also accepts multiple body forms as the ordinary macros do.
Nonrecursive members retain FLETC scope, recursive members retain LABELSC
scope. Ordinary untagged
`fletc` and `labelsc` continue to mean their existing nonrecursive and recursive
groups respectively.

For example, this already-lowered nesting (with illustrative resolved names):

```lisp
(fletc ((f (x) (+ x 1)))
  (fletc ((g (x) (f x)))
    (labelsc ((walk (x) (if (zerop x) (g x) (walk (1- x)))))
      (walk 2))))
```

prints as:

```lisp
(labelsc
  ((:nonrecursive 0 f (x) (+ x 1))
   (:nonrecursive 1 g (x) (f x))
   (:recursive 2 walk (x) (if (zerop x) (g x) (walk (1- x)))))
  (walk 2))
```

Here g depends on the preceding f; only walk's original recursive stage
sees its own recursive binding. Macroexpansion groups consecutive entries
by stage and folds from the last group toward the first, restoring the
original ordinary FLETC/LABELSC nesting. It must not turn the entire printed
list into one CL:LABELS scope. Sequential shadowing can reuse an earlier
emitted symbol: widening visibility would then capture an older reference
inside a preceding function body. Preserving the stage boundaries prevents
that capture without renaming source functions or adding a runtime dispatcher.

### 35.2 Structural boundary and provenance

Combine only immediately adjacent already-lowered named-function groups
under local-let Origins whose output is `fletc` or `labelsc`. Scalar LET
values, modules, match forms, lambdas and annotations are barriers; do not
search through them to collect more functions. Lower each group and its
body in the original order before combining the output. Binding allocation,
reference observers, imports and resolved source binding identities remain
unchanged, as do algorithms, direct named calls, `#'` references and adapters.

Retain removed local-let Origins around the combined form, with coincident
generated spans where needed, and preserve the original function and body
Origins. This is structural S-expression construction, not text rewriting
or hand-adjustment of generated Lisp/maps. Source-group provenance does not
require a separate printed parenthesis layer for each original let.

Stage flattening adds no source evaluation-order change, initialization,
function-value slots or runtime computation. §34's intentional late acquisition
of reader-headed function values remains a distinct application-timing rule;
it must not be attributed to stage flattening. Compile/load the runtime before
reading generated consumers so both the reader extension and staged macro
expansion are available.

### 35.3 Evidence boundary

Six added language observations cover function chains, mixed stages, repeated
shadows and captured function identities, parallel groups, imports and a
side-effecting closure-initializer barrier evaluated once. Their row names are
`language_function_chain`, `language_function_mixed`,
`language_function_shadow`, `language_function_parallel`,
`language_function_import` and `language_function_barrier`. Together with
`reader_computed_head`, these seven new rows match OCaml/SBCL exactly.

The final integrated `nix develop path:. --command make release` succeeded
in 217.72 seconds on aarch64-linux with OCaml 4.14.2, Camlp5 8.02.01 and
SBCL 2.3.9.nixos. All 46 inputs loaded; 122 existing native, 69 independent
PROOF, 27 protocol, 84 OPTIONAL, 16 tuple and 46 pattern checks passed.
All 1,139 differential rows matched (1,132 serialized and seven side-effect
rows). Initial registries remain 22/303/263/3 with the original three axioms;
5,519 OCaml/5,517 SBCL initialization rows retain the two known OCaml-only
messages, not identical raw transcripts.

All 194,839 core/205,818 inclusive source-map entries passed audit. Removed
scope Origins survive as coincident spans around merged groups; function and
body Origins remain. Ten rejection checks preserved output, 51 fresh-cache
production units had zero errors/warnings/style warnings, 94 clean outputs
were identical, and all 55 retained input hashes were unchanged. That variant's
generated core Lisp totals 6,174,070 bytes, an inventory measurement rather
than a performance claim. See misc/reports/verification.json, clean-build.json
and compile-diagnostics.json.

Separate actual smokes proved a closed identity theorem with generated core,
checked all six language-group results, and exercised direct staged macros
with duplicate names, parallel outer RHS scope, captured partial functions
and mutual recursion. Staged headers keep tag, stage, name and parameters
together when they fit the 90-column width (three leading header fields),
then put the body on a new line. This is a shallow presentation, not broader
visibility or a claim that every file's maximum indentation decreased.
Ordinary untagged macro syntax remains necessary for handwritten callers,
not a compatibility alias. No performance result is claimed.

## 36. Plain local named-function groups

### 36.1 One resolved CL:LABELS scope

All generated local named-function groups, including isolated nonrecursive
and recursive groups, use ordinary `labelsc` entries:

```lisp
(labelsc
  ((f (x) (+ x 1))
   (g (x) (f x))
   (walk (x) (if (zerop x) (g x) (walk (1- x)))))
  (walk 2))
```

Adjacent source groups share this one definition list, without mode keywords
or group numbers. Expansion creates one genuine CL:LABELS scope, not nested
scopes reconstructed from metadata. The translator resolves each source
reference before emission, so the broader target scope does not make later
source bindings visible to earlier RHSs. Nonrecursive RHSs retain the
preceding environment; members of a nonrecursive parallel `and` group do not
see one another. Recursive RHSs see their own original recursive group and
the preceding environment, not later groups in the combined list.

Every function target in the combined list must be distinct under the CL
reader's logical-symbol normalization, including earlier targets hidden by
later source shadows and names differing only in case. At chain entry, reserve
the logical targets of **all visible bindings** for the entire chain; also
reserve each newly allocated member until the chain ends. A later member must
never reuse an entry-visible target merely because its source binding has
since been shadowed. Otherwise an earlier RHS referring to that outer target
would be captured by the later CL:LABELS definition.

These are scoped allocator reservations, not fake environment bindings.
Reservations must not alter source lookup, RHS environments, binding IDs,
reference observers or imports. Use the existing deterministic local percent
suffix allocator when a target collides; preserve original source spellings.
Resolve and lower groups in source order, retaining the original nonrecursive,
parallel and recursive environments. Do not compile RHSs in the union of the
combined group's source bindings.
Allocate and lower each original group and its function bodies before allocating
the continuation's binders or lowering its RHSs. Reservation is not permission
to preallocate future bindings. Preserve original lowering and binding-ID order
except necessary target suffix changes.

The translator no longer emits local `fletc` groups or the §35 metadata
grammar. The old compiler helpers, runtime metadata-decoding branch and
metadata-only formatter rules are removed, without a compatibility shim.
Handwritten `fletc` retains its ordinary nonrecursive
outer-RHS API; ordinary handwritten `labelsc` remains recursive.

### 36.2 Barriers, observations and provenance

Collect only immediately adjacent source local named-function groups.
Scalar LET bindings, local modules, match, lambda and annotations stop the
chain. In particular, do not cross a scalar initializer to collect more
functions. Side-effecting initializers retain their original position and
execute once. This change introduces no function-value slots, dispatcher,
initialization or source algorithm/evaluation-order rewrite.

Captured function values and partial functions continue to refer to their
resolved original definitions; repeated acquisition of the same named function
retains physical identity, and distinct shadowed definitions remain distinct.
Direct named calls, standard `#'` references and foreign partial adapters
remain unchanged. Section 34's intentional late acquisition of reader-headed
values is separate and unchanged.

Retain every source local-let Origin around the combined output, allowing
coincident spans, and retain the existing function/body Origins and reference
marks. Resolved target renaming does not change source identities or spellings.
Construct the output structurally and regenerate Lisp/maps together; do not
rewrite emitted strings or repair map offsets by hand. Ordinary entries keep
name and parameters together when they fit the 90-column width, with the body
on a new line.

Lexical-module named function declarations also use ordinary `LABELSC`.
Only immediately adjacent named declarations inside one structure combine;
module declarations, aliases and includes, value or mixed slots, effects and
the external continuation remain barriers, even when an alias has no runtime
output. The module combiner peels only local-module-binding Origins. RHS
environment snapshots and original right-fold wrapper compilation order stay
unchanged.

Lexical global allocation reserves entry-visible names, including qualified
module public exports, and previously allocated targets; percent collision
suffixes avoid future ordinary prefixed/versioned names. Alias public
environments are visited once; functor captured environments are not traversed.
Top-level global allocation is unchanged. This prevents a new local module
`M.f` from capturing a resolved reference to an older `M.f`. No generated
`FLETC` calls remain; handwritten `FLETC` is retained. Plain local definition
headers keep the name/parameter list together when it fits 90 columns, using
a context-specific renderer without stage markers.

### 36.3 Historical validation of the preceding variant

The final module-inclusive plain-entry cutover passed
`nix develop path:. --command make release` in 218.79 seconds on aarch64-linux
with OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos.
Section 35.3 preserves the previous release's measurements as history, not
the current runtime API. No new performance result is claimed.

The six existing `language_function_*` observations remain unchanged. Three
additional behavioral observations use the existing curried functions and
unmodified serializers. All three rows matched in the completed full release:

```text
language_function_entry_shadow=142,142,284,284,42,42,42,42:true:true:true:true:true:true:true
language_function_case_shadow=42,42,42,42:true:true
language_module_function_scope=42,42,42,142,284,42,42,42,42,42,42,1,285,42,1:42,42,42,142,284,42,42,42,42,42,42,1,285,42,1
```

The first separates an outer local `f` from an inner chain with a scalar LET,
then shadows `f` repeatedly. Its first inner RHS calls the outer function;
full function captures and partial applications across all four inner shadows
must retain the old results and full-function identities.
The second hides an earlier `K` before introducing `k` and further `K`
shadows, exercising source case sensitivity despite CL reader normalization.
Existing observations retain parallel RHS, mutual recursion, import, physical
identity and once-only barrier coverage; no duplicate native unit is added.
One added `language_module_function_scope` observation exercises escaped
closures/partials, repeated module names, sequential and parallel dependencies,
case shadowing, imports, aliases and once-only initialization. Together with
the entry/case rows this gives 1,142 matching OCaml/SBCL rows: 1,135 serialized
observations and seven actual side-effect rows. No native counter is added.

All 46 inputs loaded; 122 native, 69 independent PROOF, 27 calling-protocol,
84 OPTIONAL-entry, 16 tuple and 46 structural-pattern checks passed.
Initial registries remain 22 types/303 constants/263 definitions/3 axioms,
with exactly the original three source axioms. The 5,519 OCaml/5,517 SBCL
initialization rows retain the exact two known OCaml-only message differences.
All 194,839 core/206,245 inclusive map entries passed audit. Ten rejection
checks preserved output; 51 fresh-cache production units had zero errors,
warnings or style warnings; 94 clean-generated outputs were identical and
all 55 retained input hashes were unchanged. The release ZIP's 305 members
(304 payload files plus RELEASE-MANIFEST.json) were verified. Generated core
Lisp totals 5,727,348 bytes after final header formatting, an inventory
measurement rather than a performance claim.
See misc/reports/verification.json, clean-build.json and compile-diagnostics.json.

Separate fresh-core smoke proved an actual closed identity theorem, ran all
69 PROOF checks and eight ordinary function-scope cases, and ran the escaped/
rebound module closure/partial and once-only initialization case twice with
the exact expected results. Static search found zero generated FLETC calls
or stage tags.
For this preceding checkpoint, the full-release gate was satisfied and the user
authorized committing and pushing to `tani/holai` main. Authorization and
validation are not evidence that a push occurred, nor authorization or validation
of the new §37 cutover.

## 37. One ASDF definition and inferred package dependencies

### 37.1 Systems, providers and ordering

Maintain exactly one production system-definition file, root `holai.asd`.
The main `holai` system is an ASDF `package-inferred-system` with pathname
`holai/` and dependency `holai/all`. The maintained `holai/all.lisp` uses
`uiop:define-package` and an empty import from terminal package `holai.define`;
it is a real inferred orchestration source, not a public reexport facade.
Public packages remain `holai.runtime`, `holai.<input-stem>` and their existing
nested module packages. There are no old-system compatibility aliases.

`holai/runtime` is the only explicit source-component exception, defined in
the same ASD: package, pattern, core, format and stdlib retain their original
five-file order and shared package. Runtime-only callers require ASDF before
reading UIOP declarations, register only the repository root and load this
subsystem without initializing the HOL core.

The translator emits `holai/generated/package-systems.sexp`, one ordered
readable data form mapping each input stem to every uppercase package name
provided by its physical file, including private, nested and empty-export
packages. The root ASD reads this data and registers providers as
`holai/generated/<stem>`; it maps `HOLAI.RUNTIME` to `holai/runtime`.
Root ASD and entry are maintained outside generated output. Arbitrary
`--output-dir` translation never overwrites them. The 46 Lisp/map pairs plus
inventory and provider data still total 94 generated outputs.
Only after all inputs translate successfully does the CLI remove its owned
obsolete generated ASD files. Rejected translation leaves prior output
byte-for-byte unchanged; unrelated outputs are not pruned.

Stock ASDF scans only the first top-level package declaration for dependencies.
Each generated file therefore starts with a real UIOP root-package shell,
with owned shadows/exports/internals and empty imports from runtime, the
previous input's root package and every externally referenced provider.
Exclude every same-file package from these dependency imports to avoid inferred
self-dependencies. The predecessor edge preserves the original 46-file vendor
initialization order rather than relying on dependency-list ordering.
Create remaining guarded same-file shells before full selective imports.

### 37.2 Reader ownership and prefix reduction

Resolved references retain the existing binding IDs, package/symbol identity,
reference observers and source provenance. A lexical module's forms are read
in its enclosing reader-owner package: its canonical imports, local symbol
allocation and shadows belong to that owner. Record foreign dependencies even
when collision/private/versioned references must remain qualified.

Full UIOP declarations retain CL and mix it first with already loaded foreign
input providers, alongside precise canonical imports or shadowing imports.
Do not broadly mix same-physical-file packages: parent/child shells and late
exports can otherwise introduce conflicts. Shadow all owned and lexical target
symbols, including ordinary lexical values whose names resemble foreign SPECIAL
exports such as runtime UNIT. Native CL control references must not acquire a
foreign meaning. Private makers remain internal, never exported merely to
shorten a reference. Keep synthetic CL control/constructor qualification,
`holai.runtime:proof`, original strings and reader case unchanged.
This is a package/dependency and printed-reference cutover, not an algorithm,
evaluation-order, declaration-boundary or public source-API change.

### 37.3 Verification boundary

Section 36's completed release and its 51-unit results remain historical evidence
for the preceding variant. Do not relabel historical checkouts or raw reports.
The §37 cutover passed `nix develop path:. --command make release` (exit 0,
226.10 seconds) on aarch64-linux with OCaml 4.14.2, Camlp5 8.02.01 and
SBCL 2.3.9.nixos.

All 46 upstream inputs initialized in original order. The release passed 123
native, 69 PROOF, 46 structural-pattern, 27 calling-protocol, 84 OPTIONAL-entry
and 16 tuple checks. All 1,143 differential rows matched: 1,136 serialized
observations plus seven side-effect rows. All 194,839 core / 206,277
fixture-inclusive source-map entries passed audit; ten rejection cases preserved
output. Initial types/constants/definitions/axioms remain 22/303/263/3, with
exactly the three source axioms. The 5,519 OCaml / 5,517 SBCL initialization
rows retain exactly the two known OCaml-only messages, not raw-message equality.

Fresh-cache diagnostics recorded 52 unique production source pathnames in real
compile/load order: runtime five, generated 46 in manifest order, then
`holai/all.lisp`. The latter 47 belong to genuine inferred systems. Diagnostics
reported zero errors, warnings, style warnings or notices. All 94 clean outputs
were identical and all 55 retained input hashes unchanged.

Separate fresh ASDF 3.3.1 runs loaded runtime alone, inferred the full core's
46 ordered sources, and loaded `holai/generated/fusion` with the kernel but
without parser/later theories. The full-core smoke proved a closed `p ==> p`,
checked private constructors and retained the original three axioms after reload.
Existing private/namespace/parent-capture coverage and the new lexical-module UNIT
escaped-closure regression passed; independent seeds remain lexical and runtime
UNIT is unchanged.
An extracted-archive smoke also exited 0 with pinned SBCL launched outside the
repository and only the extracted `holai/` root registered: runtime loaded
without fusion, then genuinely inferred fusion loaded its nested HOL package
without parser/later theories. The temporary extraction was removed.

The release archive contains 306 members (305 payload files plus
`RELEASE-MANIFEST.json`), only one ASD (`holai/holai.asd`), all 92 generated
Lisp/map members, entry and provider data. Generated core Lisp totals 5,980,663
bytes. Static runtime-prefix inventory in impconv fell from 910 to 59; meson
remains 51 and metis 105. Larger shadow declarations mean this is not evidence
of smaller total source or improved performance. The user subsequently
authorized committing and pushing this validated cutover to `tani/holai` main.
