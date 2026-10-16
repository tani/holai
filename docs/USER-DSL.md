# Common Lisp proof language

`holai/user` provides the v0.3 proof language in package `holai.user`, nickname
`holai-user`. It uses the generated HOL inference, definition and proof procedures.
The [implementation contract](USER-DSL-IMPLEMENTATION.md) maps the complete
[design snapshot](USER-DSL-SPEC.html) to source and tests, and records backend bounds.
Normal definitions and proofs add no axioms.

## Loading and packages

```lisp
(asdf:load-system "holai/user")

(defpackage :my-proofs
  (:use :cl :holai.user)
  (:shadowing-import-from :holai.user
    :defun :defconstant :deftype :defstruct))
(in-package :my-proofs)
```

The four shadowed names introduce logical objects. Use `cl:defun` for host
functions. Logical functions do not create executable CL functions. Names retain
their symbol identity, package and escaped case. A declaration must own its name;
use `:shadow` for inherited names. Macros capture their source package, including
when a compiled development is loaded from another REPL package.

Use ordinary `load`, `compile-file`, and serial ASDF components. Compilation
captures declaration plans; loading performs logical introductions and proofs.
Ordinary CL forms retain their normal privileges.

## Types, inference and terms

```lisp
(deftype predicate (?a) (-> ?a bool))

(term (forall (xs)
        (declare (type (list ?a) xs))
        (= (append xs (list)) xs)))

(read-term '(+ x y) :expected-type 'num)
(check '(the real 1/2))
```

Only `?`-prefixed symbols denote explicit type variables. Types include `bool`,
`num`, `int`, `real`, `(-> ?a ?b bool)`, `(list ?a)`, `(prod ?a ?b)`,
`(sum-type ?a ?b)`, `(set ?a)` and `(cart real (finite 3))`.
Unknown constructors, wrong arities and conflicting annotations fail.
`the` and `(declare (type type variables...))` constrain inference.
`(declare (values type))` constrains one logical result;
`(declare (type-variables ?a ...))` restricts residual type parameters.
Inference without that declaration permits polymorphism. Named type variables
are rigid. The generated type checker handles unification and occurs checks.

Integer and ratio objects are exact. Expected types select `num`, `int` or `real`;
an unconstrained nonnegative numeral defaults to `num`. `(decimal "1.25")` is
exact real `5/4`. Floats are rejected. An overloaded operation with multiple
possible types is an error: annotate `(+ 1 2)` with `(the num ...)`, or supply an
expected type. `nil` requires a Boolean or list type; `(list)` is explicitly empty.

Terms include application, `lambda`, `forall`, `exists`, `exists1`, `choose`,
`and`, `or`, `not`, `implies`, `iff`, `if`, total `cond`, `let`, `let*`, `the`,
`pair`, `cons`, `list`, `set`, `setof`, `arbitrary`, and constructor `match`.
Logical lambda lists contain distinct required symbols. A term body has one term
after declarations. Host functions and values are not implicitly called or lifted.

`term` captures literal syntax. `read-term`, `hol-type` and `check` are CL APIs
taking quoted syntax. Inspection permits free variables; declarations reject
undeclared free names. Explicit `(hol-syntax "...")` is inspection-only.
`check` returns five values: term, type, free term variables, type variables and
selected overloads (operator, actual constant and instantiated type).

Patterns support constructors, built-in lists/pairs/Booleans, independent `_`
wildcards, `the` annotations and `(as name pattern)` aliases. Patterns must be
linear and exhaustive. Function recursion uses distinct constructor heads or
explicit equations; overlapping computational clauses are rejected.

## Functions, datatypes and records

```lisp
(defdatatype tree (?a)
  (leaf (value ?a))
  (node (left (tree ?a)) (right (tree ?a))))

(defun tree-size (tree)
  (declare (type (tree ?a) tree) (values num))
  (match tree
    ((leaf value) 1)
    ((node left right) (+ (tree-size left) (tree-size right)))))

(defstruct point (?a) (x ?a) (y ?a))
```

Fields are `(name type)` in constructor argument order. Datatype parameters are
explicit, including `()` for ground types. Recursive occurrences retain those
parameters. `(defdatatypes group (?a ...) (type constructors...) ...)` defines
mutual types sharing parameters. Conservative positivity and witness checks run
before the original datatype package. Supported nested list/function fields are
delegated to that package; no GADTs or dependent types are introduced.

Generated results include `.induction`, `.recursion`, `.cases`, `.injective`
when applicable, `.distinct` when applicable, and `constructor.injective` for
individual constructors with fields. Results belong to their owner's package
and are not automatically exported.

`defstruct` generates positional `make-point`, `point-x` and `point-y` plus checked
projection equations. `(record-update point p (x value))` reconstructs a record
with the specified fields replaced.

Functions register `.definition` and `.equations`. Recursion principles are
inferred, including mutual datatype recursion; an explicit
`(declare (recursion tree.recursion))` is optional. General recursion uses the
original recursive existence procedure. `defconstant` defines a logical nullary
function; `deftype` defines a transparent type abbreviation.

```lisp
(deffunctions parity
  (even-number (n)
    (declare (type num n) (values bool))
    (if (= n 0) true (odd-number (- n 1))))
  (odd-number (n)
    (declare (type num n) (values bool))
    (if (= n 0) false (even-number (- n 1)))))

(defun measured-copy (n)
  (declare (type num n) (values num) (measure n))
  (if (= n 0) 0 (succ (measured-copy (- n 1)))))
```

`deffunctions` proves simultaneous existence before introducing its members.
The group has `.equations`; each member has its own equations.
General groups use a tagged sum of argument tuples and a product of results.
Automatic ordering handles recognized numeric measures and acyclic call groups.
Explicit group measures use `(declare (measure (f expression) (g expression)))`.
Single functions accept `measure`, `well-founded-relation`, or `termination`;
these ordering declarations are mutually exclusive. User proofs can be supplied
through `(obligation-proofs (:obligation-1 (by steps...)) ...)`.

`defequations` supplies named simultaneous equations:

```lisp
(defequations tree-size-by-equations (tree)
  (declare (type (tree ?a) tree) (values num) (recursion tree.recursion))
  (leaf-case (x) (= (tree-size-by-equations (leaf x)) 1))
  (node-case (l r)
    (= (tree-size-by-equations (node l r))
       (+ (tree-size-by-equations l) (tree-size-by-equations r)))))
```

Unproved termination or monotonicity conditions raise `dsl-obligation-error` and
leave the declaration pending, with no usable logical constant. Inspect them
with `(obligations 'name)`; complete with
`(complete-definition 'name '((:obligation-1 (by ...)) ...))`.
Labels and source are retained. Every listed obligation needs a closed proof;
completion introduces constants only after all proofs succeed.

## Inductive relations and sets

```lisp
(definductive even (n)
  (declare (type num n) (strong-induction t))
  (zero () (even 0))
  (step (k) (implies (even k) (even (+ k 2)))))

(defrelations reachability (r)
  (declare (type (-> num num bool) r))
  (reachable (x y)
    (declare (type num x y))
    (edge (x y) (implies (r x y) (reachable x y)))
    (chain (x y z)
      (implies (and (reachable x y) (reachable y z)) (reachable x z)))))
```

Each clause binds explicit variables. A rule's conclusion must be headed by its
relation. Group parameters become fixed leading arguments, e.g. `reachable r x y`.
`definductive-set` is the unary relation declaration form.
The native least-relation procedure proves existence and monotonicity. Explicit
`monotonicity-proof` or later obligation completion can discharge
side conditions. Residual assumptions are never registered as completed results.

Results include `.rules`, `.rules.label`, `.induction`, `.cases` and requested
`.strong-induction`. Mutual groups also expose member induction/cases.
Labels are local to each relation. A repeated label is available as
`group.rules.relation.label`; `group.rules.label` exists only when unique.
Named equations and rules are matched to their propositions by checked proofs.

## Specifications, subsets, quotients and lifting

```lisp
(defspec (chosen) ()
  (exists (x) (declare (type num x)) (= x 3))
  (witness 3) (refl))

(defsubset positive () (declare (representation-type num))
  (lambda (n) (> n 0))
  (by (witness 1) (conv (depth beta)) (arith)))

(defquotient number-class () (declare (representation-type num))
  (lambda (x y) (= x y))
  (by (conv (depth beta)) (meson)))

(defun successor (n) (declare (type num n)) (succ n))
(deflift class-successor (q)
  (declare (type number-class q) (values number-class)
           (quotients number-class) (lift-positions 1))
  successor
  (by (simp successor) (meson)))
```

`defspec` consumes all leading existential witnesses and registers
`chosen.specification`. Subsets require nonemptiness; they generate `.abs`, `.rep`,
`.abs-rep`, `.rep-abs`, and `.membership`. Quotients require the native equivalence
property; they additionally generate `.relation`, `.class`, `.equivalence`,
`.class-relation`, and `.class-equality`. The supplied relation is conservatively
named before native theorem transfer, including when it is a lambda expression.

`deflift` proves well-definedness, then introduces the lifted constant with
`.definition`, `.equations` and `.lifting`. Argument positions are one-based.
Use explicit result types to distinguish representative and quotient results.
One relation instance is handled per lifting stage; compose stages for multiple
quotients. A polymorphic designator can be specialized as `(quotient type ...)`.

The theorem expression `(lift-theorem number-class source-theorem)` performs
native first-order theorem transfer using registered lifting results. Additional
lifting facts may follow. For generic/Boolean equality quotients, state source
facts with `quotient.relation` so logical equivalence is not mistaken for the
relation being transferred. Concrete equality quotients can transfer ordinary
equalities. Arbitrary higher-order transfer is outside the native procedure.

## Theorems, contexts and proof language

```lisp
(defthm tree-size-positive (tree)
  (declare (type (tree ?a) tree))
  (>= (tree-size tree) 1)
  (induct tree) (simp tree-size) (asm-arith))

(with-proof-context (p)
  (declare (type bool p) (assumption h p))
  (lemma local-fact () p (exact h))
  (defthm closed-fact () p (exact local-fact)))
```

`defthm` takes a name, parameters, optional docstring, declarations, proposition
and steps. `prove` omits the name. Parameters remain fixed during proof;
publication universally closes parameters and discharges context assumptions
as implications. Published results have no open hypotheses. A failed proof
preserves an earlier theorem. `(theorem 'name)` retrieves a result.

`with-proof-context` nests fixed parameters, labelled assumptions and defaults:
`(simpset name)`, `(compset name)`, `(automation :timeout seconds)`.
`lemma` is local to that context. Functions and relations abstract context
parameters as leading arguments; within the context those arguments are implicit.
Existence specifications under assumptions use checked Skolemization.
Outside the context all leading arguments are explicit.

Theorem expressions include `ref`, `spec`, `inst`, `gen`, `rule`, `convert`, and
`lift-theorem`. `inst` accepts `:types ((?a type) ...)` and term substitutions.
`ref` explicitly selects a theorem when its symbol also names a logical constant.
Qualified generated symbols, e.g. `(ref holai.lists:APPEND)`, are supported.

| Purpose | Steps |
| --- | --- |
| Introductions and closure | `intro`, `intros`, `fix`, `assume`, `exact`, `apply`, `assumption`, `refl`, `contradiction` |
| Logical structure | `split`, `left`, `right`, `witness`, `cases`, `induct`, `obtain` |
| Structured proofs | `have`, `show`, `proof`, `by`, `calc`, `branch`, `focus` |
| Composition | `then`, `thenl`, `all-goals`, `orelse`, `first`, `try`, `repeat`, `skip`, `fail` |
| Simplification | `rewrite`, `asm-rewrite`, `simp`, `asm-simp`, `unfold`, `fold`, `conv`, `normalize`, `compute` |
| Automation | `taut`, `arith`, `asm-arith`, `ring`, `field`, `meson`, `metis`, `leancop`, `nanocop` |

`cases`/`induct` infer principles or accept `:using theorem`. Induction accepts
`:generalizing (variables...)`. Constructor branches have constructor labels;
natural induction uses `base` and `step`. `branch` checks a label and fresh names.
`focus` accepts a unique label or a one-based goal index and actually selects that
goal. `obtain` checks witness freshness/non-escape. `calc` proves every equality
and composes them by transitivity. `repeat` requires progress and has a default
1000-step bound. `orelse` catches proof failure, while name/type/resource errors
propagate. Procedural commands have a default 30-second SBCL timeout.

## Rewrite resources, conversions and computation

```lisp
(defsimpset arithmetic-rules (rewrites successor))
(defsimpset extended-rules (extends arithmetic-rules))
(defcompset evaluation-rules
  (equations successor.equations) (conversions num-reduce))

(prove () (= (successor 2) 3) (compute :set evaluation-rules))
(apply-conversion '(depth beta) (read-term '((lambda (x) x) 2)))
```

Simpsets accept `extends`, `rewrites`, `congruences`, and `condition-provers`.
Compsets accept `extends`, `equations`, and `conversions` (a conversion alone or
`(constant arity conversion)`). Resources capture immutable parent/theorem/
extension snapshots. Redefining a resource or extension does not change an
existing child's behavior. Resource generations are retained in provenance.

Rewrite commands accept `:using (theorems...)`, `:set name`, `:orientation`,
`:repeat`, `:strict`, and `:at`. Locations include `goal`, `(hypothesis label)`
and `(subterm goal (rator rand ...))`; paths use `rator`, `rand`, `body`.
Conditional rules use actual condition proving. `:strict t` reports unresolved
conditions as `dsl-obligation-error`, with their terms in `dsl-error-actual`.
A function name selects its equations; `(ref name)` selects a theorem explicitly.

Conversions include `beta`, `eta`, `(alpha name)`, `rator`, `rand`, `body`,
`depth`, `redepth`, `once`, `try-conv`, `repeat-conv`, `then-conv`, `orelse-conv`,
`rewrite-conv`, `num-reduce`, `int-reduce`, `real-rat-reduce`, `eval` and
`restricted-eval`. Every conversion must return a closed equality with the actual
input on the left and the same type on the right. Traversal/repetition detects
progress. `convert` also supports theorem conclusion/hypothesis positions.
Evaluation supports `:set`, `:strategy` and `:stops`; temporary native computation
settings are restored. Conditional evaluation follows the selected branch.

`ring`/`field` select native arithmetic procedures using HOL types. MESON accepts
`:depth` or `:steps` (its native inference bound), and all search adapters accept
`:timeout`. METIS/leanCoP/nanoCoP reject unsupported depth/step settings.
Automation defaults to a ten-second timeout. Bounded execution currently uses
SBCL timers; other hosts explicitly reject operations needing that timer backend.

## Macros, procedures and the standard library

Ordinary `defmacro`/`macrolet` expand with their lexical environment. Binders,
declarations and labels are protected during traversal; gensym sharing is kept.
Expansion is bounded and its output is elaborated normally. Hygiene is the
macro author's responsibility.

```lisp
(defrule double-symmetry (th)
  (declare (argument-kinds :theorem))
  (holai.equal:SYM (holai.equal:SYM th)))

(deftactic reflexivity () #'holai.tactics:REFL_TAC)
(defconversion identity-conversion ()
  (lambda (tm) (holai.fusion:REFL tm)))
```

These bodies are host CL. `argument-kinds` declares `:term`, `:type`, `:theorem`,
`:tactic`, `:conversion`, or literal `:syntax`; omission means `:syntax`.
Required/optional/rest/key/aux lambda lists are supported. A rest kind applies
to every rest element; mixed rest/key tails must remain syntax.
`register-rule`, `register-tactic`, and `register-conversion` are functional APIs.
Returned theorems/tactics/conversions are checked, including delayed proof
justifications; extension calls cannot introduce logical declarations unnoticed.

`standard-descriptors` inventories public bindings in all 46 pinned core modules
and their nested owners. Unique constant aliases and qualified native theorem
references are installed. Native procedures require explicit argument-kind
registration rather than guessed wrappers. The checked-in
[descriptor inventory](USER-DSL-NATIVE-DESCRIPTORS.tsv) has 6,712 public binding
rows, including reexports and implementation values; these are not 6,712 DSL
commands. `application` distinguishes direct terms/theorems, procedures requiring
signatures, and implementation details. Regenerate with
`holai/tests/user-descriptors.lisp` against an initialized pinned core.

## Interaction, errors, reload and persistence

```lisp
(goal '(and (= 1 1) (= 2 2)))
(proof-step '(split))
(goals)
(undo)
(proof-step '(thenl (split) (refl) (refl)))
(abort-proof)

(find-theorems "TREE-SIZE")
(find-theorems :pattern '(= (tree-size x) y))
(describe-theorem 'tree-size-positive)
(describe-definition 'tree-size)
```

Sessions retain immutable goal states; `proof-step` returns the completed theorem.
They do not alter the generated interactive goal stack or replay procedural
commands to reconstruct a proof. Undo restores the prior state.
`goal` permits free variables for interactive exploration. Pattern search uses
the native typed term matcher: free pattern variables are schematic, binders
are matched up to alpha-renaming, and leading universal binders in candidate
theorems are stripped unless explicitly present in the pattern.

Conditions derive from `dsl-error`, with form, cause, source, context and
expected/actual slots. Subclasses distinguish syntax, name, type, scope, proof
failure, obligations, conflicts, resource exhaustion, interruption, extension
contracts and uncertain kernel state. Definition-side proof blocks offer a
`retry-proof` restart. No restart certifies an unproved theorem.
Specific subclasses include `dsl-option-error`, `dsl-ambiguous-name`,
`dsl-overload-error`, `dsl-pattern-error`, `dsl-coverage-error`,
`dsl-result-error` and `dsl-backend-error`. The `dsl-proof-failure`,
`dsl-resource-exhausted` and `dsl-interrupted` classes also satisfy the
specification's `tactic-failure`, `proof-resource-limit` and `proof-interrupted`
families. Ordinary explicitly signalled tactic failure participates in `orelse`.

Identical successful definitions reuse their result on reload. Documentation
changes do not change logical identity; uninterned macro temporaries are
canonicalized while retaining sharing. Changed logical definitions signal
`definition-conflict`. Pending source cannot be silently replaced. A possibly
partial kernel failure marks the state uncertain and blocks further definitions;
restart from a clean image. Arbitrary host effects and kernel rollback are not
promised.

`(save-development pathname forms :manifest-path path)` writes executable CL
source plus an inert manifest. Loading source reruns proofs. The manifest records
the pinned basis, host, expanded sources, alpha-normalized judgments, theorem
versions/references, resource/extension histories and a conservative upper bound
of current kernel axioms. It is not a theorem deserializer or proof certificate.
Source IDs use deterministic FNV-1a identifiers, not cryptographic signatures.
Sources/FASLs/images are trusted ordinary CL artifacts.

`with-axiomatic-extensions` explicitly enables `declare-type`,
`declare-constant`, and `defaxiom` for research; normal use rejects them.
Such extensions are recorded and cannot be hidden as ordinary definitions.

## Verification

Run `make test-user` for fresh full-core normal and isolated contract processes;
`(asdf:test-system "holai/user")` runs the three normal suites. Normal checks
cover inference, packages, definitions, all declaration families, proof resources,
automation, interaction, source/FASL replay, version capture and rejection cases.
The isolated suite intentionally exercises axiom addition and uncertain state.
It never contaminates the normal suite.

See [the implementation matrix](USER-DSL-IMPLEMENTATION.md) for measured counts
and portability limits, and [examples/user-dsl.lisp](../examples/user-dsl.lisp)
for a compilable development.
