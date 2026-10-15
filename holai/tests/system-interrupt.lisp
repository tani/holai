(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")
(uiop:define-package :holai.tests.system-interrupt (:use :cl))
(in-package :holai.tests.system-interrupt)
;; The native fixture selects this shared lifecycle with a dynamically scoped
;; feature. Otherwise only the parent supplies the three actual OS SIGINTs.
(defvar *native-simulation* (member :holai-native-interrupt-test *features*))
#+ccl
(unless *native-simulation*
  ;; Nix's CCL entry point retains a shell parent. Report the actual Lisp PID,
  ;; not the wrapper PID, without changing native interrupt dispatch.
  (format t "~&SIGINT target pid: ~D~%" (ccl::getpid))
  (finish-output))
(define-condition previous-interrupt (error) ())
(defvar *previous-deliveries* 0)
(defvar *interrupt-checks* 0)
(defvar *prior-token* nil)
#+sbcl (defvar *forwarded-condition* nil)
#+sbcl (defvar *forwarded-hook* nil)
(defun current-installer ()
  #+sbcl sb-thread:*current-thread*
  #+(or ecl clasp) mp:*current-process*
  #+abcl (threads:current-thread)
  #+ccl ccl:*current-process*
  #+mkcl (mt:current-thread)
  #+(or clisp cmu) :single-thread)
(defvar *installer* (current-installer))
(defun assert-installer ()
  (unless (eq *installer* (current-installer))
    (error "Interrupt delivered on a different Lisp computation stack")))
(defun invoke-previous-hook (token)
  (assert-installer)
  (unless (eq token *prior-token*) (error "Stale independent interrupt hook"))
  (incf *previous-deliveries*)
  (error 'previous-interrupt))
(defun dispatch-previous-hook (token)
  (if (eq *installer* (current-installer))
      (invoke-previous-hook token)
      (let ((thunk (lambda () (invoke-previous-hook token))))
        #+sbcl (sb-thread:interrupt-thread *installer* thunk)
        #+(or ecl clasp) (mp:interrupt-process *installer* thunk)
        #+abcl (threads:interrupt-thread *installer* thunk)
        #+ccl (ccl:process-interrupt *installer* thunk)
        #+mkcl (mt:interrupt-thread *installer* thunk)
        #+(or clisp cmu) (error "Unexpected native interrupt thread"))))
#+mkcl
(defvar *mkcl-si-closed-p* (si::package-closed-p "SI"))
#+mkcl
(defun set-independent-mkcl-hook (hook)
  ;; Independently exercise MKCL's native bounded package-state protocol,
  ;; rather than using the runtime adapter to install our prior hook.
  (let* ((package (find-package "SI"))
         (closed (si::package-closed-p package)))
    (unwind-protect
        (progn
          (when closed (si::reopen-package package))
          (setf (fdefinition 'si::sigint-handler) hook))
      (when closed (si::close-package package)))))
#+cmu
(defun cmu-current-hook ()
  ;; ENABLE-INTERRUPT returns the exact displaced function. Restore it before
  ;; invoking it; there is no assumed native signal-handler getter.
  (let ((hook (system:enable-interrupt unix:sigint
                (lambda (&rest arguments)
                  (declare (ignore arguments))
                  (error "Interrupt during handler identity probe")))))
    (system:enable-interrupt unix:sigint hook)
    hook))
#+ccl
(defvar *ccl-interrupt-generic* #'ccl::force-break-in-listener)
(defun current-native-hook ()
  #+sbcl sb-ext:*invoke-debugger-hook*
  #+ecl (fdefinition 'si::terminal-interrupt)
  #+abcl holai.runtime.stdlib::*abcl-interrupt-hook*
  #+clisp (find-method #'sys::global-handler '(progn)
             (list (find-class 'sys::interrupt-condition)))
  #+ccl
  (progn
    (unless (eq *ccl-interrupt-generic* #'ccl::force-break-in-listener)
      (error "Interrupt adapter replaced CCL's native generic function"))
    (find-method #'ccl::force-break-in-listener nil
      (list (find-class 'ccl:process))))
  #+mkcl
  (progn
    (unless (eq *mkcl-si-closed-p* (si::package-closed-p "SI"))
      (error "Interrupt hook mutation changed MKCL's package protection"))
    (fdefinition 'si::sigint-handler))
  #+cmu (cmu-current-hook)
  #+clasp (find-method #'mp:service-interrupt nil
             (list (find-class 'core:sigint))))
(defun install-independent-hook ()
  (let ((token (setf *prior-token* (list nil))))
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
        (dispatch-previous-hook token)))
    #+ecl
    (setf (fdefinition 'si::terminal-interrupt)
      (lambda (&key correctablep)
        (declare (ignore correctablep)) (dispatch-previous-hook token)))
    #+abcl
    (setf holai.runtime.stdlib::*abcl-interrupt-hook*
      (lambda () (dispatch-previous-hook token)))
    #+clisp
    (ext:set-global-handler 'sys::interrupt-condition
      (lambda (condition)
        (declare (ignore condition)) (dispatch-previous-hook token)))
    #+ccl
    (defmethod ccl::force-break-in-listener ((process ccl:process))
      (declare (ignore process)) (dispatch-previous-hook token))
    #+mkcl
    (set-independent-mkcl-hook
      (lambda (signal)
        (declare (ignore signal)) (dispatch-previous-hook token)))
    #+cmu
    (system:enable-interrupt unix:sigint
      (lambda (signal code context)
        (declare (ignore signal code context))
        (system:with-interrupts (dispatch-previous-hook token))))
    #+clasp
    (defmethod mp:service-interrupt ((condition core:sigint))
      (declare (ignore condition)) (dispatch-previous-hook token))
    (current-native-hook)))
(defun assert-prior-identity (hook)
  (unless (eq hook (current-native-hook))
    (error "catch-break did not restore the exact previous native hook")))
(defun simulate-native-interrupt ()
  ;; Enter each selected native Lisp interrupt boundary, never Sys.Break.
  #+sbcl (invoke-debugger (make-condition 'sb-sys:interactive-interrupt))
  #+ecl (si::terminal-interrupt :correctablep t)
  #+abcl (holai.runtime.stdlib::interrupt-abcl-thread *installer*)
  #+clisp (sys::global-handler (make-condition 'sys::interrupt-condition))
  #+ccl (ccl::force-break-in-listener *installer*)
  #+mkcl (si::sigint-handler 2)
  #+cmu (funcall (cmu-current-hook) unix:sigint 0 nil)
  #+clasp (mp:raise 'core:sigint))
(defun await-interrupt (ready)
  (if *native-simulation*
      (simulate-native-interrupt)
      (progn (write-line ready) (finish-output)))
  ;; ABCL's real queued Lisp thread interruption is asynchronous. The handler
  ;; stays dynamically installed until delivery, without a helper-thread join.
  (loop (sleep 0.01)))
#+abcl
(unless *native-simulation*
  (error "ABCL supports native Lisp thread interrupts, not this OS SIGINT fixture"))
(dotimes (cycle 2)
  (declare (ignorable cycle))
  (let ((prior (install-independent-hook)))
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (holai.runtime.stdlib:catch-break t)
    (let ((installed (current-native-hook)))
      (holai.runtime.stdlib:catch-break t)
      (assert-prior-identity installed))
    #+sbcl
    (let ((*forwarded-condition* (make-condition 'simple-condition))
          (*forwarded-hook* prior))
      (unless (catch 'unrelated-forwarded
                (invoke-debugger *forwarded-condition*) nil)
        (error "Adapter did not forward unrelated debugger condition")))
    (handler-case
        (await-interrupt "SIGINT catch ready")
      (holai.runtime.stdlib:sys_break ()
        (assert-installer) (incf *interrupt-checks*))
      (previous-interrupt ()
        (error "Previous hook ran while catch-break was enabled")))
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (holai.runtime.stdlib:catch-break nil)
    (assert-prior-identity prior)
    (unless (zerop *previous-deliveries*)
      (error "Previous hook ran during adapter catches")))
  (unless *native-simulation* (write-line "SIGINT adapter check passed")))
(handler-case
    (await-interrupt "SIGINT previous hook ready")
  (previous-interrupt ()
    (assert-installer)
    (unless (= *previous-deliveries* 1)
      (error "Expected exactly one independent prior-hook delivery"))
    (incf *interrupt-checks*)
    (unless *native-simulation*
      (write-line "SIGINT previous hook restored") (finish-output)))
  (holai.runtime.stdlib:sys_break ()
    (error "Sys.Break leaked after catch-break was disabled")))
(unless (= *interrupt-checks* 3) (error "Incomplete interrupt lifecycle"))
(when *native-simulation*
  (format t "Native interrupt checks passed: ~D~%" *interrupt-checks*)
  (finish-output))
(uiop:quit 0)
