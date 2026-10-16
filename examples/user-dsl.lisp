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
