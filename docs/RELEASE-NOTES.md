# Holai 1.0.0-percent-names

## Native implementation matrix (measured profile passes)

The original compiler and SBCL/ECL pins are retained. A separately pinned
nix-common-lisp reference source supplies additional candidates ABCL, CLISP,
CCL, MKCL, CMUCL and Clasp. Packages are filtered by evaluability, platform and
broken metadata with explicit exclusion reasons. The current aarch64-linux
default matrix is SBCL/ECL/ABCL/CLISP, with measured profile passes as below.
`HOLAI_LISPS` selects hosts; only SBCL is required for the full-core profile.
Every selected additional host must pass the bounded `runtime-fixtures`
compatibility profile, with a 120-second guard per process. Its independently
recorded `compatibility_passed` status explicitly leaves full-core verification
false; compatibility does not establish full HOL Light initialization.
ASDF is required before ASDF/UIOP symbols are read.
The SIGINT gate passed on the production adapters: three actual deliveries,
two Sys.Break catches across re-enable and restored OS-default termination
with exit -2. This does not establish additional-host full-core verification.
Native-compiled NaN/EQL is
explicitly not applicable on CLISP (no representable native IEEE NaN) and ECL
(the compiler cannot externalize `#<double-float quiet NaN>` into a FASL):
both retain 45 structural checks. SBCL and ABCL retain 46. This records a native
compiler capability, not a skipped finite case or an OCaml NaN-input restriction.
Stale declaration ABI rejection is checked in a separate Lisp process on every
host by loading a real compiled consumer against a changed declaration; only
the structured stale condition, its marker and expected nonzero exit pass.
Reports and source archives retain the isolated rejection log.
Random now uses standard Common Lisp RANDOM with a private standard random-state.
Random.init ignores its integer seed and resets via MAKE-RANDOM-STATE T; integer
seed replay is not guaranteed. Tests validate explicit-state advancement,
snapshot replay and bounds without assumptions about host-internal entropy or
default-state behavior. Weak storage and SIGINT use real host adapters.

Ordinary `make release` requires SBCL's complete native/PROOF/OCaml differential
profile and cold 52-path/47-inferred manifest-order compiler diagnostic audit.
Additional hosts require actual runtime/translated-fixture compile/load and
observations, defunc/OPTIONAL/tuple-list checks, real interrupt restoration,
weak retention, standard Random and structural matching/stale FASL checks.
Packaging validates exact host identities, current source fingerprints, measured
counts and matching actual log digests; it does not require additional hosts'
full-core observation streams or cold caches. The 94 clean outputs and 55 source
pins remain gates. Evidence is tagged under `misc/reports/implementations/<id>/`;
the previous root SBCL baseline remains historical, without relabelling.

`HOLAI_LISPS=ecl,abcl,clisp make test-full-core` explicitly runs additional hosts'
complete native tests and cold diagnostics. Those full-core processes retain
the previously approved 3600-second guard; SBCL and original OCaml retain 600
seconds, ordinary checks retain 120 and negative search bounds are unchanged.
The optional aggregate is implementation-full-core-matrix.json, not the ordinary
release gate. The extended ordinary matrix was cancelled; incomplete ABCL
full-core results remain incomplete, and earlier 600-second attempts/warm probes
are retained under misc/reports/history/portable-600-second-attempt/.
The literal language_random= row is validated for its 8/8/4 group shape and
2^30/97/2^30 bounds before canonical comparison. The user additionally selected
generated-name-only structural comparison for init_constants/init_definitions,
not record/replay or a replacement random engine. A pinned-source guard rejects
authored positive `_decimal` tokens before provenance classification. One shared
generated-constant identity map and distinct tag preserve reference identity
across both rows; positive `_decimal` bound variables use actual binder indices.
Authored `_0`, free variables, explicit/unknown constant names, concrete types,
sharing, order and multiplicity remain observable. All other rows remain exact.
See DESIGN's observation boundary for the complete observer-only contract.
Fresh-counter divergence was localized around METIS at int.ml:2239; attributing
the exact two allocations remains [INFERENCE], not a reason to rewrite source.
Packages retain raw and canonical streams and hashes, actual structured
identities and separate exact/property/structural counts. The measured SBCL
corpus has 1,149 rows: 1,146 literal-exact, two structural registry comparisons
and one Random property row; raw streams are unequal. Historical seeded
SBCL/OCaml reports remain unchanged.

Current SBCL full-core verification passed 128 native and 69 PROOF checks,
with unchanged initial registries 22/303/263/3 and the original three axioms.
Initialization has 5,519 OCaml / 5,517 SBCL rows with only the two existing
OCaml-only messages. Map audits cover 194,839 core / 207,058 fixture-inclusive
entries, including current regressions, and ten rejections preserved outputs.
The 52-path/47-inferred cold audit exited 0 with zero compiler errors, warnings,
style warnings and notices. Its load/initialization accounting is separate:
zero errors/warnings, 21 style warnings and 164 notices.

ECL, ABCL and CLISP each passed the 120-second-per-process runtime-fixtures
profile: 28 defunc protocol, 84 OPTIONAL, 16 tuple-list and 1,816 Random checks;
three translated fixtures and 33 exact differential rows; nine naming rows.
Their structural counts are respectively 45, 46 and 45. Reports record current
source fingerprints, actual exits and digest-matched logs, and all explicitly
leave full-core verification false. Fixture fingerprints cover Lisp sources,
maps, provider data and inventory only; compiled FASLs are neither captured
nor shipped. Earlier full-core timeouts and incomplete extended attempts remain
failures/incomplete evidence, not compatibility passes.

The final `nix develop path:. --command make release` exited 0 in 269.03 seconds.
It regenerated all 46 inputs, passed full tests and cold diagnostics, and used
SBCL full-core evidence for inventory. Fresh clean generation matched all 94
outputs and confirmed 55 unchanged input pins. The archive producer reported
427 payload files. The earlier inventory failure requiring a CLISP full
verification report is historical, superseded by this completed release;
older package measurements below remain historical.

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
See DESIGN §33 and the README's imported development-code example; its separate
fully qualified example intentionally demonstrates the external API.

### Safe bare PROOF in development code

The readability request covers translator-generated and maintained handwritten
**software development code**, not only end-user examples. Generated tactical
heads use deferred cells finalized after completed structure lowering for the
actual reader-owner namespace, before declarations, dependency emission and
rendering. Safe owners explicitly import runtime PROOF and emit bare `proof`.
Existing owned/local/imported-symbol conflict handling plus the maker-shadow
guard keeps `holai.runtime:proof` in conflicting owners, including declarations
that appear after the first tactical. Lexical modules share their enclosing
reader owner's decision; static child packages decide separately.
No PROOF reservation or source-binder renaming is added; algorithms, binding
identities, tactical eligibility and source-map origins are preserved.

Ordinary handwritten `holai/tests/proof-dsl.lisp` cases explicitly import the
runtime macro with UIOP and use bare `proof`. The original distinct-symbol local
PROOF function versus qualified macro regression remains in its own CL-only
package and uses the original helpers/counter; no theorem checks are removed.
Intentionally qualified external-API/collision examples remain qualified.
The actual safe-bare extension release passed
`nix develop path:. --command make release` (exit 0, 227.15 seconds):
129 native and 69 independent PROOF checks passed, and all 1,149 differential
rows matched (1,142 serialized plus seven actual side-effect rows).
Native collision-symbol tests passed. All six `proof_reader_*` observations
matched OCaml/SBCL: safe_child, late_local, late_global, foreign_import, case
and lexical_module. A separate fresh theorem smoke exited 0 in 72.41 seconds:
an explicitly importing package used unqualified `proof`, `DISCH_TAC`, `THEN`,
`FIRST_ASSUM`, `ACCEPT_TAC`, `prove`, `tuple`, `hyp` and `concl`, producing an
actual closed `p ==> p` whose conclusion matched the expected term.

All 46 inputs initialized; initial registries22/303/263/3 and exactly the
three source axioms are unchanged. The 5,519 OCaml/5,517 SBCL initialization
rows retain only the two known OCaml-only messages. All 194,839 core/206,472
inclusive map entries passed audit and ten rejections preserved output.
Fresh-cache diagnostics covered 52 unique production files in compile/load
order, including 47 genuine inferred core/entry components, with zero errors,
warnings or style warnings. All 94 clean outputs matched and 55 retained pins
were unchanged. The archive contains 305 payload files plus its manifest
(306 members), with no added repository files.

Static generated inventory records 2,353 bare PROOF heads and 25 qualified
collision heads; core Lisp totals 5,942,245 bytes. These counts are inventory,
not behavioral correctness or performance evidence. Completed reader-owner
decisions remain deferred, with no eager PROOF imports or source-binder renaming.
See DESIGN §37.4. All following preceding-release measurements remain historical.

The preceding reader-inclusive PROOF variant used `nix develop path:. --command make release` on
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
to a lexical value symbol for that role. PROOF grammar is unchanged. Generated
value-call notation now follows the separate cutover below.

The runtime-only compile/load smoke passed, covering per-call evaluation,
dynamic rebinding, zero/multiple/NIL arguments, multiple values, gensym hygiene
and unchanged `#'`. The completed reader-inclusive release measured 61 PROOF
checks, including thirteen permanent reader checks with actual zero-argument
sum, positional decimal calculation, NIL classification, floor quotient/
remainder and lexical-argument hygiene computations. This runtime addition
leaves the 1,132 differential rows, 205,472 inclusive maps and 51 production
units unchanged; no publication or performance result is claimed.

## Reader-headed generated value calls

Generated value applications now use ``(#`f arg1 arg2)`` to reduce indentation,
including structurally computed heads and foreign excess-result calls.
This is a source-preserving notation change, not a performance optimization.
Direct named calls, `#'` references and foreign partial adapters retain their
existing paths. Function values passed as arguments or captured in bindings
stay eager plain references; they are not implicitly wrapped.

The function expression is acquired once per invocation **after** left-to-right
argument evaluation. An argument that rebinds it therefore selects the new
function for the same call. Direct reader calls preserve partial currying and
multiple return values. Runtime must be loaded before consumer files are read.
PROOF recognition/grammar/tactical emission and runtime-internal funcall/API
remain unchanged. A dedicated structural ReaderPrefix output node renders the
prefix adjacent to the annotated head and preserves source-map origins;
Fragment stays PROOF-only, with no generated-string postprocessing.

Eight added native consumer checks bring the measured `proof_dsl_checks` count
to 69 in the completed combined DESIGN34/35 release. One new
`reader_computed_head` observation checks a computed head and evaluation count
without duplicating existing partial/excess paths. No fixture/load component
is added (11/51). The completed DESIGN §36 release retains these checks;
historical integrated inventories are below. No new performance result is claimed.
See DESIGN §34.

## Plain local named-function groups

DESIGN §36 replaces the historical §35 representation with ordinary entries
in one shallow `labelsc` definition list:

```lisp
(labelsc
  ((f (x) (+ x 1))
   (g (x) (f x))
   (walk (x) (if (zerop x) (g x) (walk (1- x)))))
  (walk 2))
```

All generated local named-function groups use this syntax, including isolated
nonrecursive and recursive groups. Adjacent source groups share one genuine
CL:LABELS scope. Source references remain resolved in their original RHS
environments: nonrecursive and parallel RHSs see the preceding environment;
recursive RHSs see their own original recursive group, not later groups.
The compiler/runtime metadata-decoding path is removed without a shim.
Handwritten `fletc` retains its existing nonrecursive outer-RHS behavior.

Every function target stays unique throughout the combined chain, including
hidden earlier shadows and case collisions. All entry-visible logical targets
remain reserved through chain exit, as does every newly allocated member.
Scoped reservations use the existing local percent suffix allocator, without
fake environment bindings, changed source lookup or altered source spellings.
This prevents a later local definition from capturing an earlier RHS's
reference to an outer function even after repeated shadows.

Scalar LET values, modules, match, lambda and annotations stop grouping.
Initializers retain their position and execute once; captures, partials and
physical function identities retain their source bindings. All local-let
Origins survive with coincident output spans, together with function/body
Origins, binding IDs and lowering/import/reference order. No algorithms,
direct named calls, standard `#'` references or foreign adapters change.
DESIGN §34's late reader-head acquisition is separate and unchanged.
Ordinary entries keep name/parameters together when they fit 90 columns,
then place the body on a new line.

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

Final module-inclusive full-release validation of the plain-entry cutover passed.
The six existing `language_function_*` rows remain unchanged. Three added
behavioral cases produced these matching OCaml/SBCL rows:

```text
language_function_entry_shadow=142,142,284,284,42,42,42,42:true:true:true:true:true:true:true
language_function_case_shadow=42,42,42,42:true:true
language_module_function_scope=42,42,42,142,284,42,42,42,42,42,42,1,285,42,1:42,42,42,142,284,42,42,42,42,42,42,1,285,42,1
```

They cover an outer local function separated by a scalar LET from repeated
inner shadows, full function/partial captures across all four inner shadows,
stable and distinct function identities, and hidden case-sensitive names.
The added `language_module_function_scope` observation exercises escaped
closures/partials, repeated module names, sequential and parallel dependencies,
case shadowing, imports, aliases and once-only initialization. Together with
the entry/case rows this gives 1,142 matched rows (1,135 serialized observations
and seven actual side-effect rows).

`nix develop path:. --command make release` succeeded in 218.79 seconds with
OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos. All 46 inputs loaded;
122 native, 69 independent PROOF, 27 calling-protocol, 84 OPTIONAL-entry,
16 tuple and 46 structural-pattern checks passed. All 194,839 core/206,245
inclusive map entries passed audit; ten rejections preserved output.
51 fresh-cache production units had zero errors/warnings/style warnings,
94 clean outputs were identical and 55 retained input pins unchanged.
Initial registries remain 22/303/263/3 and exactly the three original axioms;
5,519 OCaml/5,517 SBCL initialization rows retain the two known OCaml-only
message differences. The release ZIP's 305 members (304 payload files plus
RELEASE-MANIFEST.json) were verified. Generated
core Lisp totals 5,727,348 bytes after final header formatting, an inventory
measurement rather than a performance result.

Separate fresh-core smoke proved a closed identity theorem, passed 69 PROOF
checks and eight ordinary function-scope cases, and ran the escaped/rebound
module closure/partial and once-only initialization case twice with exact
expected results. Static search found zero generated FLETC calls or stage tags.
The full-release gate is satisfied; the user authorizes commit/push to
`tani/holai` main. This is not a publication claim. No new performance result
is claimed.

### Historical DESIGN §§34–35 validation

The previous combined `nix develop path:. --command make release` succeeded
in 217.72 seconds with OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos.
All 46 inputs loaded; 122 existing native and 69 independent PROOF checks
passed. All 1,139 differential rows matched (1,132 serialized, seven side
effects), including the computed-head row and six language-group rows
covering chains, mixed nonrecursive/recursive groups, shadows/captured
identities, parallel groups, imports and a once-only initializer barrier.
All 194,839 core/205,818 inclusive maps passed audit, retaining all scope
Origins as coincident merged spans. Ten rejections preserved output;
51 fresh-cache units had zero errors/warnings/style warnings, 94 clean outputs
were identical and 55 input pins unchanged. Initial registries22/303/263/3,
the original axioms and the two known initialization-message differences
remained unchanged. That variant's generated core totals 6,174,070 bytes.
Separate actual smokes proved a closed identity, checked the six language
rows and the former metadata-based macros. DESIGN §35 retains their original
contract and results as history, not the current runtime API or §36 evidence.

## Pending discussion

- TODO: Start a discussion of potentially excessive `funcall` usage in this project. Distinguish `holai.runtime:funcall` and curried application from native `CL:FUNCALL`; measure actual call hotspots and allocation before proposing changes. This is an investigation topic, not a demonstrated performance problem or an optimization included in this layout/API cutover.

## Unified ASDF definition and UIOP package inference

DESIGN §37 replaces the previous system definitions with one root `holai.asd`.
Load `holai` for the complete core or `holai/runtime` for runtime-only use;
generated `holai/generated/<stem>` systems are genuinely package-inferred.
Register only the repository root and require ASDF before UIOP package reading.
The main `holai` system is package-inferred through `holai/all.lisp`; only
`holai/runtime` has explicit components, its five shared-package files in the
same root ASD and original order.
There are no compatibility system aliases. Public `holai.*` packages,
private constructors, source bindings and algorithms remain unchanged.

Generated `package-systems.sexp` records every physical file's root/nested/private
provider. The first UIOP root shell declares runtime, predecessor and external
dependencies, excluding same-file packages. Remaining shells precede canonical
imports. Safe CL-first foreign-input mixes shorten references without exporting
private makers or turning lexical values into inherited SPECIAL bindings.
The inferred `holai/all.lisp` entry raises production compiled units to 52.
Generated outputs remain 94; clean/release comparisons include the provider data.

The preceding cutover (historical DESIGN §37.3) passed `nix develop path:. --command make release` (exit 0,
226.10 seconds) on aarch64-linux with OCaml 4.14.2, Camlp5 8.02.01 and
SBCL 2.3.9.nixos. All 46 inputs initialized in original order; 123 native,
69 PROOF, 46 pattern, 27 protocol, 84 OPTIONAL and 16 tuple checks passed.
All 1,143 differential rows matched (1,136 serialized plus seven side-effect
rows), and 194,839 core/206,277 inclusive map entries passed audit.
Ten rejection cases preserved output. Initial registries remain 22/303/263/3
with exactly the original three source axioms; initialization retains only the
two known OCaml-only messages (5,519 OCaml/5,517 SBCL rows), not raw equality.
Fresh-cache diagnostics recorded 52 unique production paths in compile/load
order, including 47 genuine inferred core/entry components, with zero errors,
warnings, style warnings or notices. All 94 clean outputs were identical and
55 retained input hashes unchanged.

Fresh ASDF 3.3.1 smokes loaded runtime alone, the complete inferred 46-source
core and fusion without parser/later theories. The full-core smoke proved a
closed `p ==> p`, checked private constructors and retained the three axioms
after reload. Existing private/collision/parent-capture coverage and the new
lexical-module UNIT escaped-closure/native runtime-UNIT preservation check passed.
Reader-owner local shadows preserve CL control and lexical scope; prefixes
remain where ownership or collisions require them.

The archive contains 306 members (305 payload plus `RELEASE-MANIFEST.json`),
only one ASD, entry/provider data and all 92 generated Lisp/map members.
Core Lisp totals 5,980,663 bytes. The impconv runtime-prefix inventory fell from
910 to 59; meson remains 51 and metis 105. Increased shadow headers preclude
inferring smaller total source, and no performance claim is made.
Earlier §36 counts/timings remain historical. This preceding validated cutover
was already pushed as `36f3a78`. The user now explicitly authorizes committing
and pushing the verified safe-bare extension with the simple, tidy README rewrite
to `tani/holai` main. Final repackaging, review, commit and push belong to the
parent; this authorization is not a claim that publication has occurred.
