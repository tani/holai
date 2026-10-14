(uiop:define-package :holai.runtime.data
  (:use :cl)
  (:export :tuple :tuple-items :tuple-ref :unit :match-failure :ocaml-condition
    :raise :ref :ref-contents :deref :assign :fst :snd
    :unit-value :unit-value-p :tuple-value :tuple-value-p :ref-cell :ref-cell-p))
(in-package :holai.runtime.data)

(defstruct (unit-value (:constructor make-unit-value ())))
(defparameter unit (make-unit-value))
(defstruct (tuple-value (:constructor make-tuple-value (items)))
  (items nil :type list :read-only t))
(defun tuple (&rest items) (make-tuple-value items))
(defun tuple-items (tuple) (tuple-value-items tuple))
(defun tuple-ref (tuple i)
  (let ((items (tuple-items tuple)))
    (unless (and (integerp i) (cl:<= 0 i) (cl:< i (length items)))
      (error 'type-error :datum i :expected-type `(integer 0 (,(length items)))))
    (nth i items)))
(defun fst (tuple) (tuple-ref tuple 0))
(defun snd (tuple) (tuple-ref tuple 1))

(defstruct (ref-cell (:constructor ref (value))) value)
(defun deref (cell) (ref-cell-value cell))
(defun assign (cell value) (setf (ref-cell-value cell) value) unit)
(define-condition ocaml-condition (error) ())
(define-condition match-failure (ocaml-condition) ())
(defun match-failure () (error 'match-failure))
(defun raise (condition) (error condition))
