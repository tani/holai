(in-package :holai.user)

(defvar *inductive-declarations* (make-hash-table :test #'equal))
(defvar *recursive-declarations* (make-hash-table :test #'equal))

(defun require-closed-theorem (theorem form)
  (unless (null (holai.fusion:hyp theorem))
    (reject form "Definition has unproved side conditions"))
  theorem)

(defun register-definition-results (name entries)
  ;; Validate the complete bundle before publishing any of its theorem names.
  (let* ((key (theorem-key name))
         (results (mapcar (lambda (entry)
                            (cons (concatenate 'string key (car entry))
                                  (require-closed-theorem (cdr entry) name)))
                          entries)))
    (dolist (entry results) (setf (gethash (car entry) *theorems*) (cdr entry)))
    (cdar entries)))

(defun clause-proposition (clauses form)
  (unless (and (proper-list-p clauses) clauses)
    (reject form "Expected at least one defining clause"))
  ;; One inference pass shares relation/function types across every clause.
  (read-term (reduce (lambda (left right) (list 'and left right))
                     clauses :from-end t)
             :expected-type 'bool))

(defun register-inductive-results (name results)
  (destructuring-bind (rules induction cases) (holai.runtime.data:tuple-items results)
    (register-definition-results name
      (list (cons "" rules) (cons ".rules" rules)
            (cons ".induction" induction) (cons ".cases" cases))))
  results)

(defun define-inductive (name clauses)
  (let* ((key (theorem-key name))
         (cached (gethash key *inductive-declarations*)))
    ;; Rechecking an already defined relation as a fresh predicate would treat
    ;; it as a constant. Reuse only a previously successful identical declaration.
    (when (and cached (equal clauses (car cached)))
      (return-from define-inductive (register-inductive-results name (cdr cached)))))
  (call-with-dsl-context clauses
    (lambda ()
      (let ((proposition (clause-proposition clauses clauses)))
        ;; HOL Light can return residual monotonicity assumptions. Reject those
        ;; before introducing the relation constants, rather than registering
        ;; conditional introduction or induction theorems as completed results.
        (require-closed-theorem
          (funcall holai.ind_defs:prove_inductive_relations_exist proposition) clauses)
        (let ((results (funcall holai.ind_defs:new_inductive_definition proposition)))
          (register-inductive-results name results)
          (setf (gethash (theorem-key name) *inductive-declarations*)
                (cons (copy-tree clauses) results))
          results)))))

(defmacro definductive (name &body clauses)
  "Define a least inductive relation (or a group of mutually inductive relations)."
  `(define-inductive ',name ',clauses))

(defun register-recursive-result (name result)
  (register-definition-results name
    (list (cons "" result) (cons ".equations" result))))

(defun define-recursive (name clauses)
  (let* ((key (theorem-key name))
         (cached (gethash key *recursive-declarations*)))
    (when (and cached (equal clauses (car cached)))
      (return-from define-recursive (register-recursive-result name (cdr cached)))))
  (call-with-dsl-context clauses
    (lambda ()
      (let* ((explicit (and (consp clauses) (consp (car clauses))
                            (eq (caar clauses) :recursion)))
             (recursion
               (when explicit
                 (require-arity (car clauses) (cdar clauses) 1)
                 (require-closed-theorem (theorem (second (car clauses))) (car clauses))))
             (equations (clause-proposition (if explicit (cdr clauses) clauses) clauses))
             (result (if explicit
                         (funcall holai.recursion:new_recursive_definition recursion equations)
                         (funcall holai.define:define equations))))
        (register-recursive-result name result)
        (setf (gethash (theorem-key name) *recursive-declarations*)
              (cons (copy-tree clauses) result))
        result))))

(defmacro defrecursive (name &body clauses)
  "Define a function by equations, optionally starting with (:recursion theorem)."
  `(define-recursive ',name ',clauses))

(defun declaration-identifier (syntax)
  (let ((text (name-text syntax)))
    (flet ((letter-p (character)
             (or (find character "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_") nil)))
      (unless (and (plusp (length text)) (letter-p (char text 0))
                   (every (lambda (character)
                            (or (letter-p character) (digit-char-p character)
                                (char= character #\')))
                          text))
        (reject syntax "Expected a HOL identifier (letters, digits, underscore or prime)")))
    (when (and (symbolp syntax)
               (or (member syntax '(t nil))
                   (assoc text *term-aliases* :test #'string=)
                   (member text '("forall" "exists" "exists1" "lambda" "the")
                           :test #'string=)))
      (reject syntax "Reserved DSL name"))
    text))

(defun datatype-field-type (syntax self)
  ;; Preserve the recursive placeholder even when a prior identical declaration
  ;; has already registered SELF as a parameterized type operator.
  (cond
    ((and (or (symbolp syntax) (stringp syntax)) (string= (name-text syntax) self))
     (holai.fusion:mk_vartype self))
    ((and (consp syntax) (proper-list-p syntax))
     (let ((name (name-text (car syntax)))
           (fields (mapcar (lambda (field) (datatype-field-type field self))
                           (cdr syntax))))
       (when (string= name self)
         (reject syntax "Use the bare recursive type name; parameters are inferred"))
       (if (string= name "->")
           (progn
             (unless (>= (length fields) 2) (reject syntax "An arrow needs two types"))
             (reduce #'holai.fusion:mk_fun_ty fields :from-end t))
           (holai.fusion:mk_type (tuple (declaration-identifier (car syntax)) fields)))))
    (t (hol-type syntax))))

(defun datatype-field-text (syntax self)
  (format nil "(~a)"
          (funcall holai.printer:string_of_type (datatype-field-type syntax self))))

(defun datatype-specification (name constructors)
  (let ((type-name (declaration-identifier name)))
    (unless (and (proper-list-p constructors) constructors)
      (reject constructors "A datatype needs at least one constructor"))
    (let ((names nil)
          (has-fields nil)
          (clauses nil))
      (dolist (constructor constructors)
        (let* ((parts (if (or (symbolp constructor) (stringp constructor))
                          (list constructor) constructor)))
          (unless (and (proper-list-p parts) parts)
            (reject constructor "Expected a constructor name followed by field types"))
          (let ((constructor-name (declaration-identifier (first parts))))
            (when (member constructor-name names :test #'string=)
              (reject constructor "Duplicate constructor name"))
            (push constructor-name names)
            (when (cdr parts) (setf has-fields t))
            (push (format nil "~a~{ ~a~}" constructor-name
                          (mapcar (lambda (field) (datatype-field-text field type-name))
                                  (rest parts))) clauses))))
      (values (format nil "~a = ~{~a~^ | ~}" type-name (nreverse clauses))
              type-name (length constructors) has-fields))))

(defun define-datatype (name constructors)
  (call-with-dsl-context constructors
    (lambda ()
      (multiple-value-bind (specification type-name count has-fields)
          (datatype-specification name constructors)
        (let* ((results (holai.ind_types:define_type specification))
               (induction (fst results)) (recursion (snd results))
               (entries
                 (list (cons "" induction) (cons ".induction" induction)
                       (cons ".recursion" recursion)
                       (cons ".cases" (holai.ind_types:cases type-name)))))
          (when (> count 1)
            (setf entries (append entries
                                 (list (cons ".distinct"
                                             (holai.ind_types:distinctness type-name))))))
          (when has-fields
            (setf entries (append entries
                                 (list (cons ".injective"
                                             (holai.ind_types:injectivity type-name))))))
          (register-definition-results name entries)
          results)))))

(defmacro defdatatype (name &body constructors)
  "Define a HOL algebraic datatype; free field type variables become parameters."
  `(define-datatype ',name ',constructors))
