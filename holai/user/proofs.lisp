(in-package :holai.user)

(defvar *theorems* (make-hash-table :test #'equal))

(defun theorem-key (name)
  (unless (or (symbolp name) (stringp name))
    (reject name "Expected a theorem name"))
  ;; DSL names are independent of the host package of an unqualified symbol.
  (name-text name))

(defun theorem (name)
  "Look up a DSL theorem or an explicitly qualified generated theorem symbol."
  (or (gethash (theorem-key name) *theorems*)
      (when (and (symbolp name) (boundp name)
                 (let ((package (symbol-package name)))
                   (and package
                        (uiop:string-prefix-p "HOLAI." (package-name package)))))
        (let ((value (symbol-value name)))
          ;; Observation uses the public kernel API, never private constructors.
          (handler-case (progn (holai.fusion:concl value) value)
            (holai.runtime.core:failure () nil))))
      (reject name "Unknown theorem")))

(defun goal-theorem (name goal)
  (let ((label (theorem-key name)))
    (or (loop for entry in (fst goal)
              when (string= label (fst entry)) return (snd entry))
        (theorem name))))

(defun goal-variables (goal)
  (holai.fusion:freesl
    (cons (snd goal) (mapcar (lambda (entry) (holai.fusion:concl (snd entry)))
                           (fst goal)))))

(defun goal-term (syntax goal &optional expected-type)
  (read-term syntax :expected-type expected-type :variables (goal-variables goal)))

(defun sequence-tactics (commands)
  ;; THEN applies each following command to every remaining subgoal.
  (reduce (lambda (left right) (funcall holai.tactics:THEN left right))
          (mapcar #'command-tactic commands) :initial-value #'holai.tactics:ALL_TAC))

(defun theorem-list-tactic (names constructor)
  (lambda (goal)
    (funcall (funcall constructor
                     (mapcar (lambda (name) (goal-theorem name goal)) names)) goal)))

(defun command-tactic (command)
  (let* ((form (if (and command (symbolp command)) (list command) command)))
    (unless (and (consp form) (proper-list-p form) (symbolp (car form)))
      (reject command "Expected a proof command"))
    (let ((operator (name-text (car form))) (arguments (cdr form)))
      (cond
        ((member operator '("intro" "intros" "assumption" "refl" "split" "taut"
                            "arith" "asm-arith" "skip" "fail") :test #'string=)
         (require-arity command arguments 0)
         (cond
           ((string= operator "intro")
            (holai.tactics:ORELSE #'holai.tactics:GEN_TAC holai.tactics:DISCH_TAC))
           ((string= operator "intros")
            (holai.tactics:REPEAT (command-tactic 'intro)))
           ((string= operator "assumption")
            (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC))
           ((string= operator "refl") #'holai.tactics:REFL_TAC)
           ((string= operator "split") #'holai.tactics:CONJ_TAC)
           ((string= operator "taut") holai.itab:ITAUT_TAC)
           ((string= operator "arith") holai.int:ARITH_TAC)
           ((string= operator "asm-arith") holai.int:ASM_ARITH_TAC)
           ((string= operator "skip") #'holai.tactics:ALL_TAC)
           (t holai.tactics:NO_TAC)))
        ((string= operator "assume")
         (require-arity command arguments 1)
         (holai.tactics:DISCH_THEN
           (holai.tactics:LABEL_TAC (theorem-key (first arguments)))))
        ((member operator '("exact" "apply") :test #'string=)
         (require-arity command arguments 1)
         (lambda (goal)
           (let ((th (goal-theorem (first arguments) goal)))
             (funcall (if (string= operator "exact")
                          (funcall holai.tactics:MATCH_ACCEPT_TAC th)
                          (holai.tactics:MATCH_MP_TAC th)) goal))))
        ((member operator '("rewrite" "asm-rewrite" "simp" "asm-simp" "meson")
                 :test #'string=)
         (theorem-list-tactic
           arguments
           (cond ((string= operator "rewrite") #'holai.simp:REWRITE_TAC)
                 ((string= operator "asm-rewrite") holai.simp:ASM_REWRITE_TAC)
                 ((string= operator "simp") #'holai.simp:SIMP_TAC)
                 ((string= operator "asm-simp") holai.simp:ASM_SIMP_TAC)
                 (t holai.meson:ASM_MESON_TAC))))
        ((string= operator "then") (sequence-tactics arguments))
        ((string= operator "thenl")
         (unless arguments (reject command "THENL needs a tactic and its branches"))
         (funcall holai.tactics:THENL (command-tactic (first arguments))
                  (mapcar #'command-tactic (rest arguments))))
        ((string= operator "orelse")
         (require-arity command arguments 2)
         (holai.tactics:ORELSE (command-tactic (first arguments))
                              (command-tactic (second arguments))))
        ((member operator '("try" "repeat") :test #'string=)
         (require-arity command arguments 1)
         (let ((tactic (command-tactic (first arguments))))
           (if (string= operator "try")
               (holai.tactics:ORELSE tactic #'holai.tactics:ALL_TAC)
               (holai.tactics:REPEAT tactic))))
        ((string= operator "cases")
         (require-arity command arguments 1)
         (lambda (goal)
           (funcall (holai.class:BOOL_CASES_TAC
                      (goal-term (first arguments) goal 'bool)) goal)))
        ((string= operator "induct")
         (require-arity command arguments 0 1)
         (if (null arguments)
             holai.nums:INDUCT_TAC
             (lambda (goal)
               (funcall
                 (funcall holai.tactics:THEN
                   (holai.tactics:MATCH_MP_TAC (goal-theorem (first arguments) goal))
                   (holai.tactics:REPEAT #'holai.tactics:STRIP_TAC)) goal))))
        ((string= operator "fix")
         (require-arity command arguments 1)
         (let ((name (name-text (first arguments))))
           (binder-preterm (first arguments))
           (lambda (goal)
             (let ((variable (fst (funcall holai.basics:dest_forall (snd goal)))))
               (funcall (funcall holai.tactics:X_GEN_TAC
                          (holai.fusion:mk_var (tuple name (holai.fusion:type_of variable))))
                        goal)))))
        ((string= operator "witness")
         (require-arity command arguments 1)
         (lambda (goal)
           (let* ((variable (fst (funcall holai.basics:dest_exists (snd goal))))
                  (type (holai.fusion:type_of variable))
                  (witness (funcall term_of_preterm
                             (funcall retypecheck
                               (mapcar (lambda (v)
                                         (tuple (fst (holai.fusion:dest_var v))
                                                (pretype_of_type (holai.fusion:type_of v))))
                                       (goal-variables goal))
                               (make-Typing (syntax-preterm (first arguments))
                                            (pretype_of_type type))))))
             (funcall (funcall holai.tactics:EXISTS_TAC witness) goal))))
        ((string= operator "have")
         (unless (>= (length arguments) 3)
           (reject command "HAVE needs a label, proposition and proof commands"))
         (let ((label (theorem-key (first arguments)))
               (proof (sequence-tactics (cddr arguments))))
           (lambda (goal)
             (funcall
               (funcall holai.tactics:THENL
                 (holai.tactics:SUBGOAL_THEN
                   (goal-term (second arguments) goal 'bool)
                   (holai.tactics:LABEL_TAC label))
                 (list proof #'holai.tactics:ALL_TAC)) goal))))
        (t (reject command "Unknown proof command ~a" operator))))))

(defun prove-term (statement commands)
  "Infer a proposition and execute proof commands, requiring a closed kernel theorem."
  (unless (proper-list-p commands) (reject commands "Expected a list of proof commands"))
  (call-with-dsl-context statement
    (lambda ()
      (holai.tactics:prove
        (tuple (read-term statement :expected-type 'bool)
               (sequence-tactics commands))))))

(defmacro prove (statement &body commands)
  `(prove-term ',statement ',commands))

(defmacro defthm (name statement &body commands)
  "Register NAME only after proving the entire statement without open hypotheses."
  `(setf (gethash (theorem-key ',name) *theorems*)
         (prove-term ',statement ',commands)))

(defun define-term (name statement)
  (call-with-dsl-context statement
    (lambda ()
      (let* ((key (theorem-key name))
             (definition (funcall holai.pair:new_definition
                                 (read-term statement :expected-type 'bool))))
        (setf (gethash key *theorems*) definition)))))

(defmacro defhol (name statement)
  "Introduce a conservative HOL definition and register its defining theorem."
  `(define-term ',name ',statement))
