(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root)
      :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")
(uiop:define-package :holai.tests.system-interrupt (:use :cl))
(in-package :holai.tests.system-interrupt)
;; This harness installs native host hooks independently of the adapter.
;; Only the parent delivers signals; neither branch synthesizes a SIGINT.
(define-condition previous-interrupt (error) ())
(defvar *previous-deliveries* 0)
#+sbcl
(defvar *forwarded-condition* nil)
#+sbcl
(defvar *forwarded-hook* nil)
#+abcl
(defvar *installing-thread* (threads:current-thread))
#+(and ecl threads)
(defvar *installing-process* mp:*current-process*)

(defun invoke-previous-hook ()
  #+abcl
  (unless (eq *installing-thread* (threads:current-thread))
    (error "Previous hook delivered on a different Lisp thread"))
  #+(and ecl threads)
  (unless (eq *installing-process* mp:*current-process*)
    (error "Previous hook delivered on a different Lisp process"))
  (incf *previous-deliveries*)
  (error 'previous-interrupt))

(defun install-independent-hook ()
  #+sbcl
  (setf sb-ext:*invoke-debugger-hook*
    (lambda (condition hook)
      (when *forwarded-condition*
        (unless (and (eq condition *forwarded-condition*)
                     (eq hook *forwarded-hook*))
          (error "Adapter changed unrelated debugger condition or prior hook"))
        (throw 'unrelated-forwarded t))
      (unless (typep condition 'sb-sys:interactive-interrupt)
        (error "Prior hook received a non-interrupt condition: ~A" condition))
      (invoke-previous-hook)))
  #+ecl
  (setf (fdefinition 'si::terminal-interrupt)
    (lambda (&key correctablep)
      (declare (ignore correctablep))
      #+threads
      (mp:interrupt-process *installing-process* #'invoke-previous-hook)
      #-threads
      (invoke-previous-hook)))
  #+abcl
  (let ((hook
          (java:jinterface-implementation "sun.misc.SignalHandler" "handle"
            (lambda (signal)
              (declare (ignore signal))
              (threads:interrupt-thread *installing-thread*
                #'invoke-previous-hook)))))
    (java:jstatic "handle" "sun.misc.Signal"
      (java:jnew "sun.misc.Signal" "INT") hook)
    hook)
  #+clisp
  (progn
    (ext:set-global-handler 'sys::interrupt-condition
      (lambda (condition)
        (declare (ignore condition))
        (invoke-previous-hook)))
    (find-method #'sys::global-handler '(progn)
      (list (find-class 'sys::interrupt-condition)))))

(defun assert-prior-identity (hook)
  (unless
      #+sbcl
      (eq hook sb-ext:*invoke-debugger-hook*)
      #+ecl
      (eq hook (fdefinition 'si::terminal-interrupt))
      #+abcl
      ;; Signal.handle returns the actual installed Java object. Reinstalling
      ;; that same object probes identity without substituting a mock hook.
      (let ((identities (java:jnew "java.util.IdentityHashMap")))
        (java:jcall "put" identities hook hook)
        (java:jcall "containsKey" identities
          (java:jstatic "handle" "sun.misc.Signal"
            (java:jnew "sun.misc.Signal" "INT") hook)))
      #+clisp
      (eq hook (find-method #'sys::global-handler '(progn)
                 (list (find-class 'sys::interrupt-condition))))
    (error "catch-break did not restore the exact previous native hook")))

(dotimes (cycle 2)
  (declare (ignorable cycle))
  ;; The second cycle installs a fresh hook to reject stale saved state.
  (let ((prior (install-independent-hook)))
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (holai.runtime.stdlib:catch-break t)
    (holai.runtime.stdlib:catch-break t)
    #+sbcl
    (let ((*forwarded-condition* (make-condition 'simple-condition))
          (*forwarded-hook* prior))
      (unless (catch 'unrelated-forwarded
                (invoke-debugger *forwarded-condition*)
                nil)
        (error "Adapter did not forward unrelated debugger condition")))
    (handler-case
        (progn
          (write-line "SIGINT catch ready")
          (finish-output)
          (loop (sleep 1)))
      (holai.runtime.stdlib:sys_break ()
        #+abcl
        (unless (eq *installing-thread* (threads:current-thread))
          (error "Sys.Break delivered on a different Lisp thread"))
        #+(and ecl threads)
        (unless (eq *installing-process* mp:*current-process*)
          (error "Sys.Break delivered on a different Lisp process")))
      (previous-interrupt ()
        (error "Previous hook ran while catch-break was enabled")))
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (unless (zerop *previous-deliveries*)
      (error "Previous hook ran during adapter catches")))
  (write-line "SIGINT adapter check passed"))

(handler-case
    (progn
      (write-line "SIGINT previous hook ready")
      (finish-output)
      (loop (sleep 1)))
  (previous-interrupt ()
    (unless (= *previous-deliveries* 1)
      (error "Expected exactly one actual prior-hook delivery"))
    (write-line "SIGINT previous hook restored")
    (finish-output))
  (holai.runtime.stdlib:sys_break ()
    (error "Sys.Break leaked after catch-break was disabled")))
(uiop:quit 0)
