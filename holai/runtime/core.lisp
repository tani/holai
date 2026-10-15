(uiop:define-package :holai.runtime.core
  (:use :cl)
  (:shadow :compare :partial := :< :> :<= :>= :Some)
  (:import-from :holai.runtime.data
    :tuple :tuple-items :unit :ocaml-condition :raise :ref :deref :assign
    :tuple-value :tuple-value-p :ref-cell :ref-cell-p :unit-value-p)
  (:import-from :holai.runtime.pattern-registry
    :*pattern-descriptions* :register-pattern-family)
  ;; Keep the compiler phase available before declaration macros are loaded.
  (:import-from :holai.runtime.pattern)
  (:export :defunc :lambdac :labelsc :fletc :proof :function-value :partial
    :define-exception :defvariant :variant-value :variant-tag :variant-fields :variant-type
    := :<> :== :!= :compare :< :> :<= :>=
    :failure :invalid_argument :end_of_file :sys_error :failwith
    :make-failure :make-invalid_argument :make-sys_error :make-end_of_file
    :Some :None :make-Some :make-None :invalid-arg
    :int-div :int-mod :string-concat :string-length :string-sub :string-join :string-get
    :num :numdom :gcd-num :abs-num :power-num :quo-num :mod-num :int-of-num
    :string-of-num :string-of-int :string-of-float :cpu-time :exception-string :structural-hash
    :open-in :open-in-bin :open-out :input-line :close-channel :output-string :channel-length
    :really-input-string :char-chr :string-make :string-escaped :int-of-string
    :array-make :array-get :array-set :list-fold-left :list-exists :bool-or :bool-and
    :defrecord :record-field :record-update :record-assign :Not_found :make-Not_found
    :record-value :record-value-p :record-value-type :record-value-fields :record-fields
    :*record-descriptions* :variant-value-constant-p))
(in-package :holai.runtime.core)


;; Curried source functions receive their known prefix as optional parameters.
;; Only excess arguments need a rest list; supplied-p distinguishes NIL/omission.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun sharp-backquote-lambda-reader (stream subchar arg)
    (declare (ignore subchar arg))
    (let ((fn-expr (read stream t nil t))
          (args (gensym "ARGS")))
      `(cl:lambda (&rest ,args)
         (cl:apply ,fn-expr ,args))))

  (set-dispatch-macro-character #\# #\` #'sharp-backquote-lambda-reader)

  (defun expand-proof (expression)
    (unless expression
      (error "PROOF: expected a tactic expression"))
    (unless (oddp (length expression))
      (error "PROOF: expected alternating operands and operator references"))
    (cl:labels ((operator-symbol-p (symbol)
                  (and (symbolp symbol)
                       (not (keywordp symbol))
                       (not (eq symbol cl:t))
                       (not (eq symbol cl:nil)))))
      (let ((result (car expression)))
        (loop for (operator operand) on (cdr expression) by #'cddr
              do (setf result
                       (cond
                         ((operator-symbol-p operator)
                          `(funcall ,operator ,result ,operand))
                         ((and (consp operator)
                               (eq (car operator) 'cl:function)
                               (consp (cdr operator))
                               (null (cddr operator))
                               (operator-symbol-p (cadr operator)))
                          `(,(cadr operator) ,result ,operand))
                         (t
                          (error "PROOF: operator must be a value symbol or #'function-name: ~S"
                                 operator)))))
        result)))

  (defun curried-definition (parameters body self)
    (let* ((tail (gensym "EXCESS")) (result (gensym "RESULT"))
           (supplied (mapcar (lambda (p) (declare (ignore p))
                              (gensym "SUPPLIED")) parameters))
           (complete
             `(let ((,result (progn ,@body)))
                (if ,tail
                    (if (cl:functionp ,result)
                        (cl:apply ,result ,tail)
                        (cl:error 'cl:type-error :datum ,result :expected-type 'cl:function))
                    ,result))))
      (values
        `(,@(when parameters
              `(&optional ,@(mapcar (lambda (p flag) `(,p nil ,flag))
                                    parameters supplied)))
          &rest ,tail)
        (if (null parameters) complete
            `(if ,(car (last supplied)) ,complete
                 (cond
                   ,@(loop for flag in supplied
                           for count from 0
                           collect `((not ,flag)
                                     (partial ,self ,@(subseq parameters 0 count)))))))))))

(defmacro lambdac (parameters &body body)
  (let ((self (gensym "CURRIED")))
    (multiple-value-bind (arguments expression)
        (curried-definition parameters body `(cl:function ,self))
      `(cl:labels ((,self ,arguments (declare (ignorable ,@parameters)) ,expression)) (cl:function ,self)))))

(defmacro defunc (name parameters &body body)
  ;; Construct one self-contained function object at definition time. Partial
  ;; closures retain that object even if the global function is later replaced.
  (multiple-value-bind (arguments expression)
      (curried-definition parameters body `(cl:function ,name))
    `(progn
       (cl:declaim (cl:ftype (cl:function (&rest cl:t) *) ,name))
       (setf (cl:fdefinition ',name)
             (cl:labels ((,name ,arguments (declare (ignorable ,@parameters)) ,expression)) (cl:function ,name)))
       ',name)))

(defmacro labelsc (definitions &body body)
  `(cl:labels
     ,(mapcar (lambda (definition)
                (destructuring-bind (name parameters &rest forms) definition
                  (multiple-value-bind (arguments expression)
                      (curried-definition parameters forms `(cl:function ,name))
                    `(,name ,arguments (declare (ignorable ,@parameters)) ,expression)))) definitions)
     ,@body))

(defmacro fletc (definitions &body body)
  ;; Initializers stay outside the new flet scope, as for nonrecursive OCaml RHSs.
  (let ((cells (mapcar (lambda (definition) (declare (ignore definition))
                        (gensym "LOCAL-FUNCTION")) definitions)))
    `(let ,(mapcar (lambda (definition cell)
                    (destructuring-bind (name parameters &rest forms) definition
                      (declare (ignore name)) `(,cell (lambdac ,parameters ,@forms))))
                  definitions cells)
       (cl:flet ,(mapcar (lambda (definition cell)
                          (destructuring-bind (name parameters &rest forms) definition
                            (declare (ignore forms))
                            (multiple-value-bind (arguments expression)
                                (curried-definition parameters
                                  (list `(funcall ,cell ,@parameters)) cell)
                              `(,name ,arguments (declare (ignorable ,@parameters)) ,expression)))) definitions cells)
         ,@body))))

;; Operands remain ordinary Lisp forms; only the intervening operators expand.
(defmacro proof (&rest expression)
  (expand-proof expression))

(defun partial (function &rest initial)
  (lambda (&rest rest) (cl:apply function (append initial rest))))

;; Only fixed-arity foreign functions use adapters. Neither the native function
;; nor its adapter may be retained by this cache. Generated entries bypass it.
#+mkcl
(ffi:clines
 "#include <mkcl/gc/gc.h>"
 "static void *holai_weak_read(void *cell) { return *(void **)cell; }")
#+mkcl
(defun make-mkcl-weak-pointer (value)
  ;; MKCL 1.1.11 has no Lisp weak-pointer API. The cell is collector-owned
  ;; atomic memory: its contents are not traced. The foreign wrapper roots the
  ;; cell, not the referent. Boehm removes the link when either object dies;
  ;; never explicitly free a registered cell. Static objects need no link.
  (ffi:c-inline (value) (t) t
    "{ void **cell = (void **)mkcl_alloc_atomic(env, sizeof(void *));
       void *base = MK_GC_base((void *)#0);
       *cell = (void *)#0;
       if (base && MK_GC_general_register_disappearing_link(cell, base) != MK_GC_SUCCESS)
         mkcl_FEerror(env, \"Cannot register adapter weak pointer\", 0);
       @(return) = mkcl_make_foreign(env, mk_cl_Cnil, sizeof(void *), cell);
     }"
    :one-liner nil :side-effects t))
#+mkcl
(defun mkcl-weak-pointer-value (pointer)
  ;; Reconstitute the strong reference under the collector's allocation lock,
  ;; before it can decide to reclaim the referent and clear the hidden link.
  (ffi:c-inline (pointer) (t) t
    "(mkcl_object)MK_GC_call_with_alloc_lock(holai_weak_read, #0->foreign.data)"
    :one-liner t :side-effects t))
#+(or ccl clasp mkcl)
(defun native-adapter-reference (value)
  #+ccl (ccl:make-population :type :list :initial-contents (list value))
  #+clasp (core:make-weak-pointer value)
  #+mkcl (make-mkcl-weak-pointer value))
#+(or ccl clasp mkcl)
(defun native-adapter-reference-value (reference)
  #+ccl (car (ccl:population-contents reference))
  #+clasp (core:weak-pointer-value reference)
  #+mkcl (mkcl-weak-pointer-value reference))
#+mkcl
(defstruct mkcl-adapter-cache entries)
(defvar *native-function-adapters* (make-hash-table :test #'eql))
(defun make-native-adapter-cache ()
  #+(or sbcl ecl abcl)
  (make-hash-table :test #'eq :weakness :key-and-value)
  #+clisp
  (make-hash-table :test #'eq :weak :key-and-value)
  #+ccl
  (make-hash-table :test #'eq :weak :key)
  #+cmu
  (make-hash-table :test #'eq :weak-p :key-and-value)
  #+clasp
  (make-hash-table :test #'eq :weakness :key)
  #+mkcl
  (make-mkcl-adapter-cache)
  #-(or sbcl ecl abcl clisp ccl cmu clasp mkcl)
  (error "Weak native-function adapter storage is unsupported on ~A"
         (lisp-implementation-type)))
(defun cached-native-adapter (function table)
  #+mkcl
  (progn
    ;; There is no weak hash constructor in MKCL. Remove expired weak pairs
    ;; on access; no entry strongly retains a function, adapter or capture.
    (setf (mkcl-adapter-cache-entries table)
          (delete-if (lambda (entry)
                       (null (native-adapter-reference-value (cdr entry))))
                     (mkcl-adapter-cache-entries table)))
    (loop for entry in (mkcl-adapter-cache-entries table)
          when (eq function (native-adapter-reference-value (car entry)))
            return (native-adapter-reference-value (cdr entry))))
  #+(or ccl clasp)
  (let ((reference (gethash function table)))
    (when reference (native-adapter-reference-value reference)))
  #-(or ccl clasp mkcl)
  (gethash function table))
(defun cache-native-adapter (function adapter table)
  #+mkcl
  (push (cons (native-adapter-reference function)
              (native-adapter-reference adapter))
        (mkcl-adapter-cache-entries table))
  #+(or ccl clasp)
  (setf (gethash function table) (native-adapter-reference adapter))
  #-(or ccl clasp mkcl)
  (setf (gethash function table) adapter)
  adapter)
(defun make-native-adapter (function arity)
  (cl:labels ((invoke (&rest arguments)
               (let ((count (length arguments)))
                 (cond ((cl:< count arity) (cl:apply #'partial #'invoke arguments))
                       ((cl:= count arity) (cl:apply function arguments))
                       (t (cl:apply (cl:apply function (subseq arguments 0 arity))
                                    (nthcdr arity arguments)))))))
    #'invoke))
(defun function-value (function arity)
  (let ((table (or (gethash arity *native-function-adapters*)
                   (setf (gethash arity *native-function-adapters*)
                         (make-native-adapter-cache)))))
    (or (cached-native-adapter function table)
        (cache-native-adapter function (make-native-adapter function arity) table))))


(defmacro define-exception (name &rest slots)
  (let* ((package (symbol-package name))
         (constructor (intern (concatenate 'string "MAKE-" (symbol-name name)) package))
         (accessors (mapcar (lambda (s) (intern (format nil "~a-~a" name s) package)) slots)))
    `(progn
       (define-condition ,name (ocaml-condition)
         ,(mapcar (lambda (slot access)
                    `(,slot :initarg ,(intern (symbol-name slot) :keyword) :reader ,access))
                  slots accessors))
       (defun ,constructor ,slots
         (make-condition ',name ,@(mapcan (lambda (slot) (list (intern (symbol-name slot) :keyword) slot)) slots)))
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (register-pattern-family ',name
           '((,name :class ,name :arity ,(length slots) :readers ,accessors)))))))

(define-exception failure message)
(define-exception invalid_argument message)
(define-exception sys_error message)
(define-exception end_of_file)
(define-exception Not_found)
(defun failwith (message) (raise (make-failure message)))
(defun invalid-arg (message) (raise (make-invalid_argument message)))

(defstruct variant-value
  (type nil :read-only t) (tag 0 :read-only t) (constant-p nil :read-only t)
  (fields #() :read-only t))
(defun variant-type (x) (variant-value-type x))
(defun variant-tag (x) (variant-value-tag x))
(defun variant-fields (x) (variant-value-fields x))
(defvar *record-descriptions* (make-hash-table :test #'eq))
(defstruct record-value (type nil :read-only t) (fields #()))
(defun record-fields (x)
  (if (record-value-p x) (record-value-fields x) (variant-fields x)))
(defun record-description (x)
  (or (gethash (type-of x) *record-descriptions*)
      (invalid-arg "Not a translated record")))
(defun record-position (x field)
  (or (position field (first (record-description x)))
      (invalid-arg "Unknown record field")))
(defun record-field (x field)
  (if (ref-cell-p x)
      (if (eq field :contents) (deref x) (invalid-arg "Unknown ref field"))
      (aref (record-fields x) (record-position x field))))
(defun record-update (x &rest fields)
  (if (ref-cell-p x)
      (let ((copy (ref (deref x))))
        (loop for (field value) on fields by #'cddr do (record-assign copy field value))
        copy)
  (let ((copy (copy-structure x)) (values (copy-seq (record-fields x))))
    (loop for (field value) on fields by #'cddr
          do (setf (aref values (record-position x field)) value))
    (if (record-value-p x) (setf (record-value-fields copy) values)
        ;; The shared fields slot is read-only, but replacing it on the new
        ;; structure is needed for record copy/update; no original is mutated.
        (setf (slot-value copy 'fields) values))
    copy)))
(defun record-assign (x field value)
  (if (ref-cell-p x)
      (if (eq field :contents) (assign x value) (invalid-arg "Unknown ref field"))
  (let ((index (record-position x field)))
    (unless (nth index (second (record-description x)))
      (invalid-arg "Assignment to immutable record field"))
    (setf (aref (record-fields x) index) value) unit)))

(defmacro defrecord (name &rest specifications)
  (let* ((slots (mapcar (lambda (s) (if (consp s) (first s) s)) specifications))
         (mutable (mapcar #'consp specifications))
         (keys (mapcar (lambda (s) (intern (symbol-name s) :keyword)) slots))
         (package (symbol-package name))
         (maker (intern (concatenate 'string "MAKE-" (symbol-name name)) package))
         (raw (intern (concatenate 'string "%MAKE-" (symbol-name name)) package)))
    `(progn
       (defstruct (,name (:include record-value (type ',name)) (:constructor ,raw (fields))))
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (setf (gethash ',name *record-descriptions*) (list ',keys ',mutable)))
       (defun ,maker (&key ,@slots) (,raw (vector ,@slots)))
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (register-pattern-family ',name
           '((,name :class ,name :arity ,(length slots) :record t
                    :keys ,keys :accessor record-fields)))))))
(defmacro defvariant (type &body constructors)
  (let ((constant-tag 0) (block-tag 0))
    `(progn
      (eval-when (:compile-toplevel :load-toplevel :execute)
        (register-pattern-family ',type ',(mapcar (lambda (c) (list (car c))) constructors)))
      ,@(loop for (name . specifications) in constructors
         for record-p = (and (consp (first specifications)) (eq (caar specifications) :record))
         for record-spec = (when record-p (cdar specifications))
         for mutable = (when record-p (mapcar #'consp record-spec))
         for slots = (if record-p (mapcar (lambda (s) (if (consp s) (car s) s)) record-spec) specifications)
         for package = (symbol-package name)
         for class = (intern (concatenate 'string "%" (symbol-name name) "-VALUE") package)
         for maker = (intern (concatenate 'string "MAKE-" (symbol-name name)) package)
         for raw-maker = (intern (concatenate 'string "%MAKE-" (symbol-name name)) package)
         for singleton = (intern (concatenate 'string "*" (symbol-name name) "-VALUE*") package)
         for constant-p = (null slots)
         for tag = (if constant-p (prog1 constant-tag (incf constant-tag)) (prog1 block-tag (incf block-tag)))
         append
         `((defstruct (,class (:include variant-value
                               (type ',type) (tag ,tag) (constant-p ,constant-p))
                             (:constructor ,raw-maker (fields))))
           ,@(when constant-p `((defparameter ,singleton (,raw-maker #()))))
           ,@(when record-p `((eval-when (:compile-toplevel :load-toplevel :execute)
                               (setf (gethash ',class *record-descriptions*)
                                     (list ',(mapcar (lambda (s) (intern (symbol-name s) :keyword)) slots) ',mutable)))))
           (defun ,maker ,(if record-p `(&key ,@slots) slots)
             ,(if constant-p singleton `(,raw-maker (vector ,@slots))))
           (eval-when (:compile-toplevel :load-toplevel :execute)
             (setf (gethash ',name *pattern-descriptions*)
                   '(:class ,class :arity ,(length slots) :record ,record-p
                     :keys ,(when record-p (mapcar (lambda (s) (intern (symbol-name s) :keyword)) slots))
                     :accessor variant-fields))))))))

(defvariant option (None) (Some value))

;; This is a documented supported-data ordering, not an OCaml object inspector.
(defun compare (a b)
  (when (or (functionp a) (functionp b))
    (invalid-arg "compare: functional value"))
  (cond ((eq a b) 0)
        ((and (numberp a) (numberp b)) (cond ((cl:< a b) -1) ((cl:> a b) 1) (t 0)))
        ((and (characterp a) (characterp b)) (compare (char-code a) (char-code b)))
        ((and (stringp a) (stringp b)) (cond ((string< a b) -1) ((string> a b) 1) (t 0)))
        ((null a) -1) ((null b) 1)
        ((and (consp a) (consp b))
         (let ((c (compare (car a) (car b)))) (if (cl:= c 0) (compare (cdr a) (cdr b)) c)))
        ((and (tuple-value-p a) (tuple-value-p b)) (compare-tuple-items (tuple-items a) (tuple-items b)))
        ((and (record-value-p a) (record-value-p b))
         (unless (eq (record-value-type a) (record-value-type b)) (invalid-arg "compare: distinct record types"))
         (compare-vectors (record-fields a) (record-fields b)))
        ((and (variant-value-p a) (variant-value-p b))
         (unless (eq (variant-type a) (variant-type b))
           (invalid-arg "compare: distinct variant types"))
         (cond ((and (variant-value-constant-p a) (not (variant-value-constant-p b))) -1)
               ((and (not (variant-value-constant-p a)) (variant-value-constant-p b)) 1)
               (t (let ((c (compare (variant-tag a) (variant-tag b))))
                    (if (cl:= c 0) (compare-vectors (variant-fields a) (variant-fields b)) c)))))
        ((and (ref-cell-p a) (ref-cell-p b)) (compare (deref a) (deref b)))
        ((and (unit-value-p a) (unit-value-p b)) 0)
        ((and (typep a 'boolean) (typep b 'boolean)) (if a 1 -1))
        (t (invalid-arg "compare: unsupported values"))))
(defun compare-tuple-items (a b)
  (let ((c (compare (length a) (length b))))
    (unless (cl:= c 0) (return-from compare-tuple-items c)))
  (loop for x in a for y in b for c = (compare x y)
        unless (cl:= c 0) do (return-from compare-tuple-items c))
  0)
(defun compare-vectors (a b)
  (let ((c (compare (length a) (length b))))
    (unless (cl:= c 0) (return-from compare-vectors c)))
  (loop for x across a for y across b for c = (compare x y)
        unless (cl:= c 0) do (return-from compare-vectors c))
  0)
(defun = (a b) (cl:= (compare a b) 0))
(defun <> (a b) (not (= a b)))
(defun == (a b) (eq a b))
(defun != (a b) (not (eq a b)))
(defun < (a b) (cl:< (compare a b) 0))
(defun > (a b) (cl:> (compare a b) 0))
(defun <= (a b) (cl:<= (compare a b) 0))
(defun >= (a b) (cl:>= (compare a b) 0))

(defun int-div (a b) (if (zerop b) (invalid-arg "division by zero") (truncate a b)))
(defun int-mod (a b) (if (zerop b) (invalid-arg "division by zero") (rem a b)))
(defun num (n) n)
(defun numdom (n) (tuple (numerator n) (denominator n)))
(defun gcd-num (a b) (gcd a b))
(defun abs-num (n) (abs n))
(defun power-num (a b) (expt a b))
(defun quo-num (a b) (if (minusp b) (ceiling a b) (floor a b)))
(defun mod-num (a b) (- a (* (quo-num a b) b)))
(defun int-of-num (n)
  (unless (integerp n) (failwith "integer argument required"))
  (unless (cl:<= (- (ash 1 62)) n (1- (ash 1 62))) (failwith "int_of_big_int")) n)
(defun string-of-num (n) (format nil "~a" n))
(defun string-of-int (n) (format nil "~d" n))
(defun string-of-float (n) (format nil "~a" n))
(defun string-concat (a b) (concatenate 'string a b))
(defun string-length (s) (length s))
(defun string-sub (s start length)
  (if (or (cl:< start 0) (cl:< length 0) (cl:> (cl:+ start length) (length s)))
      (invalid-arg "String.sub") (subseq s start (cl:+ start length))))
(defun string-get (s i) (char s i))
(defun string-join (separator strings)
  (format nil "~{~a~}" (loop for s in strings for first = t then nil
                             unless first collect separator collect s)))
(defun cpu-time (u) (declare (ignore u))
  (coerce (cl:/ (get-internal-run-time) internal-time-units-per-second) 'double-float))
(defun exception-string (e)
  (typecase e (failure (failure-message e)) (sys_error (sys_error-message e))
             (invalid_argument (invalid_argument-message e)) (t (format nil "~a" (type-of e)))))

;; Hash equal translated structures identically, without depending on object EQ.
;; 30 nonnegative bits suffice for the original Patricia-tree algorithm.
(defun structural-hash (x)
  (labels ((mix (a b) (logand #x3fffffff (logxor (cl:* 65599 a) b)))
           (walk (x)
             (typecase x
               (variant-value (reduce #'mix (map 'list #'walk (variant-fields x))
                                      :initial-value (mix (variant-tag x) (if (variant-value-constant-p x) 1 2))))
               (tuple-value (reduce #'mix (map 'list #'walk (tuple-items x)) :initial-value 7))
               (record-value (reduce #'mix (map 'list #'walk (record-fields x)) :initial-value 11))
               (cons (mix (walk (car x)) (walk (cdr x))))
               (ref-cell (walk (deref x)))
               (function (invalid-arg "hash: functional value"))
               (t (logand #x3fffffff (sxhash x))))))
    (walk x)))

(defun open-channel (filename direction)
  (handler-case (open filename :direction direction :if-exists :supersede
                              :if-does-not-exist (if (eq direction :input) :error :create))
    (file-error (e) (raise (make-sys_error (princ-to-string e))))))
(defun open-in (filename) (open-channel filename :input))
(defun open-in-bin (filename) (open-in filename))
(defun open-out (filename) (open-channel filename :output))
(defun close-channel (stream) (close stream) unit)
(defun input-line (stream)
  (or (read-line stream nil nil) (raise (make-end_of_file))))
(defun output-string (stream s) (write-string s stream) unit)
(defun channel-length (stream) (file-length stream))
(defun really-input-string (stream length)
  (let ((s (make-string length)))
    (unless (cl:= (read-sequence s stream) length) (raise (make-end_of_file))) s))

(defun bool-or (a b) (or a b))
(defun bool-and (a b) (and a b))
(defun char-chr (n)
  (if (cl:<= 0 n 255) (code-char n) (invalid-arg "Char.chr")))
(defun string-make (length char)
  (if (minusp length) (invalid-arg "String.make") (make-string length :initial-element char)))
(defun string-escaped (s)
  (with-output-to-string (out)
    (loop for c across s for n = (char-code c)
      do (case c
           (#\" (write-string "\\\"" out)) (#\\ (write-string "\\\\" out))
           (#\Newline (write-string "\\n" out)) (#\Return (write-string "\\r" out))
           (#\Tab (write-string "\\t" out)) (#\Backspace (write-string "\\b" out))
           (otherwise (if (or (cl:< n 32) (cl:> n 126))
                          (format out "\\~3,'0d" n) (write-char c out)))))))
(defun int-of-string (s)
  (let* ((s (remove #\_ s)) (negative (and (plusp (length s)) (char= (char s 0) #\-)))
         (start (if (and (plusp (length s)) (find (char s 0) "+-")) 1 0))
         (base 10))
    (when (and (cl:> (length s) (cl:+ start 2)) (char= (char s start) #\0))
      (case (char-downcase (char s (cl:1+ start)))
        (#\x (setf base 16 start (cl:+ start 2)))
        (#\o (setf base 8 start (cl:+ start 2)))
        (#\b (setf base 2 start (cl:+ start 2)))))
    (handler-case (let ((n (parse-integer s :start start :radix base))) (if negative (- n) n))
      (parse-error () (failwith "int_of_string")))))
(defun array-make (length initial)
  (if (minusp length) (invalid-arg "Array.make") (make-array length :initial-element initial)))
(defun array-get (a i)
  (if (cl:<= 0 i (1- (length a))) (aref a i) (invalid-arg "index out of bounds")))
(defun array-set (a i value)
  (if (cl:<= 0 i (1- (length a))) (progn (setf (aref a i) value) unit) (invalid-arg "index out of bounds")))
(defun list-fold-left (f acc list)
  (if (null list) acc (list-fold-left f (funcall f acc (car list)) (cdr list))))
(defun list-exists (f list)
  (and list (or (funcall f (car list)) (list-exists f (cdr list)))))
