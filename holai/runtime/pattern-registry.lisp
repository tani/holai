(uiop:define-package :holai.runtime.pattern-registry
  (:use :cl)
  (:export :*pattern-descriptions* :register-pattern-family :check-pattern-signature
    :pattern-declaration-changed :pattern-declaration-name))
(in-package :holai.runtime.pattern-registry)

;; Declarations and their load-time ABI guards share one canonical registry.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *pattern-descriptions* (make-hash-table :test #'eq))
  (defvar *pattern-families* (make-hash-table :test #'eq))
  (define-condition pattern-declaration-changed (simple-error)
    ((name :initarg :name :reader pattern-declaration-name)))
  (defun register-pattern-family (owner descriptions)
    (dolist (name (gethash owner *pattern-families*))
      (remhash name *pattern-descriptions*))
    (setf (gethash owner *pattern-families*) (mapcar #'car descriptions))
    (dolist (description descriptions)
      (setf (gethash (car description) *pattern-descriptions*) (cdr description))))
  (defun check-pattern-signature (name signature)
    (unless (equal signature (gethash name *pattern-descriptions*))
      (error 'pattern-declaration-changed :name name
             :format-control "Pattern declaration changed for ~s; rebuild dependent FASLs"
             :format-arguments (list name)))
    t))
