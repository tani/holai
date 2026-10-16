# Common Lisp proof language

`holai/user` implements the first part of the [v0.3 language specification](USER-DSL-SPEC.html).
The public package is `holai.user`, with nickname `holai-user`.
It uses the generated HOL inference, definition and proof procedures; it adds no axioms.
This implementation replaces the earlier prototype syntax. It does not yet implement the entire specification.

## Load and package

```lisp
(asdf:load-system "holai/user")

(defpackage :my-proofs
  (:use :cl :holai.user)
  (:shadowing-import-from :holai.user
    :defun :defconstant :deftype :defstruct))
(in-package :my-proofs)
```

The four shadowed names are logical definition macros.
Use `cl:defun` for a host Common Lisp function.
Logical definitions do not create executable CL functions or host constants.
Names retain symbol identity, home package and escaped case.
New declarations must use symbols owned by the source package; use `:shadow` when reusing an inherited CL name.
The macros retain their source package when compiled and later called from a different REPL package.

The ordinary reader, `load`, `compile-file` and serial ASDF components are used.
Compiling a development creates declaration plans without introducing kernel types or constants.
Loading its FASL performs the definitions and proofs.
Ordinary CL source retains its normal execution privileges.

## Types and terms

```lisp
?a
(-> ?a ?b bool)
(list num)
(prod num bool)

(deftype predicate (?a)
  (-> ?a bool))

(term
  (forall (xs)
    (declare (type (list ?a) xs))
    (= (append xs (list)) xs)))
```

Only `?`-prefixed names denote explicit type variables.
Unknown type constructors and wrong arities are errors.
Type annotations use `the` and `declare (type ...)`.
`declare (values type)` constrains a function's single logical result.
`declare (type-variables ?a ...)` restricts the permitted residual type variables; omission allows inferred polymorphism.
Named type variables remain rigid during inference.

Terms include application, `lambda`, `forall`, `exists`, `exists1`, `choose`,
`and`, `or`, `not`, `implies`, `iff`, `if`, total `cond`,
`let`, `let*`, `the`, `pair`, `cons`, `list`, `set`, `setof`,
`arbitrary`, and exhaustive constructor `match`.
Logical lambda lists contain distinct required symbols, without CL lambda-list keywords.
Bodies contain one logical term after their declarations.
Host functions and values are not implicitly called or lifted.

Integer and ratio objects are exact.
Expected types select `num`, `int` or `real` representations; floating-point literals are rejected.
An otherwise unconstrained numeral defaults to `num`.
`nil` requires an unambiguous Boolean or list type; `(list)` explicitly denotes an empty list.
The original overload resolver still selects overloaded operators.
The specification's complete ambiguity policy and `decimal` syntax remain pending.

`term` captures literal syntax. `read-term` and `check` are CL functions taking quoted syntax:

```lisp
(read-term '(+ x y) :expected-type 'num)
(check '(the real 1/2))
```

Inspection permits free variables. Named declarations reject undeclared free term names.
Raw HOL text is available explicitly through `(hol-syntax "...")` in inspection;
it is currently rejected in strict declarations.

## Functions and theorems

```lisp
(defun identity-function (x)
  "The polymorphic identity."
  (declare (type ?a x))
  x)

(defconstant empty-numbers
  (the (list num) (list))
  "An empty list of natural numbers.")

(defthm identity-equation (x)
  (declare (type num x))
  (= (identity-function x) x)
  (simp identity-function))
```

A theorem has a name, parameter list, optional docstring, declarations, proposition and proof steps.
Parameters are fixed while proving and universally closed after success.
The published theorem must have no open assumptions.
`prove` has the same form without a name and returns an unregistered theorem.
`(theorem 'identity-equation)` retrieves a registered theorem.
Explicitly qualified generated theorem symbols can also be used.
A failed proof preserves the previous named theorem.

Functions register `.definition` and `.equations` theorems.
A definition name in `simp` or `rewrite` selects its equations.
Successful identical definitions are reused on reload; documentation changes do not change their logical identity.
Uninterned macro temporaries are compared using a canonical representation preserving their sharing.
A changed logical definition at the same name signals `definition-conflict`.

## Datatypes, recursion and records

```lisp
(defdatatype tree (?a)
  (leaf (value ?a))
  (node (left (tree ?a)) (right (tree ?a))))

(defun tree-size (tree)
  (declare (type (tree ?a) tree) (values num))
  (match tree
    ((leaf value) 1)
    ((node left right)
     (+ (tree-size left) (tree-size right)))))

(defthm tree-size-positive (tree)
  (declare (type (tree ?a) tree))
  (>= (tree-size tree) 1)
  (induct tree)
  (simp tree-size)
  (asm-arith))

(defstruct point (?a)
  (x ?a)
  (y ?a))
```

Fields contain exactly a name and a type. Their declared order is constructor argument order.
Datatype parameters are explicit, including `()` for ground types.
Recursive occurrences preserve that parameter list.
`defdatatypes` introduces a group sharing one parameter list.
The backend owns datatype construction, including supported nested recursion.
The frontend rejects duplicate fields/constructors, unused or undeclared parameters,
negative recursive fields and groups lacking a recognized constructor witness before calling the backend.
Recognized witness analysis includes empty lists; it is conservative for other nested type constructors.

Generated theorem names include `.induction`, `.recursion`, `.cases`,
`.injective` when constructors have fields, and `.distinct` when multiple constructors exist.
They are interned in the owner's package and are not automatically exported.
Individual constructor injectivity names remain pending.

A top-level exhaustive `match` with distinct constructor heads is lowered to recursion equations.
The datatype recursion principle is selected automatically.
Other recursion uses the original general existence procedure and must have closed existence evidence before introduction.
An optional `(declare (recursion tree.recursion))` selects a principle explicitly.
Explicit measure/relation and obligation-completion interfaces are not implemented yet.

`defequations` accepts named simultaneously required equations and an optional recursion declaration:

```lisp
(defequations tree-size-equations (tree)
  (declare (type (tree ?a) tree) (recursion tree.recursion))
  (leaf-case (x) (= (tree-size-equations (leaf x)) 1))
  (node-case (l r)
    (= (tree-size-equations (node l r))
       (+ (tree-size-equations l) (tree-size-equations r)))))
```

Pattern variables must be exactly the clause's explicit variable list.
Nullary constructors in patterns use `(constructor)`.
Coverage is checked; existence and compatibility are proved by the original procedures.
`defstruct` generates `make-point`, `point-x` and `point-y`, with position arguments and logical projection equations.
Record update syntax remains pending.

## Inductive relations

```lisp
(definductive even (n)
  (declare (type num n))
  (zero () (even 0))
  (step (k) (implies (even k) (even (+ k 2)))))

(defthm even-two ()
  (even (+ 0 2))
  (meson even.rules))
```

The relation lambda list describes its signature.
Each rule independently binds its explicit variables.
Its conclusion must be headed by the relation it declares.
`defrelations group ()` groups mutually inductive relation clauses of the same shape.
The complete group's signatures are shared during inference.
`prove_inductive_relations_exist` must return a theorem without residual monotonicity assumptions before constants are introduced.
Generated results include `.rules`, `.rules.label`, `.induction`, and `.cases`.
Group parameters, user monotonicity proofs, explicit strong induction and the set declaration wrapper remain pending.

## Proof steps and macros

Implemented steps include introduction, labeled assumptions, exact/apply, refl, split,
rewrite/asm-rewrite, simp/asm-simp, MESON, taut, arithmetic,
then/thenl, orelse/try, bounded progress-sensitive repeat, Boolean cases,
fix, witness, have, show, proof/by blocks, and inferred structural/natural induction.
`spec` theorem expressions and explicit global `ref` are available.
A local `have` cannot refer to itself while being proved.
`orelse` handles tactic failure, allowing name/type diagnostics to escape.
Batch proofs preserve the original interactive goal stack.
The complete keyword/position options, general theorem-expression language,
branch labels and additional automation adapters remain pending.

Ordinary `defmacro` and lexical `macrolet` can generate logical syntax.
Expansion preserves binders, type declarations, pattern labels and gensym identity.
Expansion is bounded; expanded terms undergo the same scope and type checks.
No automatic macro hygiene is claimed.
Handwritten procedural rule/tactic/conversion registration remains pending.

## State and verification

Errors derive from `dsl-error` and carry the offending form and underlying cause.
Unknown names, types, scope leaks, obligations and definition conflicts have condition subclasses.
If a backend definition call fails after entering the potentially mutating operation,
`kernel-state-uncertain` prevents further definitions until a clean restart.
The frontend does not claim rollback of the kernel or arbitrary host side effects.

Run `make test-user` or `(asdf:test-system "holai/user")`.
The current focused SBCL run passes 82 language checks and 68 definition checks.
The suite checks proofs, definitions, inference, independent packages,
constructor principles, recursion and induction, reload, macros and rejection cases.
It is separate from the original core differential and PROOF/reader suites.
The specification's remaining features include contexts/lemma, general mutual recursion,
subset/quotient/lifting, existence specification, custom simplification/computation resources,
interactive sessions, procedural proof extensions and full provenance/replay tooling.
These are implementation work remaining under v0.3, not completed APIs.

See [examples/user-dsl.lisp](../examples/user-dsl.lisp) for a compilable development.
