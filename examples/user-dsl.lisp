;; Load (asdf:load-system "holai/user") before loading this development.
(in-package :holai.user)

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

(defthm branching-example
  (and true (implies p p))
  (thenl split
    (exact holai.bool:TRUTH)
    (then intro assumption)))

(defthm local-lemma-example
  (implies p p)
  (assume h)
  (have local-p p (exact h))
  (exact local-p))

(defthm inferred-witness
  (forall ((x :type num)) (exists (y) (= y x)))
  intro
  (witness x)
  refl)

(defhol identity-definition
  (= (user_identity x) x))

(defthm boolean-identity
  (forall ((x :type bool)) (= (user_identity x) x))
  (rewrite identity-definition))

(defthm natural-add-zero
  (forall ((n :type num)) (= (+ n 0) n))
  (arith))

(defdatatype user_tree
  (user_leaf a)
  (user_node user_tree user_tree))

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

(definductive user-even
  (user_even 0)
  (forall (n) (implies (user_even n) (user_even (+ n 2)))))

(defthm even-step-example
  (user_even (+ 0 2))
  (meson user-even.rules))

(defrecursive natural-copy
  (= (user_copy 0) 0)
  (forall (n) (= (user_copy ("SUC" n)) ("SUC" (user_copy n)))))

(defthm natural-copy-identity
  (forall ((n :type num)) (= (user_copy n) n))
  induct
  (asm-rewrite natural-copy))
