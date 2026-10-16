(in-package :holai.user)

(defparameter *term-aliases*
  '(("true" . "T") ("false" . "F") ("and" . "/\\")
    ("or" . "\\/") ("not" . "~") ("implies" . "==>")
    ("iff" . "<=>") ("if" . "COND")))

(defun term-name (name)
  (cond ((eq name t) "T")
        ((null name) "F")
        ((symbolp name)
         (let ((text (name-text name)))
           (or (cdr (assoc text *term-aliases* :test #'string=)) text)))
        ((stringp name) name)
        (t (reject name "Expected a HOL identifier"))))

(defun type-preterm (syntax)
  (cond
    ((or (symbolp syntax) (stringp syntax))
     (pretype_of_type (holai.parser:parse_type (name-text syntax))))
    ((and (consp syntax) (proper-list-p syntax))
     (let ((name (name-text (car syntax))) (arguments (cdr syntax)))
       (if (string= name "->")
           (progn
             (unless (>= (length arguments) 2)
               (reject syntax "An arrow type needs at least two types"))
             (reduce (lambda (domain range) (make-Ptycon "fun" (list domain range)))
                     (mapcar #'type-preterm arguments) :from-end t))
           (make-Ptycon name (mapcar #'type-preterm arguments)))))
    (t (reject syntax "Expected a type name, HOL type string or type application"))))

(defun hol-type (syntax)
  "Elaborate a type name, HOL type string, (-> A B ...) or (constructor A ...)."
  (call-with-dsl-context syntax
    (lambda () (funcall holai.preterm:type_of_pretype (type-preterm syntax)))))

(defun parse-preterm-string (text)
  (let ((parsed (funcall holai.parser:parse_preterm
                  (funcall holai.parser:lex (holai.lib:explode text)))))
    (unless (null (snd parsed))
      (reject text "Unparsed input following term"))
    (fst parsed)))

(defun apply-preterms (head arguments)
  (reduce #'make-Combp arguments :initial-value head))

(defun binder-preterm (syntax)
  (cond
    ((or (symbolp syntax) (stringp syntax))
     (let ((name (name-text syntax)))
       (when (or (eq syntax t) (null syntax) (zerop (length name)))
         (reject syntax "Expected a variable name"))
       (when (and (symbolp syntax) (assoc name *term-aliases* :test #'string=))
         (reject syntax "Reserved term alias; use a different variable name"))
       (make-Varp name dpty)))
    ((and (proper-list-p syntax) (= (length syntax) 3)
          (eq (second syntax) :type))
     (make-Typing (binder-preterm (first syntax)) (type-preterm (third syntax))))
    (t (reject syntax "Expected a variable or (variable :type type)"))))

(defun bind-preterms (operator binders body form)
  (unless (and (proper-list-p binders) binders)
    (reject form "A binder needs a nonempty list of variables"))
  (let ((names (mapcar (lambda (binder)
                        (name-text (if (consp binder) (first binder) binder)))
                      binders)))
    (unless (= (length names) (length (remove-duplicates names :test #'string=)))
      (reject form "Duplicate variables in one binder")))
  (reduce (lambda (variable result)
            (let ((abstraction (make-Absp (binder-preterm variable) result)))
              (if operator (make-Combp (make-Varp operator dpty) abstraction)
                  abstraction)))
          binders :from-end t :initial-value (syntax-preterm body)))

(defun syntax-preterm (syntax)
  (cond
    ((stringp syntax) (parse-preterm-string syntax))
    ((symbolp syntax) (make-Varp (term-name syntax) dpty))
    ((and (integerp syntax) (not (minusp syntax)))
     (make-Varp (write-to-string syntax :base 10 :radix nil) dpty))
    ((and (consp syntax) (proper-list-p syntax))
     (let* ((head (car syntax)) (arguments (cdr syntax))
            (operator (and (symbolp head) (name-text head))))
       (cond
         ((member operator '("forall" "exists" "exists1" "lambda") :test #'equal)
          (require-arity syntax arguments 2)
          (bind-preterms (cdr (assoc operator '(("forall" . "!") ("exists" . "?")
                                               ("exists1" . "?!") ("lambda" . nil))
                                    :test #'string=))
                         (first arguments) (second arguments) syntax))
         ((equal operator "the")
          (require-arity syntax arguments 2)
          (make-Typing (syntax-preterm (second arguments))
                       (type-preterm (first arguments))))
         ((eq (second syntax) :type)
          (require-arity syntax arguments 2)
          (make-Typing (syntax-preterm head) (type-preterm (third syntax))))
         (t
          (unless arguments (reject syntax "An application needs an argument"))
          (when (and (symbolp head)
                     (member (name-text head)
                             '("and" "or" "implies" "iff" "=" "if" "not")
                             :test #'string=))
            (require-arity syntax arguments
                           (cond ((equal operator "if") 3)
                                 ((equal operator "not") 1) (t 2))))
          (apply-preterms (syntax-preterm head) (mapcar #'syntax-preterm arguments))))))
    (t (reject syntax "Expected a term, nonnegative numeral or HOL term string"))))

(defun read-term (syntax &key expected-type variables)
  "Infer a HOL term as a whole, optionally constrained by a type and HOL variables."
  (call-with-dsl-context syntax
    (lambda ()
      (let* ((preterm (syntax-preterm syntax))
             (constrained (if expected-type
                              (make-Typing preterm (type-preterm expected-type)) preterm))
             (environment
               (mapcar (lambda (variable)
                         (tuple (fst (holai.fusion:dest_var variable))
                                (pretype_of_type (holai.fusion:type_of variable))))
                       variables)))
        (funcall term_of_preterm (funcall retypecheck environment constrained))))))

(defmacro term (syntax)
  "Literal HOL term notation. Syntax is data, never a Common Lisp expression."
  `(read-term ',syntax))
