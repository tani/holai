# Instructions for work on Holai

Read DESIGN.md before making a change. The user's priority is structural,
readable OCaml-to-Lisp translation, even when argument evaluation order differs.

- Keep DESIGN.md, AGENTS.md, and all OCaml translator sources in every artifact.
- Update DESIGN.md when translation rules, runtime boundaries, supported input,
  or measured validation change. Keep status factual and reproducible.
- Never hand-edit generated Lisp or source maps. Repair ml2cl/ or holai/runtime/ and
  regenerate. Do not patch the upstream input to evade unsupported syntax.
- Do not introduce algorithm changes, inlining, loop conversion, or anonymous
  evaluation-order temporaries. Preserve source bindings, aliases, and scopes.
- Reject unsupported syntax and unresolved references with source locations.
  Parsed, translated, compiled, and differential-tested are distinct states.
- Use real Camlp5 pa_j. Production matching uses the standard-CL static
  compiler specified in DESIGN30; do not describe it as Trivia.
- Compile the translator and generated files; run the applicable fixture,
  kernel, differential, source-map, and regeneration checks before release.
- Keep original licensing in pinned and generated inputs, and pin dependencies.
- Package with `make release`; its manifest must include the design and source.
- Latest completed historical validation is the split-profile release:
  `nix develop path:. --command make release` exited 0 in 269.03 seconds.
  All 46 unchanged vendor/CORE_FILES.json inputs initialize in original order;
  128 native and 69 independent PROOF checks passed. The 1,149 differential rows
  comprise 1,146 exact, two structural registry and one Random property comparison.
  Map audits cover 194,839 core / 207,058 fixture-inclusive entries. Ten protected
  rejection cases, fresh 94 identical clean outputs and 55 unchanged pins passed.
  Fresh-cache diagnostics covered 52 unique production source paths, including
  47 inferred core/entry components: zero compiler errors, warnings, style warnings
  or notices. Separate load/initialization accounting records zero errors/warnings,
  21 style warnings and 164 notices. ECL/ABCL/CLISP each passed three runtime
  fixtures and 33 exact rows, not full-core verification. Fixture fingerprints
  cover Lisp/maps/provider/inventory only; compiled FASLs are neither captured
  nor shipped. Inventory uses SBCL full-core evidence; the archive producer
  reported 427 payload files.
  Initial types/constants/definitions/axioms: 22/303/263/3. Initial inductive
  definitions: 3; rewrite/conversion/congruence/monotonicity lists: 34/5/8/9.
  Source axioms are exactly INFINITY_AX/SELECT_AX/ETA_AX; the primitive-kernel
  fixture explicitly adds one test-only witness axiom after the initial snapshot.
  All standard-manifest TODOs are complete. Generic OCaml/library completeness
  and optional HOL Light libraries outside the manifest remain outside the profile.
  Update factual counts from reports when implementation or corpus changes.
- Prior explicit-ASDF release passed locally on ARM64 Linux: `make release`
  exited 0 in 283.44 seconds, with SBCL full-core and ECL/ABCL/CLISP compatibility.
  Tagged SBCL reports record 128 native/69 PROOF checks, 1,149 differential rows
  (1,146 exact, two structural registry, one Random property), 194,839 core /
  207,058 fixture-inclusive map ranges and ten protected rejections. Fresh cold
  compilation covered all 52 physical files (six runtime plus 46 core) in literal
  ASD order with zero compiler diagnostics; separate initialization accounting
  remains zero errors/warnings, 21 style warnings and 164 notices. Clean generation
  reproduced 93 outputs; 55 pins were unchanged; packaging reported 427 payload
  files. Do not assert a fixed ZIP byte size after documentation changes.
  Current packages are holai.define, holai.runtime.<unit> and holai.<stem>, not
  holai.generated.*. There is no provider/load-order data or empty entry.
  Preserve ECL's native MP worker/join weak-GC regression: all 28 assertions and
  two explicit collections, without production cache changes.
  Prior hosted run [38661471081](https://github.com/tani/holai/actions/runs/38661471081)
  at ac56ca3 passed 12/12. The three-host/eight-candidate matrix has eight
  explicit ARM exclusions and 16 runnable jobs. Historical native run
  [38668191870](https://github.com/tani/holai/actions/runs/38668191870) at d3ac15b8
  passed 15/16; only CCL stale-consumer typed rejection failed with exit 255.
  Current native [run 38676192150](https://github.com/tani/holai/actions/runs/38676192150)
  at `3e1457d2df0efd4e8f8108d894392dd34fc7d54f` concluded SUCCESS, 16/16:
  all eight x86 Linux jobs and ABCL/SBCL/ECL/CLISP on each ARM64 host.
  Three SBCL jobs passed full release/core corpus and 52-unit cold audits;
  the other 13 passed bounded compatibility, not full core or optional HOL libraries.
  All eight require three native Lisp interrupt checks; three real OS SIGINT
  deliveries are required except ABCL, explicitly not applicable.
  Captured phase stdout/stderr and public GitHub Actions error annotations support
  precise diagnosis instead of blind retries. Earlier measurements above are history.
- Pre-repair native ARM64 Linux release passed in 286.76 seconds;
  SBCL reports 130 native/30 protocol/69 PROOF checks and 1,150 rows
  (1,147 exact + two structural registries + one Random property), with
  194,839 core / 207,095 fixture-inclusive maps, 52 cold units, 93 clean outputs
  and 55 pins. Its runtime/launcher fingerprints validate that historical source only.
  MKCL/CMUCL bounded passes and Clasp isolated passes under QEMU are emulated,
  never native x86 release evidence. Keep earlier 128/129 and 1,149 counts historical.
- Preserve the static matcher's compile-time descriptor / load-time ABI boundary
  and registry-independent execution; no source binding, algorithm or data change.
  CCL 1.13 can fold a direct conditional deferred LOAD-TIME-VALUE and drop its
  initializer: only #+ccl uses a standalone PROGN ABI check before the IF type test.
  The other seven implementations retain the original AND guard, since CLISP
  drops unused standalone PROGN load-time values. Keep typed stale rejection,
  the declaration name assertion and child exit 17 mandatory on every host.
  Full-system x86 Linux under ARM QEMU reproduced pre-fix exit 255 and post-fix
  45 pattern checks / Separate typed rejection marker 1, child exit 17, VM exit 0
  in 105.03 seconds: emulated evidence, not native hardware or full compatibility.
  Native ARM64 CLISP's bounded profile passed in 9.04 seconds with stale exit 17.
  Failure annotations keep escaped head and tail within 10,000 characters;
  an actual failing SBCL smoke preserved the root error. Never replace a failure
  with a pass based on diagnostic output or reuse pre-repair release fingerprints.
- Pinned Nix bin/ccl is a Bash non-exec wrapper. The real-SIGINT test must
  consume exactly one positive CCL `SIGINT target pid: N` marker, validate POSIX
  ps ancestry under Popen's wrapper, signal Lisp three times and wait for wrapper
  exit 0. Signalling only the wrapper missed Lisp and timed out with exit 143.
  Keep this test-only: other seven hosts retain Popen PID targeting and no
  production launcher/runtime change is needed. Kernel-emulated physical check
  passed in 46.23 seconds (wrapper79/Lisp80, three real signals, two Sys.Break
  catches, restored prior hook, wrapper/VM exit0), not native/full-profile proof.
- Current-code ARM64 four-host release passed in 278.84 seconds after matcher,
  interrupt-harness and logger changes: 130 native/30 protocol/69 PROOF,
  1,150 rows (1,147 exact/two structural/one property), 52 cold units with zero
  compiler diagnostics, 93 identical clean outputs and 55 unchanged pins.
  This is separate local SBCL full-core plus ECL/ABCL/CLISP bounded evidence.
  The subsequent native matrix above supplies repaired CCL and hosted 16/16 evidence.
  Documentation repackaging determines final archive bytes/payload count.
- Complete CCL bounded runtime/translated-fixture profile passed in 312.43s
  under a system-emulated x86 Linux kernel (_build/ccl-vm-run.sleh3T, VM exit0):
  patterns45/stale17 typed Separate/protocol30/OPTIONAL84/tuple16/Random1816,
  native interrupts3, real SIGINT3/two catches/prior restoration/wrapper0,
  three fixtures/33 exact OCaml rows/nine naming rows. This historical bounded
  emulated compatibility is not native hardware or full HOL core; native CI is above.
- Keep THEN and the literal source helper then1_ as separate bindings.
  The one-subgoal helper must reject multiple branches; do not merge it into
  the grammar-encoded tactical name. Preserve the branch-count regressions.
- Check lexical target symbols against all visible bindings, including source
  names differing only in case. Reserve names in parallel local function groups
  without extending nonrecursive RHS visibility. Preserve the R/r, K/k and
  DISJ_CASES regressions; do not globally change Lisp reader case conversion.
- Track local function symbols in package shadow declarations. Rename local
  functions that would hide generated control syntax using the existing suffix.
  Preserve local_cl_functions and local_syntax_function regressions.
- Emit guarded package shells/owned exports before imports, so a child can
  reference enclosing values without a package-declaration cycle. Intern earlier
  versioned symbols referenced by another package without exposing private
  constructors. Preserve the parent_capture and MESON module regressions.
- Preserve vendor/CORE_FILES.json load order and every vendor/SOURCES.json
  input digest. Full-core scan errors may cascade after a rejected dependency.
- Map.Make/Set.Make specialize original OCaml 4.14.1 whole declarations, with
  their original helpers: 15 Map and 18 Set public operations. Do not replace
  their balanced-tree algorithms. Keep both pinned sources and LGPL/linking
  exception notices. Retained Random provenance/licenses remain pinned inputs.
- Records use unambiguous label sets or explicit module qualifiers; retain each
  record's owner and emitted binding. General type-directed label resolution and
  module-signature record exports are outside the profile. Format has a tested box interface
  and bounded printf/fprintf/asprintf callbacks; it does not cover every directive
  or every OCaml layout edge case. Printf.printf/sprintf have a separate scalar
  profile (%s/%d/%b/%%/%!); their callback conventions are not aliases of Format.
- Let bool.ml perform its own binder/infix registration and logical initialization.
  Do not hide failures with manual fixture registration. Capture initial types,
  constants, definitions and axioms before test-only extensions. The corpus
  compares original logical proofs, hypotheses and conclusions, not stub results.
- Let class.ml add exactly its original ETA_AX and SELECT_AX, and trivia.ml
  introduce its original one type. Keep the HOL input trivia.ml distinct from
  the actual Lisp Trivia library. Initial registries must precede test extensions.
- Preserve actual inductive definition, canonicalization and MESON algorithms.
  Compare rules/induction/cases/strong induction and reconstructed theorems;
  do not replace original search, modify recursion or assume missing results.
  Negative MESON cases have an explicit small bound (currently 2). Restore all
  source search settings, including dcutin, even when focused cases fail.
  Bound-name normalization is confined to the explicitly reported observation
  cases; free names/types and full term/statement structure remain observable.
- Preserve actual METIS, leanCoP/nanoCoP, quotient construction/lifting and
  implicational rewriting. Use finite saturation/streams or depth 2 for failing
  connection search. Default nanoCoP function-congruence search exceeds the
  retained timeout in original OCaml too; keep the bounded corpus disclosed.
  Never patch search algorithms, raise timeouts casually, or assume a proof.
- Static functors capture their definition-time environment; named argument
  module applications create distinct instances and aliases reuse identities.
  Local module values must initialize inside the source lexical scope at the
  declaration point, even if their closures escape. Do not hoist captured values.
  Local type metadata in a global child module belongs to that child package;
  only lexical children propagate metadata to their enclosing lexical owner.
- Preserve leading-let recursive closure initialization with source-named slots.
  Mixed named recursive groups also admit initializers with no resolved reference
  to their group. Check binding identities through shared nested-module reference
  observers, compose nested guards and restore on errors. Inner shadowing is
  distinct; cyclic data and hidden same-group dependencies must reject. Keep
  mixed lexical-module bindings/calls in value slots. Global recursive values
  receive a CL special declaration before their group, without moving initializers
  or declaring lexical slots special. Preserve once-only/capture regressions.
  Only actual source loops become loops. Lazy forcing caches values and OCaml
  exceptions. Required labels use retained binding metadata; optional parameters
  and unresolved higher-order labelled calls must reject without writing output.
- The 0.7 checkpoint adds unchanged pair/compute/nums/recursion to the previous
  24-file release. Preserve product/CBV/numeral/recursive-definition algorithms and
  let nums add its actual INFINITY_AX. Snapshot all three source axioms and the
  original ind/num/prod types before test extensions; do not assume new results.
- The 0.8 checkpoint adds unchanged arith.ml, with its actual seventeen added
  definitions/constants and no added axiom. Preserve arithmetic proofs and
  MOD_DOWN_CONV/NUM_CANCEL_CONV/BITS_ELIM_CONV algorithms. Keep the 44 arithmetic
  observations' literal names and require closed expected conversion equations.
  The 1.0 completion includes wf.ml, calc_num.ml and all later manifest files.
- Reference-record contents uses the existing ref cell and a structural
  pattern. Field access is independent of a rebound !. Copy/update allocates a
  fresh cell. Ambiguous unqualified contents patterns/literals must reject.
- Sibling root record labels may uniquely select a partial record pattern.
  Constructor metadata retains visible predecessors and declared variant
  families; sibling root/tuple case evidence may select an earlier constructor.
  Qualified constructor names stay exact. Known non-tuple single payloads cannot
  absorb multiple-field patterns. Unknown transparent aliases retain tuple
  adaptation. Pattern hints never change expression bindings or case order.
  Prune private constructor lineage at signatures; open/include may attach
  only previously visible caller bindings. Preserve hidden-history rejection.
- Hashtbl.fold visits shadowed associations; remove deletes only the newest
  matching binding. Iteration order is unspecified; canonicalize only the
  order-independent test inventory, not source evaluator operations or proofs.
  Array.fold_left preserves left-to-right element callbacks.
- Compute's original bool_compset leaves LET_END residuals; test that boundary
  and explicit rule extension. Restricted evaluation still reduces arguments.
  Compare benign recursive/specification warnings as actual output lines.
  product_beta and recursive_exists serialize bound names only; this does not
  alter the input parser, generated theorem, free names or kernel algorithm.
- Honor the lexical binding of prefix ! despite Camlp5's reference-field AST.
  Keep the source recursive-operator regression and real impconv proof cases.
  Reserve prior imports in local symbol allocation; qualify conflicting later
  foreign references. Shadow generated makers and protect the CL constant PI.
  CL-qualify synthetic cons/vector/and/or. Distinguish boolean source tokens
  from declared True/False variants, retaining their original constructor tags.
- Random.init ignores its integer seed and replaces a private standard CL
  random-state with MAKE-RANDOM-STATE T; bits/int use CL:RANDOM with that state.
  Integer seed replay is not guaranteed. Validate explicit-state advancement,
  snapshot replay and result bounds; do not assume host-internal entropy or
  default-state behavior. Shifts use signed 63-bit ints, counts
  0..63; zero logical shift retains the signed operand.
  General machine-int overflow and full OCaml library coverage remain outside.
- Preserve the actual tactic and justification algorithms, including goal-stack
  mutation, rotation, undo and top_thm. Do not substitute a different prover or
  insert assumed theorems to make initialization/search succeed.
- Capture initialization and observation streams separately. Keep the raw
  5,519 OCaml / 5,517 SBCL initialization rows. Normalize numeric CPU durations
  only for message comparison. Accept exact equality or the documented two
  OCaml-only occurrences in iterate.ml (inventing type variables; solved at 2);
  reject every other message difference. Report message/raw equality as false
  for this measured profile. Goal/theorem/output observations must match exactly
  under the enumerated observer rules. Keep the existing std_formatter identity
  when redirecting output, because source closures capture it.
- Forty selected observations serialize bound names by binding index. The user
  selected generated-name-only structural comparison for `init_constants` and
  `init_definitions`, not Random record/replay or a different engine. Preserve
  existing ?decimal schematic type normalization and PCROSS/iterate binder rules.
  A pinned-source guard must reject authored positive `_decimal` names before
  provenance classification. Use one shared generated-constant identity map
  across both registry rows, with a distinct serialization tag; normalize
  positive `_decimal` variables only at actual binders via de Bruijn indices.
  Preserve authored `_0`, free variables, explicit/unknown constant names, order,
  multiplicity, concrete types, sharing and complete term/theorem structure.
  These observer-only rules never rewrite source, runtime or stored proofs.
  Keep raw/canonical hashes and separate exact/property/structural row counts.
- Full native/oracle core processes use a measured 600-second guard and a
  256 MiB SBCL control stack. Keep ordinary compiler/rejection/isolated-adapter
  processes at 120 seconds and negative proof-search bounds at their explicit
  small values. Document measured evidence before altering those boundaries.
  Explicit user-authorized exception: optional ECL/ABCL/CLISP full-core native
  and cold-diagnostic commands retain 3600 seconds, following the measured
  timeouts/progress in DESIGN §38. Ordinary additional-host matrix profiles now
  run runtime/translated-fixture compatibility at 120 seconds per process.
  SBCL and original OCaml retain 600 seconds; negative bounds are unchanged.
  Report actual profiles/guards; compatibility never means full-core verified.
- In the 1.0 baseline, synthetic lambdas use CL:LAMBDA, including lazy thunks; preserve actual source
  values/functions named lambda. Retain both namespace regression cases.
- Scope.reference caches only the immutable exact owned-symbol/maker spellings;
  changing local symbols and reference observers remain separate. Changes to
  this cache must preserve every generated byte unless the user explicitly
  requests a naming change; then regenerate and run full collision/scope checks.
- Array.of_list/map allocate fresh vectors, retaining identities/order; map
  invokes callbacks left-to-right. Num quotient/remainder use Euclidean division
  for negative divisors/rational operands. int_of_num preserves noninteger and
  signed-63-bit overflow Failure boundaries. Gc get/set retain logical snapshot
  semantics; stack capacity is a launcher setting, not an active native resize.
  Verify native Lisp interrupt catch/re-enable/exact previous-hook restoration
  on every selected host. Keep real OS-SIGINT evidence separate; ABCL reports
  it not applicable, not passed. Do not add Java/OS signal rewiring, SIG_DFL,
  or forced-process-death success. Cleanup kills preserve failure/timeout status.
- Heap checkpoints are scratch-only development aids. Every release must verify
  full initialization from SBCL and original OCaml, plus every selected
  additional host's bounded runtime/translated-fixture compatibility profile.
- Run `make release` for delivery; it includes all tests and inventory. After
  documentation-only changes, repackage against the validated reports without
  repeating a full initialization unless a new unresolved concern justifies it.
  Include raw observation streams and reproducible canonical comparison streams
  in the package; keep parsed/lowered/compiled/differential-corpus states distinct.
- Use the single NixOS 26.05 pin in flake.lock for current development/release.
  Preserve the OCaml 4.14/Camlp5 8.02 grammar contract and explicit Camlp5/Num
  source overrides, not an old distribution input. Run release inside the
  pinned shell: host versions and executable bindings must match its exported
  metadata. All eight candidate adapters participate when pinned packages are
  usable; retain genuine platform/broken/evaluation exclusions and require SBCL.
  Current selection is eight x86 Linux plus four on each ARM64 host; CMUCL uses
  the pinned i686 binary. CI excludes exactly eight unavailable ARM cells and
  fails missing actual targets rather than skipping. SBCL alone runs full release;
  other selected hosts run 120-second runtime/translated-fixture compatibility.
  Keep prior measured results historical; never claim native/platform correctness
  from package evaluation, cached binary fetching or emulated execution.
  The current expanded 16/16 native pass is recorded above; exclusions are not passes.
  ASDF checks cover startup only. Supply the real pinned ASDF source for hosts
  without bundled ASDF; never fake the package or add inferred systems/load files.
- `make test` needs Camlp5 8.02, OCaml Num for the original-execution oracle,
  all selected pinned native hosts (and ECL's C compiler); production runtime has no external pattern-library dependency.
- Do not publish or push anywhere unless the user requests that destination.
- Further agents should work independently only if the user explicitly asks
  for delegation. This file does not request multi-agent work.


## Current implementation and repository policy

- Keep README.md tidy, simple and concise: overview, setup, basic usage and
  testing only. Put detailed design, counts, benchmarks and history in existing
  DESIGN/docs/reports; do not duplicate inventories in the README.
- Production variant: 1.0.0-percent-names. Shared OPTIONAL/supplied-p entries
  across defunc/lambdac/labelsc/fletc; no fixed worker, callc or call-site routing.
  Keep NIL-vs-omitted, primary return, body-once, partial/excess, old-function
  capture and fletc outer-RHS scope. Standard bare `funcall` replaces the removed
  runtime wrapper; list tuples remain unchanged. Do not restore its API or alias.
  Historical OPTIONAL checkpoint: 122 native, 27 protocol, 84 OPTIONAL,
  16 tuple checks;1124 matching rows and94 identical clean-generated files.
- Two-run ABBA startup medians 97.840→81.957s; cumulative allocation50.95% lower,
  peakRSS16.67% higher. OCamlopt13.715s is a separate historical measurement.
  Never equate cumulative allocation with peak RSS or promise a universal speedup.
- Read docs/REPOSITORY-LAYOUT.md. Track generated Lisp and inventory, but not
  generated source maps, _build, bin, dist, compiled code or Python caches.
  make regenerate recreates maps; source ZIPs include all 93 generated outputs
  (46 Lisp/map pairs plus inventory) and the hand-maintained root ASD.
- Historical reports are under misc/reports/history/. Keep current evidence separate
  and update paths when moving files. Keep all vendor digests and licenses.
- Current layout/API contract: CLI `bin/ml2cl`, dot-separated packages
  `holai.runtime.<unit>` and `holai.<stem>` (static children also use dots);
  ordinary serial systems `holai` and `holai/runtime`, both defined explicitly
  in root `holai.asd`. No compatibility aliases or inferred per-source systems.
  Regenerate rather than hand-edit outputs. DESIGN37 specifies handwritten
  load order, reader-owner imports/shadows and CL-first safe UIOP mix rules.
- User authorized initial organization and push to tani/holai main. Subsequent
  unrelated publication requires its own user instruction.

- User authorizes star-suffix naming implementation and push to tani/holai main
  (DESIGN29). Source identifiers must be safe unescaped reader atoms. Preserve
  binding IDs, source spelling in maps, constructor makers and package imports.
  Prefer lowercase owned names; append stars for uppercase logical collisions.
  Prime/reserved-name atom encoding must also be consistent for record fields.
  Do not change readtable-case, HOL string literals or runtime algorithms.

- Naming inherited from 1.0.0-star-names: ordinary CL reader atoms, star suffixes
  for primes/reserved stems/collisions. Reader case conversion stays unchanged;
  the authorized DESIGN33 dispatch extension does not affect foreign names or
  HOL strings, which stay native/original. Public source symbol spellings change.
  19allocator checks,9additional OCaml/SBCL observations,9export checks and no
  escaped symbols in46core files. Full1124-row corpus and94clean outputs pass.
  Earlier OPTIONAL performance measurements are historical after this rename.

- DESIGN30 authorizes replacing Trivia with static structural matching. Keep
  data representations unchanged; validate OR joins, guard once/next-clause
  semantics and descriptor compile/load visibility. Rebuild dependent FASLs
  after declaration ABI changes. Historical benchmark baselines are separate.

- Structural backend validated on all46 unchanged inputs,122native checks,
  1124 differential rows and94 clean regenerated files. Additional46 pattern
  checks cover OR/guard, literals, stale FASL detection and registry-independent
  execution, plus wide/deep patterns. Production holai/runtime, ml2cl and holai/generated contain
  no Trivia references. Historical Lisp dependencies and licenses are available in the baseline Git revision.

- Final structural-backend single-run comparison: compile operations33.857→
  24.181s; cold compile/load peakRSS1822.102→1079.875MiB; fresh startup80.927→
  82.044s, peakRSS239.762→205.594MiB. Allocation effectively unchanged. Cold
  RSS includes initialization; do not call it compile-only. Startup speedup is
  not demonstrated. See misc/reports/PATTERN-MATCH.md and its one-run limitations.

- DESIGN31: user authorizes replacing translator-added stars with percent
  suffixes and adding IGNORABLE at curried parameter/input binding sites.
  Preserve literal/operator stars, native special names, source scopes and
  algorithm behavior. Regenerate all naming references/keywords/makers; do not
  mute warnings globally or convert lexical bindings into special variables.

- Percent naming validated:21 allocator/native-target checks,9 naming rows,
  full46-file/1124-row corpus and94 clean outputs. Fresh-cache production audit
  compiles51units with0 errors,0 warnings and0 style warnings. make release
  requires that audit and checks the compiled source fingerprints. Historical
  percent-predecessor timing data do not describe the new naming variant.

- User explicitly authorizes pushing the structural-match and percent-naming
  implementation together to tani/holai main after successful validation.

- DESIGN32: obsolete vendor/lisp may be deleted; its historical revisions and
  licenses are available in commit1730c0299f7d677ba25be29d2dfbff0538fea354.
  Preserve all remaining pinned HOL/OCaml files byte-for-byte. Current scripts
  must not search removed vendor directories or imply external Lisp dependencies.

- Vendor cleanup validated with vendor/lisp absent: full46-file/1124-row
  corpus,51 production files with zero diagnostics,94 clean outputs and55
  unchanged retained input hashes. vendor/README.md explains each retained item.
  Continue the same repository-maintenance task on the previously requested main.

- DESIGN33 PROOF recognition applies only to canonical new globals in
  holai/generated/tactics/tactics.ml, without lexical prefix, at source-name occurrence1:
  then_/Value, thenl_/Value, orelse_/Function3. Binding reuse retains tagging;
  new aliases/shadowing do not. Only exact two-argument unlabelled applications
  qualify. Synthetic heads follow DESIGN37's completed-reader-owner policy below,
  never eager PROOF import/reservation or source renaming; then1_ stays separate.
  Left folding/right inner PROOF preserve the binary call tree; branch lists, justification and kernel
  operations are unchanged.
- Preceding reader-inclusive PROOF release validated with `nix develop path:. --command make release`:
  46 inputs,122 existing native,61 independent PROOF,46 pattern,27 protocol,
  84 OPTIONAL,16 tuple checks;1132 matching rows(1125 serialized,7 side effects).
  Initial registries22/303/263/3 and exact3source axioms unchanged;5519 OCaml/
  5517 SBCL initialization rows retain the exact2known OCaml-only differences.
  Audited194839 core/205472 inclusive maps;10 rejections keep output;94 clean
  outputs identical,55 pins unchanged,51units zero errors/warnings/style warnings.
  Native PROOF counter runs after capture/std_formatter restoration, isolated
  from observations. Fresh sharp-backquote handwritten smoke proved the actual
  closed identity theorem. Package retains newunit/translator/design/maps/reports/streams.
  Keep1.0.0-percent-names; no PROOF timing or publication claim. Earlier
  baseline measurements above remain historical.
- Explicitly authorized DESIGN33 reader: runtime sharp-backquote-lambda-reader
  installs #` in the active *readtable* at compile/load/execute time. Load runtime
  before reading consumers; copies inherit dispatch, fresh standard readtables
  from NIL do not. Never redefine standard #' or change readtable-case/source
  atoms. #' references named functions; #` wraps a value/expression in CL:LAMBDA
  using a gensym rest variable and CL:APPLY. Evaluate the expression each call,
  not at construction; preserve all arguments and multiple values. It is a
  PROOF operand, not a direct operator form; bind it to a value symbol for an
  operator. Keep PROOF grammar and tactical emission unchanged; generated value
  application now follows DESIGN34 below.
  Runtime-only compile/load smoke passed. Completed reader-inclusive release
  measured61 PROOF checks, including13 permanent reader checks with actual
  zeroarg sum, positional decimal calculation, NIL classification, floor
  quotient/remainder and lexicalargs hygiene computations, not mock echoes.
  Differential1132/maps205472/production51 inventories are unaffected.
- DESIGN34 reader-headed value calls: compiler.call_value and translator-added
  value forwarding emit (#`<structural-head> args...), including computed heads
  and foreign excess-result application. Keep direct named Function calls,
  #' references and foreign partial adapters intact. Do not wrap eager plain
  function values passed as arguments or captured in bindings.
  Arguments evaluate left-to-right before the reader lambda acquires its
  function expression once per invocation. This late-head timing is intentional;
  do not introduce order temporaries, ANF, source rewrites or optimizations.
  Runtime must install dispatch before generated consumers are read.
  Use Sexp.ReaderPrefix/reader_prefix, preserving Origin spans and prefix width;
  no text postprocessing. Fragment remains PROOF-only. The later standard
  FUNCALL cutover removes the runtime wrapper without changing reader timing.
  Eight added native consumer checks give measured69 PROOF checks; one new
  tactical computed-head row supplements existing partial/excess coverage.
  Keep the marker isolated after observation capture/std_formatter restoration
  and retain11 fixture/51 production components. Combined DESIGN34/35 release
  succeeded; earlier measurements above remain historical.
- DESIGN36 plain local named-function groups supersede DESIGN35's historical
  display. Emit every generated local function group, isolated or adjacent,
  nonrecursive or recursive, as ordinary labelsc (name (params) body) entries.
  Combine adjacent source groups into one genuine CL:LABELS scope; no mode
  keywords/group numbers, decoder, reconstructed nesting or compatibility shim.
  Handwritten fletc retains its ordinary nonrecursive outer-RHS API.
  Allocate unique normalized function targets across the whole combined chain,
  including earlier names hidden by shadows and case collisions. Reserve all
  visible target logicals at chain entry until chain exit, plus every allocated
  member. A later binding must not capture an earlier RHS's outer reference.
  Use scoped allocator reservations, never fake source environment bindings;
  apply the existing local percent suffix allocator without changing source
  spellings or binding IDs. Lower in source order with original RHS environments:
  preceding env for nonrecursive/parallel RHSs, own recursive group for rec RHSs.
  Never give earlier RHSs the union of the combined chain's source bindings.
  Scalar LET values/modules/match/lambda/annotations are barriers. Preserve
  lowering, binder/reference/import order, recursive observers and source IDs;
  retain all let Origins with coincident spans and all function/body Origins.
  Keep once-only initialization, captures, partials and physical function identity.
  No dispatcher, new initialization, algorithm or evaluation-order rewrite.
  DESIGN34's late reader-head acquisition is separate and unchanged; retain
  direct named calls, standard #' references and foreign partial adapters.
  Runtime-first compile/load still supplies the reader and ordinary macros.
  Plain entries keep name/params together when they fit90 columns, body next.
  Final module-inclusive DESIGN36 release succeeded218.79s via
  nix develop path:. --command make release with OCaml4.14.2/Camlp5 8.02.01/
  SBCL2.3.9.nixos:46inputs/122native/69PROOF/27protocol/84OPTIONAL/16tuple/
  46pattern;1142matching rows(1135serialized+7actual side effects).
  Existing six language-group observations remain unchanged; the three new
  entry-reservation/repeated-shadow, case-sensitive hidden-shadow and
  module-scope rows matched. Audited194839core/206245inclusive maps;
  10rejections preserved output;51fresh units zero errors/warnings/style warnings;
  94clean outputs identical,55pins unchanged,304release ZIP members verified.
  Initial22/303/263/3, original3axioms and5519OCaml/5517SBCL initialization rows
  with known2OCaml-only message differences remain unchanged. Generated core
  5727348bytes after final header formatting is an inventory, not a performance
  claim. DESIGN33/34/35 measurements and staged metadata examples remain
  historical, not the current API or evidence for this cutover.
  This was the preceding checkpoint's satisfied release gate and publication
  authorization, not authorization or validation of the new DESIGN37 cutover.
- DESIGN36 lexical-module named function declarations also use ordinary LABELSC.
  Only immediately adjacent named declarations inside one structure combine;
  module declarations/aliases/includes, value or mixed slots, effects and the
  external continuation remain barriers, even when an alias has no runtime
  output. The module combiner peels only local-module-binding Origins. RHS
  environment snapshots and original right-fold wrapper compilation order stay
  unchanged. Lexical global allocation reserves entry-visible names, including
  qualified module public exports, and previously allocated targets; percent
  collision suffixes avoid future ordinary prefixed/versioned names. Alias
  public environments are visited once; functor captured environments are not
  traversed. Top-level global allocation is unchanged. This prevents a new
  local module M.f from capturing a resolved reference to an older M.f.
  No generated FLETC calls remain; handwritten FLETC is retained. Plain local
  definition headers keep name/parameter list together when it fits90 columns,
  using a context-specific renderer without stage markers.
  One added language_module_function_scope observation exercises escaped
  closures/partials, repeated module names, sequential and parallel dependencies,
  case shadowing, imports, aliases and once-only initialization. Together with
  entry/case rows this gives three new matched rows and measured1142 total.
  Separate fresh-core smoke proved an actual closed identity, passed69PROOF/
  8ordinary function-scope cases and ran the escaped/rebound module closure/
  partial and once-only initialization case twice with exact expected results.
  Static search found zero generated FLETC calls or stage tags.
  Validation and authorization are not evidence of publication.

## Explicit ASDF/UIOP load order (DESIGN37)

- Keep exactly one root holai.asd with handwritten serial component lists.
  holai/runtime loads data, pattern-registry, pattern, core, format, stdlib;
  holai depends on it and loads the original 46 generated files in vendor order.
  Runtime-only callers load holai/runtime. Register only the repository root.
  Require ASDF before reading UIOP declarations in runtime-only scripts.
- Do not infer systems from package names or generate an ASD from a manifest.
  No provider registry or S-expression load-order data remains. Packages use
  dots independently of filesystem paths/system IDs. Guarded same-file package
  shells still precede complete declarations for reader availability.
- Preserve resolved binding identity, observers, source maps, private makers and
  canonical imports. Lexical module forms use enclosing reader-owner imports
  and shadow allocation. Shadow ordinary lexical values as well as functions
  so mixed foreign SPECIAL exports cannot alter lexical scope. CL is first in
  safe foreign-input mixes; no broad same-file use or new public exports.
- Apply readability policy to the software's generated and maintained handwritten
  development code, not merely end-user API examples. Synthetic PROOF heads use a
  deferred cell per actual reader owner, finalized after complete structure
  lowering and before dependencies/package declarations/rendering. Safe owners
  explicitly import runtime PROOF and emit bare proof; source-owned/local names,
  distinct foreign PROOF imports or maker shadows retain holai.runtime.core:proof.
  Lexical modules share the enclosing owner; static child packages decide
  separately. Never reserve/import PROOF during lowering or rename source proof
  to shorten the macro head. Retain Fragment layout, Origin spans and source IDs.
  Ordinary handwritten tests explicitly import the macro; the separate CL-only
  source-function collision regression intentionally retains qualification.
- Audit actual ASDF compile/load operations for 52 unique physical paths:
  runtime data/pattern-registry/pattern/core/format/stdlib, then 46 generated
  sources in vendor manifest order. Require zero compiler diagnostics; report
  load/initialization diagnostics separately. Fingerprint root ASD and every
  production source/translator; no entry or provider-data fingerprint remains.
  Regeneration/clean comparisons cover 93 Lisp/map/inventory outputs only.
- Current explicit-order/dotted-package changes await regeneration and parent
  release verification. Earlier constructor/private/parent-capture/collision
  regressions and inferred-loading smokes remain historical evidence only.
  Report counters and differential/map totals from actual reports; historical
  baseline names and raw evidence stay unchanged.
- The safe-bare extension passed 129 native/69 PROOF checks and 1,149 matching
  rows, including all six proof_reader_* real-theorem observations: safe child,
  late local/global, foreign import, case and lexical module. Native reader-symbol
  identity/no-PROOF% assertions passed. A separate fresh smoke exited 0 in
  72.41 seconds using an explicitly importing development package and bare
  proof/tactic/runtime/kernel names to prove the actual closed p ==> p theorem
  with its independently parsed expected conclusion.
- The historical safe-bare archive has 306 members (305 payload plus manifest), only one ASD,
  entry/provider data and 92 generated Lisp/map members. Core Lisp totals
  5,942,245 bytes; static generated inventory has 2,353 bare PROOF heads and
  25 qualified collision heads. These inventories are not performance evidence.
  The release retained 55 input hashes and 94 identical clean-generated outputs;
  initial registries remain 22/303/263/3 with exactly three source axioms.
  The 5,519 OCaml/5,517 SBCL initialization rows retain the two known OCaml-only
  messages. Prior cutover measurements remain historical in DESIGN37.3.
- The previous unified ASDF/UIOP cutover was separately authorized and pushed as
  36f3a78. The user now explicitly authorizes committing and pushing this verified
  safe-bare extension and tidy README rewrite to tani/holai main. The parent owns
  repackaging, review, commit and push; authorization is not evidence they occurred.

## Supported host portability (DESIGN38)

- Current correctness/release tooling uses `misc/scripts/lisp_host.py` and
  `run-lisp.sh`; no obsolete SBCL launcher alias. Select any explicit candidate
  ID using `HOLAI_LISP`, with optional uppercase `HOLAI_<ID>` executable paths.
  Native arguments are implementation-specific, not textual substitution.
- Require ASDF in its own evaluated form before reading any ASDF/UIOP symbols.
  Use actual UIOP environment/process/quit APIs where supplied; unsupported
  signal and weak-storage capabilities must fail, never fake success.
- Use standard CL Random state, not OCaml seeded replay or a custom generator.
  Validate only the literal language_random= row's shape/bounds before replacing
  it for comparison; every other row stays exact. Keep original source pins and
  licenses. Adapters preserve real weak retention, live identity and SIGINT.
- `make release` must exercise SBCL's complete 46-file/native/PROOF/oracle
  profile and cold 52-path explicit-manifest-order diagnostics. Every selected
  additional host must pass `runtime-fixtures` compatibility with independent
  counts/source fingerprints/log digests and 120 seconds per process; never
  label it full-core verified or require its full-core streams/cold diagnostics.
  `make test-full-core` explicitly opts selected hosts into complete tests/cold
  diagnostics, retaining ECL/ABCL/CLISP's approved 3600-second full-core guard.
  Keep SBCL/original OCaml 600-second guards, ordinary 120-second guards,
  negative proof bounds, native capacities and recorded OS stack constraints.
  Retain compiled NaN/EQL tests using actual APIs and exact trap restoration.
  CLISP cannot represent NaN; ECL cannot externalize a compiled NaN literal:
  both report that case not applicable (45 structural checks), never passed.
  SBCL/ABCL retain 46.
  Require three direct-native interrupt checks on every selected host: two
  Sys.Break catches across re-enable and exact previous-hook restoration.
  Keep actual OS-SIGINT evidence separate: two catches and restored prior-hook
  delivery with exit 0 where supported; ABCL reports OS not applicable with zero
  deliveries, never passed, while its native Lisp thread checks remain mandatory.
  Use SBCL's public SB-EXT:*INVOKE-DEBUGGER-HOOK*
  (only INTERACTIVE-INTERRUPT becomes Sys.Break; forward unrelated conditions),
  ECL's pre-debugger SI:TERMINAL-INTERRUPT function entry with exact restoration
  and MP:INTERRUPT-PROCESS forwarding to the enabling process, ABCL's native Lisp
  thread-interruption hook and CLISP's ANSI CLOS global-handler methods.
  Clasp preserves/restores the exact primary MP:SERVICE-INTERRUPT method
  specialized CORE:SIGINT; do not mutate CORE:TERMINAL-INTERRUPT or unlock packages.
  Do not reintroduce Java Signal, libc/LibSystem signal FFI, signal-mask
  manipulation, ECL's broken GET-SIGNAL-HANDLER getter or late debugger-hook
  conversion, CLISP build overrides, SIG_DFL or forced-death success.
- Current evidence is under `misc/reports/implementations/<id>/`; matrix selection,
  explicit profiles and actual per-phase status are in implementation-matrix.json.
  Package availability never implies compatibility; every selected profile's
  failures gate packaging. Require exact implementation/version identities and
  current source coverage/log digests. Only SBCL requires full verification,
  diagnostics and streams; extras require compatibility.json and matching
  compatibility/ logs. Optional full-core evidence has a separate aggregate;
  preserve incomplete/timeout attempts without relabelling them.
  Old root SBCL raw baselines and historical benchmarks retain their identity.
  Release checks 93 clean outputs, 55 pins and SBCL/original OCaml's
  registries/axioms and exact initialization exceptions.
- Historical measured profiles passed: SBCL full core (128 native, 69 PROOF;
  1,149 rows = 1,146 exact + two structural registries + one Random property)
  and ECL/ABCL/CLISP runtime fixtures (28 protocol, 84 OPTIONAL, 16 tuple-list,
  1,816 Random; 45/46/45 structural checks; three fixtures and 33 exact rows).
  Preserve those historical source fingerprints and digest-matched logs. Each extra-host
  SIGINT test delivered three signals, caught two and restored default exit -2.
  SBCL cold diagnostics passed 52 paths/47 inferred components with zero compiler
  diagnostics, separately recording 21 load/initialization style warnings and
  164 notices. Those maps total 194,839 core / 207,058 fixture-inclusive.
  The earlier inventory failure was superseded by the completed split-profile
  release. The current dotted-package/explicit-ASDF candidate still requires a
  fresh parent release; none of those historical results verifies this cutover.

## Optional user proof language (DESIGN39)

- The user authorizes `holai.user` with nickname `holai-user`, maintained in
  `holai/user/`, and ordinary `holai/user` / `holai/user/tests` systems in the
  existing root ASD. Preserve core/runtime ordering and runtime-only loading.
- Use the generated preterm inference, overload resolution and checked `prove`;
  do not duplicate the type checker or add axioms to implement DSL commands.
  Keep literal term/proof syntax independent of host Lisp evaluation.
- Run `make test-user` for this layer. Native integration runs after all original
  observations and registry checks; retain separate user counts/fingerprints.
  DSL compilation is separate from the existing 52-unit core cold audit.
- Focused SBCL 2.2.9 evidence: 102 DSL and 69 existing PROOF/reader checks passed;
  compiled example executed and new sources had zero compiler warnings.
  Five macro redefinition conditions occurred during load, recorded separately.
  This is not a pinned Nix release or a new other-host portability measurement.
- DESIGN39.2 adds the fourth optional unit `definitions.lisp`: `definductive`,
  `defrecursive`, `defdatatype`, registered generated principles, `induct` and
  `asm-arith`. Relations require closed existence/monotonicity evidence before
  introducing constants. Never register residual hypotheses as completed results.
  Identical successful relation/function source forms may reuse their recorded
  theorem; invalid declarations must not overwrite a registered theorem bundle.
- Extended focused SBCL 2.2.9 checks passed: 102 existing user checks plus 53
  definition checks from a fresh complete core, and 69 original PROOF checks.
  Four user units, two test units and the compiled example had zero compiler
  warnings; eight macro redefinition conditions were recorded during load.
  The definition suite also passed twice in one process. Full pinned release,
  original differential/regeneration audits and extra-host validation were not rerun.


### Current user language increment (specification v0.3)

- The user authorized implementation after v0.3; the design snapshot is in
  `docs/USER-DSL-SPEC.html`. Keep its full target distinct from the implemented
  subset in `docs/USER-DSL.md` and DESIGN39.3.
- Preserve symbol/package identity, source-package capture, ?a variables,
  DECLARE/THE, explicit lambda lists and `(field type)` datatype/record syntax.
  Use CL:DEFUN for host helpers; never redefine CL's standard symbols.
- Keep inference and proofs in the generated procedures. Numeral/NIL elaboration
  must use the inferred type and same-typed kernel substitution. Unresolved NIL,
  invalid numeric types, unbound names and open proof obligations must fail.
- COMPILE-FILE must not introduce kernel types/constants. Preserve source/FASL
  loading, same-definition reuse, gensym canonicalization and conflict rejection.
  A potentially partial backend failure must not be described as rolled back.
- Preserve constructor coverage and independent wildcard variables, checked
  correspondence of named rules/equations, package independence, parameter
  order and absence of new axioms. Run `make test-user` after changes.
- Current focused SBCL evidence is 82 language checks, 68 definition checks,
  and 69 independent PROOF/reader checks. Four user units, two tests and the
  example compile with zero compiler warnings/errors; 15 macro redefinition
  load conditions are separate. This is not full v0.3/release/other-host evidence.
