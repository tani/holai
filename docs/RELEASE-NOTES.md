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

The cutover passed `nix develop path:. --command make release` (exit 0,
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
Earlier §36 counts/timings remain historical. The user explicitly authorized
committing and pushing this validated cutover to `tani/holai` main.
