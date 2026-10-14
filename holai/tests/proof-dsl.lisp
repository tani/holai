(uiop:define-package :holai.proof-dsl-tests
  (:use :cl)
  (:import-from :holai.runtime :proof))
(in-package :holai.proof-dsl-tests)

(defparameter *proof-dsl-checks* 0)

(defun check-proof (test message)
  (incf *proof-dsl-checks*)
  (unless test (error "PROOF DSL check failed: ~a" message)))

(defun check-closed-proof (theorem expected message)
  (check-proof (null (holai.fusion:hyp theorem))
               (format nil "~a: no hypotheses" message))
  (check-proof (holai.fusion:aconv (holai.parser:parse_term expected)
                                  (holai.fusion:concl theorem))
               (format nil "~a: expected conclusion" message)))

(defun prove-proof (goal tactic)
  (holai.tactics:prove
    (holai.runtime:tuple (holai.parser:parse_term goal) tactic)))

(defun check-proof-syntax (form expected)
  (check-proof
    (handler-case (progn (macroexpand-1 form) nil)
      (simple-error (condition)
        (string= expected (apply #'format nil
                                (simple-condition-format-control condition)
                                (simple-condition-format-arguments condition)))))
    (format nil "syntax diagnostic for ~s" form)))

(check-closed-proof
  (prove-proof "!x:bool. x = x"
    (proof #'holai.tactics:GEN_TAC holai.tactics:THEN
           #'holai.tactics:REFL_TAC))
  "!x:bool. x = x" "universal reflexivity")

(check-closed-proof
  (prove-proof "p ==> p"
    (proof (holai.tactics:FAIL_TAC "first")
           #'holai.tactics:ORELSE holai.tactics:DISCH_TAC
           holai.tactics:THEN
           (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
  "p ==> p" "Failure fallback then assumption")

(check-closed-proof
  (prove-proof "p /\\ q ==> q /\\ p"
    (proof holai.tactics:DISCH_TAC holai.tactics:THEN
           #'holai.tactics:CONJ_TAC holai.tactics:THENL
      (list
        (holai.tactics:FIRST_ASSUM
          (holai.runtime:lambdac (th)
            (holai.runtime:funcall holai.tactics:ACCEPT_TAC
                                  (holai.runtime:funcall holai.bool:CONJUNCT2 th))))
        (holai.tactics:FIRST_ASSUM
          (holai.runtime:lambdac (th)
            (holai.runtime:funcall holai.tactics:ACCEPT_TAC
                                  (holai.runtime:funcall holai.bool:CONJUNCT1 th)))))))
  "p /\\ q ==> q /\\ p" "literal THENL branches")

(let ((branches
        (list
          (holai.tactics:FIRST_ASSUM
            (holai.runtime:lambdac (th)
              (holai.runtime:funcall holai.tactics:ACCEPT_TAC
                                    (holai.runtime:funcall holai.bool:CONJUNCT2 th))))
          (holai.tactics:FIRST_ASSUM
            (holai.runtime:lambdac (th)
              (holai.runtime:funcall holai.tactics:ACCEPT_TAC
                                    (holai.runtime:funcall holai.bool:CONJUNCT1 th)))))))
  (check-closed-proof
    (prove-proof "p /\\ q ==> q /\\ p"
      (proof holai.tactics:DISCH_TAC holai.tactics:THEN
             #'holai.tactics:CONJ_TAC holai.tactics:THENL branches))
    "p /\\ q ==> q /\\ p" "dynamic THENL branches"))

(check-closed-proof
  (prove-proof "p ==> p"
    (proof holai.tactics:DISCH_TAC #'holai.tactics:ORELSE
           (holai.tactics:FAIL_TAC "fallback") holai.tactics:THEN
           (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
  "p ==> p" "left association completes identity")

(check-proof
  (handler-case
    (progn
      (prove-proof "p ==> p"
        (proof holai.tactics:DISCH_TAC #'holai.tactics:ORELSE
          (proof (holai.tactics:FAIL_TAC "fallback")
                 holai.tactics:THEN
                 (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC))))
      nil)
    (holai.runtime:failure () t))
  "explicit right association leaves an unsolved goal")

(let ((saved (holai.runtime:deref holai.tactics:current_goalstack)))
  (unwind-protect
      (progn
        (holai.tactics:set_goal
          (holai.runtime:tuple nil (holai.parser:parse_term "p ==> p")))
        (holai.tactics:e (proof holai.tactics:DISCH_TAC))
        (let ((goal (holai.tactics:top_goal holai.runtime:unit))
              (goals (holai.runtime:snd
                       (first (holai.runtime:deref holai.tactics:current_goalstack)))))
          (check-proof
            (and (= 1 (length goals))
                 (= 1 (length (holai.runtime:fst goal)))
                 (holai.fusion:aconv (holai.parser:parse_term "p:bool")
                                     (first (holai.runtime:fst goal)))
                 (holai.fusion:aconv (holai.parser:parse_term "p:bool")
                                     (holai.runtime:snd goal)))
            "single operand interactive e leaves p as assumption and goal"))
        (holai.tactics:e (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC))
        (check-closed-proof (holai.tactics:top_thm holai.runtime:unit)
                            "p ==> p" "interactive identity"))
    (holai.runtime:assign holai.tactics:current_goalstack saved)))

(check-proof
  (handler-case
    (progn
      (prove-proof "T /\\ T"
        (proof #'holai.tactics:CONJ_TAC holai.tactics:THENL
          (list (holai.runtime:funcall holai.tactics:ACCEPT_TAC holai.bool:TRUTH))))
      nil)
    (holai.runtime:failure () t))
  "THENL rejects too few branches")

(check-proof
  (handler-case
    (progn (prove-proof "p ==> p" (proof holai.tactics:DISCH_TAC)) nil)
    (holai.runtime:failure () t))
  "prove rejects incomplete single operand")

(let ((bogus
        (holai.runtime:lambdac (goal)
          (holai.runtime:tuple holai.tactics:null_meta nil
            (holai.runtime:lambdac (inst ths)
              holai.bool:TRUTH)))))
  (check-proof
    (handler-case (progn (prove-proof "F" (proof bogus)) nil)
      (holai.runtime:failure () t))
    "prove rejects an actual TRUTH justification for F"))

(let ((finish (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
  (check-closed-proof
    (prove-proof "p ==> p"
      (proof holai.tactics:DISCH_TAC holai.tactics:THEN finish))
    "p ==> p" "lexical tactic capture"))

(let ((compose holai.tactics:THEN))
  (check-closed-proof
    (prove-proof "p ==> p"
      (proof holai.tactics:DISCH_TAC compose
             (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
    "p ==> p" "lexical function value operator"))

(let ((compose holai.tactics:THEN))
  (holai.runtime:fletc
      ((named-compose (left right) (holai.runtime:funcall compose left right)))
    (check-closed-proof
      (prove-proof "p ==> p"
        (proof holai.tactics:DISCH_TAC #'named-compose
               (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
      "p ==> p" "fletc named operator captures lexical THEN")))

;; Keep the source/local PROOF symbol distinct from the runtime macro.
(uiop:define-package :holai.proof-dsl-collision-tests
  (:use :cl))
(in-package :holai.proof-dsl-collision-tests)

(holai.runtime:fletc ((proof (tactic) tactic))
  (holai.proof-dsl-tests::check-closed-proof
    (holai.proof-dsl-tests::prove-proof "p ==> p"
      (holai.runtime:proof (proof holai.tactics:DISCH_TAC) holai.tactics:THEN
                           (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC)))
    "p ==> p" "separate local proof function and runtime macro"))

(in-package :holai.proof-dsl-tests)

(let ((trace nil)
      (expected '(:left-construct :right-construct :left-run :right-run)))
  (flet ((make-left ()
           (push :left-construct trace)
           (holai.runtime:lambdac (goal)
             (push :left-run trace)
             (holai.runtime:funcall holai.tactics:DISCH_TAC goal)))
         (make-right ()
           (push :right-construct trace)
           (holai.runtime:lambdac (goal)
             (push :right-run trace)
             (holai.runtime:funcall
               (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC) goal))))
    (check-closed-proof
      (prove-proof "p ==> p"
        (proof (make-left) holai.tactics:THEN (make-right)))
      "p ==> p" "trace DSL identity")
    (check-proof (equal expected (reverse trace)) "DSL constructs and runs each operand once")
    (let ((dsl-trace (copy-list trace)))
      (setf trace nil)
      (check-closed-proof
        (prove-proof "p ==> p"
          (holai.runtime:funcall holai.tactics:THEN (make-left) (make-right)))
        "p ==> p" "explicit call identity")
      (check-proof (and (equal expected (reverse trace)) (equal dsl-trace trace))
                   "explicit call has the same once-only trace")
      (let ((before (copy-list trace)))
        (macroexpand-1 '(proof (make-left) holai.tactics:THEN (make-right)))
        (check-proof (equal before trace) "macroexpansion does not evaluate operands")))))

(let ((right-runs 0))
  (check-proof
    (handler-case
      (progn
        (prove-proof "p ==> p"
          (proof
            (holai.runtime:lambdac (goal)
              (holai.runtime:invalid-arg "proof-dsl"))
            #'holai.tactics:ORELSE
            (holai.runtime:lambdac (goal)
              (incf right-runs)
              (holai.runtime:funcall holai.tactics:DISCH_TAC goal))))
        nil)
      (holai.runtime:invalid_argument () t))
    "ORELSE propagates Invalid_argument instead of catching it")
  (check-proof (zerop right-runs) "Invalid_argument does not run ORELSE fallback"))

(check-proof-syntax '(proof)
                     "PROOF: expected a tactic expression")
(check-proof-syntax '(proof holai.tactics:DISCH_TAC holai.tactics:THEN)
                     "PROOF: expected alternating operands and operator references")
(dolist (operator '(:then 42 (function (lambda (x) x)) (function)
                   (function holai.tactics:ORELSE extra) (function :then)
                   (function t) (function nil) t nil))
  (check-proof-syntax
    (list 'proof 'holai.tactics:DISCH_TAC operator
          'holai.tactics:DISCH_TAC)
    (format nil "PROOF: operator must be a value symbol or #'function-name: ~S" operator)))

(check-proof
  (null (macroexpand-1 '(proof nil)))
  "singleton NIL is valid operand syntax")
(check-proof
  (handler-case
    (progn (prove-proof "p ==> p" (proof nil)) nil)
    (error (condition) (not (typep condition 'holai.runtime:ocaml-condition))))
  "singleton NIL application fails at the existing nonfunction boundary")

(check-closed-proof
  (prove-proof "p ==> p"
    (proof #`holai.tactics:DISCH_TAC holai.tactics:THEN
           (holai.tactics:FIRST_ASSUM #`holai.tactics:ACCEPT_TAC)))
  "p ==> p" "sharp-backquote function-value operands close identity")

(let ((evaluations 0)
      (selected (lambda (x) (+ x 1))))
  (let ((call #`(progn (incf evaluations) selected)))
    (check-proof (zerop evaluations)
                 "sharp-backquote delays the function expression until invocation")
    (check-proof (= 11 (funcall call 10))
                 "sharp-backquote invokes the initial lexical function value")
    (check-proof (= 1 evaluations)
                 "sharp-backquote evaluates the function expression once per first call")
    (setf selected (lambda (x) (* x 2)))
    (check-proof (= 20 (funcall call 10))
                 "sharp-backquote observes lexical function-value rebinding")
    (check-proof (= 2 evaluations)
                 "sharp-backquote evaluates the function expression once per subsequent call")))

(let ((sum #'+)
      (decimal (lambda (hundreds tens units)
                 (+ (* hundreds 100) (* tens 10) units)))
      (classify (lambda (value) (if value :present :absent))))
  (check-proof (zerop (funcall #`sum))
               "sharp-backquote invokes a zero-argument function")
  (check-proof (= 123 (funcall #`decimal 1 2 3))
               "sharp-backquote preserves positional argument order")
  (check-proof (eq :absent (funcall #`classify nil))
               "sharp-backquote preserves an explicit NIL argument"))

(let ((divide #'floor))
  (check-proof (equal '(4 1) (multiple-value-list (funcall #`divide 9 2)))
               "sharp-backquote preserves quotient and remainder values"))

(let ((args 7))
  (let ((call #`(lambda (tens units) (+ args (* tens 10) units))))
    (check-proof (= 42 (funcall call 3 5))
                 "sharp-backquote argument binding does not capture source lexical ARGS")))

(flet ((selected (x) (+ x 100)))
  (let ((selected (lambda (x) (- x 1))))
    (check-proof (and (= 105 (funcall #'selected 5))
                      (= 4 (funcall #`selected 5)))
                 "standard sharp-quote named function coexists with sharp-backquote value")))

(let ((decimal (holai.runtime:lambdac (tens units) (+ (* tens 10) units))))
  (let ((partial (#`decimal 4)))
    (check-proof (functionp partial)
                 "reader-headed curried partial call returns a function")
    (check-proof (= 42 (#`partial 2))
                 "reader-headed call completes a lexical partial function")
    (check-proof (= 42 (#`decimal 4 2))
                 "reader-headed call supplies all curried arguments directly")))

(let ((trace nil)
      (evaluations 0)
      (selected (lambda (left right) (- left right))))
  (flet ((invoke (left right next)
           (#`(progn (incf evaluations) (push :head trace) selected)
             (progn (push :left trace) left)
             (progn (push :right trace) (setf selected next) right))))
    (check-proof (= 42 (invoke 4 2
                         (lambda (tens units) (+ (* tens 10) units))))
                 "reader-headed computed call acquires the function after arguments")
    (check-proof (= 42 (invoke 6 7 (lambda (left right) (* left right))))
                 "reader-headed computed call observes the next argument-time rebinding")
    (check-proof (= 2 evaluations)
                 "reader-headed computed expression is evaluated once per call")
    (check-proof (equal '(:left :right :head :left :right :head) (reverse trace))
                 "reader-headed calls evaluate arguments left-to-right before the head")))

(let ((divide #'floor))
  (check-proof (equal '(4 1) (multiple-value-list (#`divide 9 2)))
               "reader-headed direct call preserves quotient and remainder values"))

(format t "~&PROOF DSL checks passed: ~d~%" *proof-dsl-checks*)
