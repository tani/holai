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
- Current 1.0.0 baseline: all 46 unchanged vendor/CORE_FILES.json inputs,
  including system.ml and every theory through define.ml, parse/lower/compile/
  initialize in original order. 122 independent SBCL checks and 1,124 matching
  output lines (1,117 serialized, three print lines, two benign warnings and
  two actual Groebner progress lines). Maps: 194,839 core / 205,341 with eleven
  fixtures. Ten rejection checks preserve existing output; all 94 generated
  files regenerate identically, including a translator built in a clean directory.
  Initial types/constants/definitions/axioms: 22/303/263/3. Initial inductive
  definitions: 3; rewrite/conversion/congruence/monotonicity lists: 34/5/8/9.
  Source axioms are exactly INFINITY_AX/SELECT_AX/ETA_AX; the primitive-kernel
  fixture explicitly adds one test-only witness axiom after the initial snapshot.
  All standard-manifest TODOs are complete. Generic OCaml/library completeness
  and optional HOL Light libraries outside the manifest remain outside the profile.
  Update factual counts from reports when implementation or corpus changes.
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
  exception notices. The runtime Random section also retains that license.
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
- Keep seeded Random.init/bits/int equivalent to pinned OCaml 4.14.1 raw-byte
  MD5/lagged-Fibonacci code; UTF-8 encoding changes the seed sequence. Shifts use
  signed 63-bit ints, counts 0..63; zero logical shift retains the signed operand.
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
- Forty selected observations serialize bound names by binding index; two
  initial registry rows normalize generated ?decimal schematic type variables
  by first structural occurrence per scheme; the definition row also normalizes
  generated GEN%PVAR%decimal binders in PCROSS/iterate. Preserve sharing, explicit
  names, all free names, concrete types and full term/theorem structure. These
  rules are observer-only and must never rewrite source, stored proofs or output.
- Full native/oracle core processes use a measured 600-second guard and a
  256 MiB SBCL control stack. Keep ordinary compiler/rejection/isolated-adapter
  processes at 120 seconds and negative proof-search bounds at their explicit
  small values. Document measured evidence before altering those boundaries.
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
  Verify the actual SIGINT-to-Sys.Break adapter in its own SBCL process.
- Heap checkpoints are scratch-only development aids. Every release must verify
  full initialization from fresh SBCL and original OCaml processes.
- Run `make release` for delivery; it includes all tests and inventory. After
  documentation-only changes, repackage against the validated reports without
  repeating a full initialization unless a new unresolved concern justifies it.
  Include reports and matching observation streams in the package; keep
  parsed/lowered/compiled/differential-corpus states distinct.
- `make test` needs Camlp5 8.02, OCaml Num for the original-execution oracle,
  SBCL; production runtime has no external pattern-library dependency.
- Do not publish or push anywhere unless the user requests that destination.
- Further agents should work independently only if the user explicitly asks
  for delegation. This file does not request multi-agent work.


## Current implementation and repository policy

- Production variant: 1.0.0-percent-names. Shared OPTIONAL/supplied-p entries
  across defunc/lambdac/labelsc/fletc; no fixed worker, callc or call-site routing.
  Keep NIL-vs-omitted, primary return, body-once, partial/excess, old-function
  capture and fletc outer-RHS scope. rt:funcall and list tuples remain unchanged.
  Historical OPTIONAL checkpoint: 122 native, 27 protocol, 84 OPTIONAL,
  16 tuple checks;1124 matching rows and94 identical clean-generated files.
- Two-run ABBA startup medians 97.840→81.957s; cumulative allocation50.95% lower,
  peakRSS16.67% higher. OCamlopt13.715s is a separate historical measurement.
  Never equate cumulative allocation with peak RSS or promise a universal speedup.
- Read docs/REPOSITORY-LAYOUT.md. Track generated Lisp/inventory/ASDF, but not
  generated source maps, _build, bin, dist, compiled code or Python caches.
  make regenerate recreates maps; every source ZIP must include all94outputs.
- Historical reports are under misc/reports/history/. Keep current evidence separate
  and update paths when moving files. Keep all vendor digests and licenses.
- Current layout/API contract: CLI `bin/ml2cl`, packages `holai.*`, systems
  `holai-runtime`/`holai-generated`. This user-authorized cutover supersedes the earlier retain-hol2cl rule; no compatibility aliases. Regenerate rather than hand-edit outputs.
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

- DESIGN33 PROOF contract: emit fully qualified `holai.runtime:proof` only for
  canonical new globals in holai.tactics/tactics.ml, without lexical prefix,
  at source-name occurrence1: then_/Value, thenl_/Value, orelse_/Function3.
  Binding reuse retains tagging; new aliases/shadowing do not. Only exact
  two-argument unlabelled applications qualify. Source proof names are not
  newly reserved/renamed; then1_ remains separate. Left folding/right inner
  PROOF preserve the binary call tree; branch lists, justification and kernel
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
  no text postprocessing. Fragment remains PROOF-only. Runtime funcall/API and
  manually authored semantic funcall tests stay unchanged.
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
  The full-release gate is satisfied; the user authorizes commit/push to
  tani/holai main. Never claim a push before it succeeds.
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
