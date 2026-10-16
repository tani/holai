# v0.3 implementation contract and evidence

The complete v0.3 declaration/proof surface is implemented over Holai's pinned
46-module HOL core. The design snapshot is [USER-DSL-SPEC.html](USER-DSL-SPEC.html);
the executable syntax and backend choices are documented in
[USER-DSL.md](USER-DSL.md). The snapshot's design-phase implementation freeze and
first-increment work lists are historical: the user subsequently authorized
implementation of the entire language. This document records the concrete
choices where the snapshot left alternatives open.

The package is `holai.user` (nickname `holai-user`). No generated Lisp, runtime,
translator, source map or vendor input was changed for this implementation.
Normal declarations use conservative native constructions and closed existence
proofs. They do not use new axioms, assumed termination, `admit`, or `sorry`.

## Specification-to-code matrix

Paths below are relative to `holai/user/`. The three normal suites are
`holai/tests/user-dsl.lisp` (U), `user-definitions.lisp` (D), and
`user-advanced.lisp` (A). Isolated state-changing checks are
`user-contracts.lisp` (C). Each row gives the actual mechanism, not a claim that
all possible inputs in that area are accepted.

| Spec section | Implementation and executable evidence |
| --- | --- |
| 0. Agreement and notation | Package/nickname, `?a`, `(field type)`; `package.lisp`, `definitions.lisp`; U/D package/type checks. |
| 1. CL conventions | Ordinary reader, docstrings, declarations and owned symbols; all eight units; U/D source and compiled-package checks. |
| 2. Trust and HOL basis | Generated type checker/kernel `prove`, closed results, guarded extensions; `package.lisp`, `proofs.lisp`, `resources.lisp`; D/A unchanged axioms, C explicit axiom opt-in and illicit mutation. |
| 3. Core coverage | All 46 public owners plus nested owners, qualified theorems and unambiguous term aliases; `development.lisp`; A list theorem/term use; checked-in descriptor inventory. |
| 4. Stages and objects | Macro capture, preterms, inference, native terms/theorems, checked publication; `terms.lisp`, `proofs.lisp`; U/D compile without constant introduction and FASL execution. |
| 5. Reader/packages | EQ symbol keys, injective kernel names, source-package capture; `package.lisp`, `terms.lisp`; U/D independent packages, escaped case and macro temporaries. |
| 6. Types | Arrows, products/sums/lists/sets, aliases, explicit variables, cartesian/finite dimension types; `terms.lisp`, `recursive-definitions.lisp`, `development.lisp`; U/D/A arity and annotation checks. |
| 7. Inference/overloads | Native inference, expected types, rigid variables, exact literals, restored candidate enumeration and strict ambiguity errors; `terms.lisp`, `development.lisp`; U/A numeric/NIL/decimal and interface restoration. |
| 8. Logical terms | Binders, choice, quantifiers, Boolean forms, local bindings, sets/lists/pairs; `terms.lisp`; U/A checked terms and scope rejection. |
| 9. Patterns/totality | Constructor matrices, linearity, aliases, independent wildcards, total match lowering; `terms.lisp`, `definitions.lisp`; D/A list/pair/Boolean/datatype matches and rejection cases. |
| 10. Declarations/results | Declaration validation, owner checks, generated-name preflight and exact theorem correspondence; `terms.lisp`, `definitions.lisp`, `recursive-definitions.lisp`; D/A duplicate/conflicting declarations and label case. |
| 11. Functions/specification | Logical functions/constants/aliases and existential specification, including contextual Skolemization; `definitions.lisp`, `constructions.lisp`; D/A ordinary functions, multiple/context witnesses, hidden type rejection. |
| 12. ADTs/records | Single/mutual regular datatypes, positivity/witness preflight, native principles, individual injectivity, projections and record update; `definitions.lisp`, `development.lisp`; D/A nested/mutual types and records. |
| 13. Inductive definitions | Parameterized mutual least relations/sets, checked named rules, cases/induction/strong induction, deferred monotonicity; `recursive-definitions.lisp`; D/A mutual labels, context parameters and completion. |
| 14. Recursion | Inferred primitive/mutual principles, native general existence, simultaneous sum/product encoding, measures/relations and deferred obligations; `recursive-definitions.lisp`; D/A primitive, measured, mutual numeric/datatype, nullary and completed recursion. |
| 15. Subsets/quotients/lifting | Native nonempty type and quotient construction, named relation, well-defined lifts and first-order theorem transfer; `constructions.lisp`; A nonempty/empty subset, lambda relation, successor injectivity transfer and polymorphic identity transfer. |
| 16. Theorems/closure | Fixed parameters, closed publication, local lemmas and failed-proof preservation; `proofs.lisp`, `constructions.lisp`; U/D/A closure and nested contexts. |
| 17. Theorem expressions | `ref/spec/inst/gen/rule/convert/lift-theorem`, checked argument elaboration; `proofs.lisp`, `resources.lisp`, `constructions.lisp`; U/A specialization, type instantiation, symmetry, conversions and transfer. |
| 18. Structured proofs | Contexts, local facts, `have/show/obtain/calc`, closure and witness freshness; `proofs.lisp`, `development.lisp`; U/A local leakage and eigenvariable rejection. |
| 19. Tactics/composition | Native tactic adapters, bounded repeat, labelled branches, real goal focus and generalized induction; `proofs.lisp`, `resources.lisp`, `development.lisp`; U/D/A focus index, labels, relational cases and generalized variables. |
| 20. Rewriting/resources | Positional and conditional rewriting, immutable simpsets, strict unresolved-condition reporting; `resources.lisp`; A hypothesis/subterm rewrites, inherited/frozen resources and strict conditions. |
| 21. Conversions/computation | Checked equality conversions, traversal/combination, immutable compsets, branch-aware evaluation and restored settings; `resources.lisp`; A num/int/real/beta, stops, false conversion contract and frozen conversion dependencies. |
| 22. Mathematics/automation | Standard core names plus MESON/METIS/leanCoP/nanoCoP, arithmetic, typed ring/field; `resources.lisp`, `development.lisp`; A all four search engines, integer/real rings, field and timeout conditions. |
| 23. CL/ASDF/contexts | Eight serial optional units, ordinary development systems, contextual parameter abstraction and local defaults; `holai.asd`, `constructions.lisp`, `development.lisp`; D/A FASL/reload and nested/contextual declarations. |
| 24. Extensions | Lexical CL macro expansion; procedural rules/tactics/conversions with explicit argument kinds and kernel-effect guards; `terms.lisp`, `resources.lisp`; D/A macros and optional/key/rest signatures; C mutation rejection. |
| 25. State/reload | Canonical source identity, idempotent successful plans, conflicts, stable pending obligations, uncertain-state blocking; `package.lisp`, `constructions.lisp`, `development.lisp`; D/A reload/completion; C blocked subsequent definition. |
| 26. REPL/conditions/restarts | Independent immutable proof sessions, undo/abort, search/inspection, condition slots and proof retry restart; `package.lisp`, `constructions.lisp`; A interactive completion, undo, focus, timeout, classified native failures and failed-state preservation; C delayed mutation and uncertain state. |
| 27. Artifacts/provenance/axioms | Source replay, inert alpha-normalized metadata, theorem references/versions, extension/resource history, conservative axiom bounds and explicit axiomatic profile; `package.lisp`, `development.lisp`, `constructions.lisp`; D/A compiled/source replay and readable manifest; C opt-in audit. |
| 28. Grammar/omissions | Ordinary macro entry points with arity, single-result, duplicate declaration, scope/type and option validation; `terms.lisp`, `resources.lisp`; U/D/A positive and negative forms. |
| 29. Conformance scenarios | Three normal suites and separate destructive contract process, original independent proof checks, source/FASL compilation and reload; runner and script paths below. |
| 30. Concrete decisions | The implementation choices and bounds below resolve the snapshot's implementation alternatives. |
| 31. Migration | The old prototype's property-list declarations are replaced by ordinary lambda lists, docstrings and `declare`; the manual and compilable example use current syntax. No silent acceptance of unknown options. |
| 32. Basis | Original pinned HOL Light core and generated API ownership remain authoritative; native inventory and unchanged vendor/CORE_FILES.json bound the profile. |

## Concrete choices and bounds

- **Names and overloads.** Package identity and escaped case are significant.
  Explicit type variables are rigid. Candidate checking rejects unresolved
  overloads instead of choosing a default numeric operator. Standalone literals
  retain the documented natural-number default. Native overload settings are
  restored even after failure.
- **Inspection.** `check` returns the term, type, free variables, type parameters
  and actual overload choices. `goal` permits free variables for exploration;
  named declarations remain strict. `find-theorems :pattern` uses native typed
  term matching, preserving binders for explicit quantified patterns and
  otherwise searching universally stripped conclusions. Specific diagnostic
  classes refine the broader syntax/name/type/result families; ordinary
  explicit tactic failure participates in `orelse`.
- **Datatype acceptance.** Recursive parameters must be regular. Preflight is
  conservative about positivity and constructor witnesses; it recognizes empty
  lists and delegates supported nested construction to the original package.
  Acceptance of every positive recursive functor is not claimed.
- **Simultaneous definitions.** Mutual datatype primitive recursion uses its
  common native principle. Other function groups prove one encoded simultaneous
  existence statement before specifying all names. Explicit measures may differ
  per member. Source-labelled equation results are proved against the resulting
  equations. This is not sequential introduction of mutually assumed functions.
- **Obligations.** Native residual hypotheses receive stable `:obligation-N`
  labels. Proofs must close exactly the pending obligations. Pending names are
  unavailable as logical constants; completion retains source identity and
  creates the same result bundle as immediate success.
- **Quotients.** Equivalence is proved before relation/type introduction. A
  conservative `quotient.relation` constant preserves lambda relation identity
  through native first-order lifting. Each stage handles one quotient relation
  instance; multiple stages can be composed. Type instances are inferred from
  argument/result annotations or explicit `(quotient type ...)` designators.
  Generic or Boolean equality quotients use the named relation in source facts;
  arbitrary higher-order transfer is beyond the native first-order procedure.
- **Resources.** Parent resources, theorem values, condition provers and
  computation conversions are captured at resource definition. Registry copies
  preserve late theorem/extension lookups in those callbacks. Redefinition
  creates a new generation; existing children retain their old behavior.
- **Procedural extensions.** Ordinary CL lambda lists and explicit
  `argument-kinds` elaborate host procedure arguments. No guessing of generated
  procedure currying, overload or argument categories is performed. Kernel
  changes during tactic execution or delayed justification are detected.
- **Search limits.** MESON supports native depth/inference bounds with restored
  global settings. Other search engines support timeout only and reject
  unsupported bounds. SBCL supplies the timer backend; operations requiring
  timers explicitly fail on hosts without it. This DSL has not been validated on
  additional Lisp implementations.
- **Provenance.** Manifests retain sources, versions, normalized judgments,
  resources and extension histories. Axiom dependencies are a conservative
  upper bound of current kernel axioms, not a minimal derivation dependency
  graph. FNV-1a source/reference identifiers are deterministic identifiers, not
  cryptographic proof signatures. Generated definition theorem bundles can lack
  a separate `defthm` proof source; their defining source is in the definition
  records. Manifests are inert inspection data. Replayed trusted CL source
  reruns proofs; no serialized theorem is accepted as authority.
- **Failure.** Closed proofs are required before specification introduction.
  Potentially partial native mutations mark the kernel uncertain and prohibit
  further declarations until restart. Neither kernel rollback nor rollback of
  arbitrary host CL effects is promised. The retry restart only reruns a proof.
- **Core scope.** The inventory covers 6,712 public owner/binding rows, including
  nested owners, reexports and implementation details. Qualified native
  theorem references and unique logical constants are directly usable.
  Procedures need registered signatures; implementation values remain explicitly
  classified as such. Optional upstream libraries outside the 46-module manifest
  and general host CL interoperability are outside this language profile.

## Validation on 2026-10-16

`make test-user` passed on x86_64 Linux, SBCL 2.2.9, from **two independent fresh
complete-core processes**:

| Suite | Checks | Boundary |
| --- | ---: | --- |
| Basic language | 82 | Terms, inference, proofs and package identity |
| Definitions | 68 | Definitions, datatypes, rules, source/FASL and reload |
| Advanced language | 235 | Contexts, mutual/general recursion, obligations, quotient transfer, resources, extensions, automation, interaction and metadata |
| Isolated contracts | 12 | Explicit axiom introduction and irreversible uncertain-state fixture |

The normal three suites preserve the initial three kernel axioms. The isolated
fixture explicitly adds one test-only axiom, then tests illicit extension
mutation during ordinary tactics and delayed definition/interactive
justifications, preservation of the failed session state, and subsequent
declaration blocking in its own process.

All eight user units, the three normal test units, the isolated fixture and the
example compiled with zero compiler errors/warnings, including style warnings.
Thirty macro redefinition conditions occurred separately during load. The compiled example
executed without compilation introducing kernel constants. The definition suite
passed twice (68 each); the advanced suite passed 235 then 227 checks in one
process, with eight pending-only checks skipped after successful completion.
The independent original PROOF/reader suite passed 69 checks.
All fenced Lisp examples in the manual executed successfully; Python syntax
checks and `git diff --check` passed.
DSL evidence is separate from the historical 52 physical-unit core cold
compilation audit, core differential observations and original 69-check
PROOF/reader suite. DESIGN39.4 records the focused run and its boundary.
The full pinned Nix release, OCaml differential, regeneration/source-map audits
and additional-host compatibility were not rerun for this optional layer.

Reproduction entry points:

```sh
make test-user
```

- `holai/tests/user-dsl-runner.lisp` loads the complete core and runs the three
  normal ASDF suites.
- `holai/tests/user-contracts-runner.lisp` loads another complete core and runs
  the isolated fixture.
- `misc/scripts/test-user.py` checks each process's exit status and suite counters;
  logs are `_build/user-dsl.log` and `_build/user-contracts.log`.
- `holai/tests/user-descriptors.lisp` regenerates the public descriptor TSV.
- Release source fingerprints include every optional user unit/test; these
  counts and files do not replace the original core's observation boundary.
