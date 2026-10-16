(uiop:define-package :holai.user
  (:nicknames :holai-user)
  (:use :cl)
  (:import-from :holai.runtime.data :tuple :fst :snd)
  (:import-from :holai.preterm
    :dpty :make-Varp :make-Combp :make-Absp :make-Typing :make-Ptycon
    :pretype_of_type :retypecheck :term_of_preterm)
  (:export :term :read-term :hol-type :prove :prove-term :defthm :defhol
           :definductive :defrecursive :defdatatype
           :theorem :dsl-error :dsl-error-form :dsl-error-cause))
(in-package :holai.user)

(define-condition dsl-error (error)
  ((form :initarg :form :reader dsl-error-form)
   (cause :initarg :cause :reader dsl-error-cause))
  (:report (lambda (condition stream)
             (format stream "HOL DSL error in ~s: ~a"
                     (dsl-error-form condition)
                     (let ((cause (dsl-error-cause condition)))
                       (if (typep cause 'holai.runtime.core:failure)
                           (holai.runtime.core:exception-string cause) cause))))))

(defun reject (form control &rest arguments)
  (error 'dsl-error :form form :cause (apply #'format nil control arguments)))

(defun call-with-dsl-context (form thunk)
  (handler-case (funcall thunk)
    (dsl-error (condition) (error condition))
    (holai.runtime.core:failure (condition)
      (error 'dsl-error :form form :cause condition))))

(defun name-text (name)
  (cond ((symbolp name) (string-downcase (symbol-name name)))
        ((stringp name) name)
        (t (reject name "Expected a name"))))

(defun proper-list-p (form)
  ;; LIST-LENGTH detects cycles as well as rejecting dotted lists.
  (and (listp form)
       (handler-case (or (null form) (list-length form))
         (type-error () nil))))

(defun require-arity (form arguments minimum &optional (maximum minimum))
  (unless (and (proper-list-p arguments)
               (<= minimum (length arguments) maximum))
    (reject form "Expected ~d~@[ to ~d~] arguments" minimum
            (unless (= minimum maximum) maximum))))
