(uiop:define-package :holai.runtime.stdlib
  (:use :cl)
  (:shadow :list-length)
  (:import-from :holai.runtime.data
    :unit :tuple :fst :snd :assign :deref :ocaml-condition :raise)
  (:import-from :holai.runtime.core
    :defrecord :record-update :record-field :invalid-arg :define-exception
    :failwith :None :make-Not_found :structural-hash)
  (:shadowing-import-from :holai.runtime.core :funcall := :Some)
  (:import-from :holai.runtime.pattern :match)
  ;; The terminal runtime includes the initialized standard formatter.
  (:import-from :holai.runtime.format)
  (:export :array-fold-left :array-of-list :array-map :gc-control :make-gc-control
    :gc-get :gc-set :catch-break :sys_break :make-sys_break :table-remove :table-fold
    :lazy-create :lazy-force :lazy-undefined :make-lazy-undefined :ocaml-max-int
    :assert_failure :make-assert_failure :assert-true :ref-incr :ref-decr :print-endline
    :ignore-value :int-lsl :int-lsr :int-asr :float-of-int :int-of-float :float-floor
    :table-create :table-clear :table-add :table-replace :table-find
    :random-init :random-bits :random-int :list-length :list-hd :list-tl :list-nth
    :list-rev :list-rev-append :list-map :list-map2 :list-mapi :list-rev-map :list-iter
    :list-concat :list-fold-left2 :list-fold-right2 :list-fold-right :list-for-all
    :list-for-all2 :list-mem :list-mem-assoc :list-assoc :list-find :list-filter
    :list-filter-map :list-partition :list-sort))
(in-package :holai.runtime.stdlib)

;; Required OCaml 4.14.1 library boundary. These functions do not change the
;; translated HOL algorithms. List.sort preserves values/stability, but does
;; not promise OCaml's comparator invocation order.
(defparameter ocaml-max-int 4611686018427387903)
(defrecord gc-control stack_limit)
(defvar *gc-control* (make-gc-control :stack_limit 16777216))
(defun gc-get (u) (declare (ignore u)) (record-update *gc-control*))
(defun gc-set (configuration)
  (unless (and (typep configuration 'gc-control)
               (integerp (record-field configuration :stack_limit))
               (cl:>= (record-field configuration :stack_limit) 0))
    (invalid-arg "Gc.set: stack_limit"))
  (setf *gc-control* (record-update configuration)) unit)
(define-exception sys_break)
(defvar *catch-break* nil)
#+abcl
(defvar *abcl-sigint-registration* nil)
#+(and clisp unix)
(ffi:def-call-out native-sigint-disposition
  (:name "signal") (:library :default) (:language :stdc)
  (:arguments (number ffi:int) (handler ffi:c-pointer))
  (:return-type ffi:c-pointer))
#+(and clisp unix)
(defvar *clisp-original-sigint-handler* nil)
#+(and clisp unix)
(defun set-native-sigint-disposition (handler)
  (let ((previous (native-sigint-disposition 2 handler)))
    ;; Inspect the address, never dereference SIG_ERR ((void *) -1).
    (when (and previous
               (= (ffi:foreign-address-unsigned previous)
                  (1- (ash 1 (ffi:bitsizeof 'ffi:c-pointer)))))
      (error "Cannot set the native SIGINT disposition"))
    previous))
(defun catch-break (enabled)
  #+sbcl
  (sb-sys:enable-interrupt sb-unix:sigint
    (if enabled
        (lambda (signal info context)
          (declare (ignore signal info context)) (raise (make-sys_break)))
        :default))
  #+ecl
  (if enabled
      (ext:set-signal-handler ext:+sigint+
        (lambda () (raise (make-sys_break))))
      ;; ECL's compiler declares CATCH-SIGNAL's result NULL. Its :DEFAULT
      ;; action still installs SIG_DFL; do not test the compiled return value.
      (ext:catch-signal ext:+sigint+ :default))
  #+abcl
  (if enabled
      (let* ((target (threads:current-thread))
             (signal (java:jnew "sun.misc.Signal" "INT"))
             (handler
               (java:jinterface-implementation "sun.misc.SignalHandler" "handle"
                 (lambda (signal)
                   (declare (ignore signal))
                   ;; Java dispatches on its own thread; raise only on the
                   ;; Lisp thread that installed this handler.
                   (threads:interrupt-thread target
                     (lambda () (raise (make-sys_break))))))))
        (java:jstatic "handle" "sun.misc.Signal" signal handler)
        (setf *abcl-sigint-registration* (cons signal handler)))
      (progn
        (java:jstatic "handle" "sun.misc.Signal"
          (if *abcl-sigint-registration* (car *abcl-sigint-registration*)
              (java:jnew "sun.misc.Signal" "INT"))
          (java:jfield "sun.misc.SignalHandler" "SIG_DFL"))
        (setf *abcl-sigint-registration* nil)))
  #+(and clisp unix)
  (if enabled
      (progn
        (when *clisp-original-sigint-handler*
          (set-native-sigint-disposition *clisp-original-sigint-handler*))
        (ext:set-global-handler 'sys::interrupt-condition
          (lambda (condition)
            (declare (ignore condition))
            (raise (make-sys_break)))))
      (progn
        (let ((previous
                (set-native-sigint-disposition (ffi:unsigned-foreign-address 0))))
          ;; Save only the first disable: subsequent disables return SIG_DFL.
          (unless *clisp-original-sigint-handler*
            (setf *clisp-original-sigint-handler* previous)))
        (ext:set-global-handler 'sys::interrupt-condition nil)))
  #-(or sbcl ecl abcl (and clisp unix))
  (error "SIGINT handling is unsupported on ~A" (lisp-implementation-type))
  (setf *catch-break* enabled)
  unit)
(define-exception assert_failure location)
(defun assert-true (condition source line column)
  (unless condition (raise (make-assert_failure (tuple source line column)))) unit)
(defun ref-incr (cell) (assign cell (1+ (deref cell))))
(defun ref-decr (cell) (assign cell (1- (deref cell))))
(defun ignore-value (value) (declare (ignore value)) unit)
(defun print-endline (string) (write-line string *standard-output*) (finish-output *standard-output*) unit)
(define-exception lazy-undefined)
(defstruct (ocaml-lazy (:constructor lazy-create (thunk))) thunk (state :pending) value)
(defun lazy-force (cell)
  (case (ocaml-lazy-state cell)
    (:value (ocaml-lazy-value cell))
    (:failed (raise (ocaml-lazy-value cell)))
    (:forcing (raise (make-lazy-undefined)))
    (:pending
     (setf (ocaml-lazy-state cell) :forcing)
     (handler-case
         (let ((value (funcall (ocaml-lazy-thunk cell) unit)))
           (setf (ocaml-lazy-value cell) value (ocaml-lazy-state cell) :value
                 (ocaml-lazy-thunk cell) nil) value)
       (ocaml-condition (condition)
         (setf (ocaml-lazy-value cell) condition (ocaml-lazy-state cell) :failed
               (ocaml-lazy-thunk cell) nil)
         (raise condition))))))
(defun int-lsr (x n)
  (unless (cl:<= 0 n 63) (invalid-arg "Shift count outside tested profile"))
  (if (zerop n) x (ash (logand x (1- (ash 1 63))) (- n))))
(defun int-lsl (x n)
  (unless (cl:<= 0 n 63) (invalid-arg "Shift count outside tested profile"))
  (let ((bits (logand (ash x n) (1- (ash 1 63)))))
    (if (logbitp 62 bits) (- bits (ash 1 63)) bits)))
(defun int-asr (x n)
  (unless (cl:<= 0 n 63) (invalid-arg "Shift count outside tested profile"))
  (ash x (- n)))
(defun float-of-int (x) (float x 1.0d0))
(defun int-of-float (x) (truncate x))
(defun float-floor (x) (float (floor x) 1.0d0))

(defun list-length (xs) (length xs))
(defun list-hd (xs) (if xs (car xs) (failwith "hd")))
(defun list-tl (xs) (if xs (cdr xs) (failwith "tl")))
(defun list-nth (xs n)
  (when (minusp n) (invalid-arg "List.nth"))
  (labels ((nth-aux (xs n) (if xs (if (zerop n) (car xs) (nth-aux (cdr xs) (1- n)))
                              (failwith "nth")))) (nth-aux xs n)))
(defun list-rev (xs) (reverse xs))
(defun list-rev-append (xs ys) (nconc (reverse xs) ys))
(defun list-map (f xs) (if xs (cons (funcall f (car xs)) (list-map f (cdr xs))) nil))
(defun list-map2 (f xs ys)
  (cond ((and (null xs) (null ys)) nil)
        ((or (null xs) (null ys)) (invalid-arg "List.map2"))
        (t (cons (funcall f (car xs) (car ys)) (list-map2 f (cdr xs) (cdr ys))))))
(defun list-mapi (f xs)
  (labels ((walk (i xs) (if xs (cons (funcall f i (car xs)) (walk (1+ i) (cdr xs))) nil)))
    (walk 0 xs)))
(defun list-rev-map (f xs) (reverse (list-map f xs)))
(defun list-iter (f xs) (dolist (x xs) (funcall f x)) unit)
(defun list-concat (xs) (if xs (append (car xs) (list-concat (cdr xs))) nil))
(defun list-fold-right (f xs init)
  (if xs (funcall f (car xs) (list-fold-right f (cdr xs) init)) init))
(defun list-fold-left2 (f init xs ys)
  (cond ((and (null xs) (null ys)) init)
        ((or (null xs) (null ys)) (invalid-arg "List.fold_left2"))
        (t (list-fold-left2 f (funcall f init (car xs) (car ys)) (cdr xs) (cdr ys)))))
(defun list-fold-right2 (f xs ys init)
  (cond ((and (null xs) (null ys)) init)
        ((or (null xs) (null ys)) (invalid-arg "List.fold_right2"))
        (t (funcall f (car xs) (car ys) (list-fold-right2 f (cdr xs) (cdr ys) init)))))
(defun list-for-all (f xs) (if xs (and (funcall f (car xs)) (list-for-all f (cdr xs))) t))
(defun list-for-all2 (f xs ys)
  (cond ((and (null xs) (null ys)) t)
        ((or (null xs) (null ys)) (invalid-arg "List.for_all2"))
        (t (and (funcall f (car xs) (car ys)) (list-for-all2 f (cdr xs) (cdr ys))))))
(defun list-mem (x xs) (if xs (or (= x (car xs)) (list-mem x (cdr xs))) nil))
(defun list-mem-assoc (x xs) (if xs (or (= x (fst (car xs))) (list-mem-assoc x (cdr xs))) nil))
(defun list-assoc (x xs)
  (cond ((null xs) (raise (make-Not_found))) ((= x (fst (car xs))) (snd (car xs)))
        (t (list-assoc x (cdr xs)))))
(defun list-find (f xs)
  (cond ((null xs) (raise (make-Not_found))) ((funcall f (car xs)) (car xs))
        (t (list-find f (cdr xs)))))
(defun list-filter (f xs)
  (if xs (if (funcall f (car xs)) (cons (car xs) (list-filter f (cdr xs)))
             (list-filter f (cdr xs))) nil))
(defun list-filter-map (f xs)
  (if xs (let ((result (funcall f (car xs))))
           (match result ((Some x) (cons x (list-filter-map f (cdr xs))))
             ((None) (list-filter-map f (cdr xs))))) nil))
(defun list-partition (f xs)
  (if xs (let* ((take (funcall f (car xs))) (rest (list-partition f (cdr xs))))
           (if take (tuple (cons (car xs) (fst rest)) (snd rest))
                    (tuple (fst rest) (cons (car xs) (snd rest)))))
      (tuple nil nil)))
(defun list-sort (cmp xs)
  (stable-sort (copy-list xs) (lambda (a b) (minusp (funcall cmp a b)))))
(defun array-fold-left (function initial array)
  (let ((result initial))
    (loop for value across array do (setf result (funcall function result value)))
    result))
(defun array-of-list (values) (coerce values 'vector))
(defun array-map (function array)
  (map 'vector (lambda (value) (funcall function value)) array))

;; Add shadows an earlier binding; replace replaces only the newest binding.
;; Buckets use the existing OCaml-compatible equality/hash boundary.
(defstruct (ocaml-table (:constructor make-ocaml-table (buckets))) buckets)
(defun table-create (size)
  (make-ocaml-table (make-hash-table :test #'eql :size (max 1 size))))
(defun table-clear (table) (clrhash (ocaml-table-buckets table)) unit)
(defun table-add (table key value)
  (push (cons key value) (gethash (structural-hash key) (ocaml-table-buckets table))) unit)
(defun table-replace (table key value)
  (let ((pair (find key (gethash (structural-hash key) (ocaml-table-buckets table))
                    :key #'car :test #'=)))
    (if pair (setf (cdr pair) value) (table-add table key value))) unit)
(defun table-find (table key)
  (let ((pair (find key (gethash (structural-hash key) (ocaml-table-buckets table))
                    :key #'car :test #'=)))
    (if pair (cdr pair) (raise (make-Not_found)))))
(defun table-remove (table key)
  (let* ((hash (structural-hash key)) (buckets (ocaml-table-buckets table))
         (rest (remove-if (lambda (pair) (= key (car pair)))
                          (gethash hash buckets) :count 1)))
    (if rest (setf (gethash hash buckets) rest) (remhash hash buckets))) unit)
(defun table-fold (function table initial)
  (let ((result initial))
    (maphash (lambda (hash bucket)
               (declare (ignore hash))
               (dolist (pair bucket)
                 (setf result (funcall function (car pair) (cdr pair) result))))
             (ocaml-table-buckets table))
    result))

;; Source Random API backed by the host's standard Common Lisp engine.
;; Integer seeds are accepted for source compatibility, but ignored:
;; RANDOM-INIT creates a fresh state, not an integer-seeded replay stream.
;; Reproducibility requires copying a RANDOM-STATE within the same host.
(defvar *source-random-state* (make-random-state t))
(defun random-init (seed)
  (declare (ignore seed))
  (setf *source-random-state* (make-random-state t))
  unit)
(defun random-bits (u)
  (declare (ignore u))
  (cl:random #x40000000 *source-random-state*))
(defun random-int (n)
  (unless (cl:<= 1 n #x3fffffff) (invalid-arg "Random.int"))
  (cl:random n *source-random-state*))
