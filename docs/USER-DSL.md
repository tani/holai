# HOL proof language

Load `(asdf:load-system "holai/user")`, then use `(in-package :holai.user)`.
The package's nickname is `holai-user`.
The optional system depends on the complete translated core; loading `holai` or `holai/runtime` alone retains its existing behavior.
See [the executable development](../examples/user-dsl.lisp).

```lisp
(defthm implication-identity
  (implies p p)
  (assume h)
  (exact h))

(defthm polymorphic-reflexivity
  (forall (x) (= x x))
  intro
  refl)

(defthm conjunction-swap
  (implies (and p q) (and q p))
  (meson))
```

Statements and proof commands are literal data.
No quote, tuple construction, function-value notation or Lisp lambda is required.
They are never evaluated as Common Lisp programs by the DSL.
The normal Lisp reader still reads source files; this is not an untrusted-input reader.

## Terms and types

`(term syntax)` produces a typed HOL term.
`(read-term syntax :expected-type type)` is its data-driven counterpart.
`(hol-type syntax)` elaborates a type expression.

| Syntax | Meaning |
| --- | --- |
| `x`, `(f x y)` | Inferred variable/constant and curried application |
| `true`, `false`, `t`, `nil` | HOL truth and falsity |
| `(= x y)`, `(and p q)`, `(or p q)`, `(not p)` | Equality and connectives |
| `(implies p q)`, `(iff p q)` | Implication and Boolean equivalence |
| `(forall (x y) p)`, `(exists (x) p)`, `(exists1 (x) p)` | Quantifiers |
| `(lambda (x y) body)` | HOL abstraction |
| `(if p x y)` | HOL conditional |
| `0`, `42`, `(+ x y)`, `(< x y)` | Numerals and ordinary overloaded constants |
| `(x :type num)`, `(the num x)` | Explicit term constraint |
| `(forall ((x :type num) y) p)` | Optional binder constraints |
| `"!x:num. x + 0 = x"` | Original HOL term syntax, also usable as a subterm |
| `bool`, `num`, `real`, `a` | Registered ground types or named type variables |
| `(-> a b c)`, `(list a)`, `(prod a b)` | Right-associated function type and type constructors |
| `"num->bool"` | Original HOL type syntax, including registered abbreviations |

Symbol spelling is lowercased independently of the caller's package.
HOL's case-sensitive uppercase names are available as HOL strings, such as `("MAP" f xs)`; existing generated theorem references use package-qualified symbols, such as `holai.bool:TRUTH`.
Logical aliases are reserved as S-expression variable names.
Binders must list distinct variable names, but nested binders may shadow names.
Variables are inferred from use without declarations; unrecognized names follow HOL Light's free-variable convention rather than generating new constants.

Elaboration constructs `holai.preterm` preterms directly, then uses the translated `retypecheck` and `term_of_preterm` functions.
All uses of a free variable in one term share its inferred type, while each use of a polymorphic constant is freshly instantiated.
Applications, binders, annotations and expected results contribute constraints.
For example, `(read-term '(+ x y) :expected-type 'num)` selects natural addition, and the same syntax with expected type `real` selects real addition.
Proof statements are constrained to `bool` before inference, including strings.

Unconstrained types remain HOL type variables, with upstream's type-invention notice; they are not arbitrarily replaced by a ground type.
Where several overloaded instances remain possible, the existing HOL interface priority decides the choice; this is not a claim of principal overload resolution.
Use a type annotation for the intended numeric domain when it is ambiguous.
Ill-typed applications and infinite types fail rather than inserting coercions.
The DSL does not change global parser priorities or implicit-type settings.

## Proofs

`(prove statement command ...)` returns a theorem without registering a name.
`(defthm name statement command ...)` registers a theorem after complete success.
`(theorem 'name)` retrieves it; names are shared across DSL developments and symbol names are lowercased, whereas string names preserve case.
An unsuccessful redefinition leaves the previous registered theorem intact.
The data API is `(prove-term statement command-list)`.

| Command | Effect |
| --- | --- |
| `intro`, `intros` | Introduce one / repeatedly introduce universal variables or premises |
| `(fix x)` | Introduce a universal variable with an explicit name and inferred type |
| `(assume h)` | Discharge an implication and label its premise |
| `assumption`, `refl`, `split` | Use a hypothesis, reflexivity, conjunction introduction |
| `(exact name)`, `(apply name)` | Match and instantiate a theorem / use matching modus ponens |
| `(rewrite names...)`, `(simp names...)` | Original rewriting / simplification |
| `(asm-rewrite names...)`, `(asm-simp names...)` | Also use the current hypotheses |
| `(meson names...)`, `taut`, `arith` | Original assumption-aware MESON, ITAUT, arithmetic tactics |
| `(cases p)` | Boolean case split |
| `induct`, `(induct principle)` | Natural number induction / a registered induction theorem, followed by stripping premises |
| `asm-arith` | Arithmetic using induction hypotheses and other assumptions |
| `(witness term)` | Existential witness inferred against the existential variable's type |
| `(have h statement commands...)` | Prove a local lemma under the current hypotheses |
| `(then commands...)` | Sequence, applying each command to every remaining goal |
| `(thenl command branch...)` | Match one branch command to each produced subgoal |
| `(orelse a b)`, `(try a)`, `(repeat a)` | Original failure fallback / optional / repeated tactic |
| `skip`, `fail` | Identity / failing tactic |

A zero-argument command can be written bare or parenthesized.
The body is an implicit `then`; multi-command branches use `(then ...)`.
`thenl` checks branch count through the generated tactical.
As with HOL Light, `repeat` requires a tactic that eventually fails; repeating `skip` does not terminate.
Local assumption labels take precedence over registered names inside a proof.
Names used by rewriting, simplification and MESON may also reference local labels.

```lisp
(defthm branching
  (and true (implies p p))
  (thenl split
    (exact holai.bool:TRUTH)
    (then intro assumption)))

(defthm with-local-lemma
  (implies p p)
  (assume h)
  (have local-p p (exact h))
  (exact local-p))

(defthm with-witness
  (forall ((x :type bool)) (exists (y) (= y x)))
  intro
  (witness x)
  refl)
```

Proof-local terms are elaborated using free-variable types from the current goal and hypotheses; a witness also receives its expected type from the goal.
`have` first creates a separate obligation without adding the lemma to that obligation's hypotheses, so a lemma cannot prove itself.
Finished batch proofs go through the translated `holai.tactics:prove`, which requires no remaining hypotheses and checks the returned conclusion.
The interactive HOL goal stack is not changed.

## Conservative definitions and diagnostics

```lisp
(defhol identity-definition (= (user_identity x) x))
(defthm identity-on-booleans
  (forall ((x :type bool)) (= (user_identity x) x))
  (rewrite identity-definition))
```

`defhol` invokes the original `holai.pair:new_definition` and registers its defining theorem; it does not introduce an axiom.
HOL constant definitions persist in the existing kernel state.
A Common Lisp interoperability layer is outside this DSL.

## Inductive relations

```lisp
(definductive user-even
  (user_even 0)
  (forall (n) (implies (user_even n) (user_even (+ n 2)))))

(defthm even-step-example
  (user_even (+ 0 2))
  (meson user-even.rules))
```

The body consists of introduction clauses, inferred together as one conjunction.
`user-even` and `user-even.rules` name the introduction theorem; `user-even.induction` is the leastness/induction principle and `user-even.cases` is the inversion theorem.
The HOL predicate itself is `user_even`; the declaration's label need not be its constant name.
Put `forall` around clause-local variables; schematic parameters and mutually inductive predicates follow HOL Light's inductive-definition conventions.
Multiple predicates can occur among the conclusions of the same declaration; their combined rules, induction and cases receive the declaration label.
Before introducing constants, the DSL calls the original existence prover and rejects any remaining monotonicity assumptions.
It then invokes `new_inductive_definition` and registers only closed theorems.

## Algebraic datatypes

```lisp
(defdatatype user_tree
  (user_leaf a)
  (user_node user_tree user_tree))

(defdatatype user_flag user_off user_on)
(defdatatype user_rose (user_rose_node a (list user_rose)))
```

Each constructor lists its field types; a nullary constructor may be bare or parenthesized.
Unknown field type names such as `a` become type parameters, in the underlying HOL type package's canonical order.
The declaration infers the parameter list rather than taking an explicit one.
Refer to the recursive type by its bare name inside its declaration; after definition its instances use ordinary type application, such as `(user_tree num)`.
Nested recursion through registered datatypes, such as `(list user_rose)`, is handled by the original datatype package.
Function-valued fields use `(-> num a)`.
Type/constructor names must be HOL identifiers; use underscores rather than hyphens in these constant/type names.
String names preserve case, for example `("Leaf" a)`.
Nullary constructor terms are written as atoms, not zero-argument applications.

| Registered theorem | Meaning |
| --- | --- |
| `user_tree`, `user_tree.induction` | Structural induction |
| `user_tree.recursion` | Recursion/existence principle |
| `user_tree.cases` | Constructor exhaustiveness |
| `user_tree.injective` | Constructor injectivity, when some constructor has fields |
| `user_tree.distinct` | Constructor distinctness, when there are at least two constructors |

These are original HOL theorems produced by `define_type` and its public theorem accessors.
The DSL defines one datatype per declaration; it does not add GADTs, dependent indices or a new positivity algorithm.

## Functions defined by recursion

```lisp
(defrecursive tree-size
  (:recursion user_tree.recursion)
  (= (user_size (user_leaf x)) 1)
  (forall (l r)
    (= (user_size (user_node l r)) (+ (user_size l) (user_size r)))))

(defthm tree-size-positive
  (forall ((t0 :type (user_tree num))) (<= 1 (user_size t0)))
  (induct user_tree.induction)
  (asm-rewrite tree-size)
  asm-arith)

(defrecursive natural-copy
  (= (user_copy 0) 0)
  (forall (n) (= (user_copy ("SUC" n)) ("SUC" (user_copy n)))))

(defthm copy-identity
  (forall ((n :type num)) (= (user_copy n) n))
  induct
  (asm-rewrite natural-copy))
```

An initial `(:recursion theorem-name)` selects `new_recursive_definition` with that closed recursion principle; existing generated principles, such as `holai.nums:num_RECURSION`, are also accepted.
Omitting it selects the original general `holai.define:define`, which recognizes registered datatype recursion and attempts its existing termination/well-definedness proofs.
Both routes infer all equations together and register the resulting closed theorem as the label and `label.equations`.
Free left-hand-side variables are universally closed by the backend; explicit `forall` gives clause-local binding before type inference.
The general backend defines one function at a time; simultaneous definitions require a suitable explicit recursion theorem.
Termination automation retains the original backend's limits: arbitrary recursive programs are not accepted merely because they are syntactically valid.
No separate function-induction or termination theorem is fabricated; structural proofs use the datatype/natural-number induction principles.

Successful identical inductive and function declarations are memoized for reloading the same source forms; datatype redeclaration uses the original package's benign-redefinition mechanism.
New theorem bundles are registered only after validation, so a failed declaration does not replace an existing DSL theorem bundle.
Kernel definitions are persistent: this does not promise transactional rollback of every auxiliary definition that an upstream definition procedure may introduce before failure.

Malformed DSL syntax and original HOL failures signal `dsl-error`.
`dsl-error-form` retains the input and `dsl-error-cause` retains the underlying HOL condition or diagnostic text.
Proof fallback catches original HOL tactic failures before this outer diagnostic conversion, preserving the generated `ORELSE` semantics.
Host interrupts and unrelated implementation errors are not swallowed.

Run `(asdf:test-system "holai/user")` for the focused type-inference and proof suite, or `make test-user` in the configured Lisp environment.
This exercises the new layer against the complete generated core, independently of the translator's existing OCaml differential/release checks.
