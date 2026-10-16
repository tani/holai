;; (asdf:load-system "holai/user"), then LOAD or COMPILE-FILE this file.
(defpackage :holai.examples.user
  (:use :cl :holai.user)
  (:shadowing-import-from :holai.user :defun :defconstant :deftype :defstruct)
  (:export :tree :leaf :node :tree-size :tree-size-positive :even :even-two))
(in-package :holai.examples.user)

(defmacro implies* (p q)
  `(implies ,p ,q))

(defthm implication-identity (p)
  "Every proposition implies itself."
  (declare (type bool p))
  (implies* p p)
  (assume h)
  (exact h))

(defun identity-function (x)
  "The polymorphic identity function."
  (declare (type ?a x))
  x)

(defthm boolean-identity (x)
  (declare (type bool x))
  (= (identity-function x) x)
  (simp identity-function))

(defdatatype tree (?a)
  "Binary trees with values at their leaves."
  (leaf (value ?a))
  (node (left (tree ?a)) (right (tree ?a))))

(defun tree-size (tree)
  "Count the leaves."
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

(defthm first-coordinate (x y)
  (declare (type ?a x y))
  (= (point-x (make-point x y)) x)
  (simp point-x))

(definductive even (n)
  (declare (type num n))
  (zero () (even 0))
  (step (k) (implies (even k) (even (+ k 2)))))

(defthm even-two ()
  (even (+ 0 2))
  (meson even.rules))
