;;;; Run in a fresh Lisp process: never unwind out of a FASL initializer.
(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")
;; Replay the consumer declaration with the same symbol identities in a fresh process.
(uiop:define-package :holai.tests.pattern (:use :cl) (:intern :separate :value))
(uiop:define-package :holai.tests.pattern-stale
  (:use :cl)
  (:shadowing-import-from :holai.tests.pattern :separate :value)
  (:shadowing-import-from :holai.runtime.core :defvariant :defrecord :define-exception :funcall := :< :>)
  (:shadowing-import-from :holai.runtime.data :ref :ref-contents :unit :tuple :match-failure)
  (:shadowing-import-from :holai.runtime.pattern :match :character-code :guard))
(in-package :holai.tests.pattern-stale)

(defvariant separate (Separate value))
(let* ((path (or (uiop:getenv "HOLAI_PATTERN_STALE_FASL")
                 (error "HOLAI_PATTERN_STALE_FASL is required")))
       (consumer (truename path)))
  ;; The consumer was compiled against the actual Separate declaration. Only
  ;; its load-time ABI check, not a file error or arbitrary load error, counts.
  (setf (gethash 'Separate holai.runtime.pattern-registry::*pattern-descriptions*)
        (list :class 'bogus :arity 1))
  (handler-bind
      ((holai.runtime.pattern-registry::pattern-declaration-changed
         (lambda (condition)
           (unless (eq (holai.runtime.pattern-registry::pattern-declaration-name condition) 'Separate)
             (error "Unexpected stale declaration: ~S"
                    (holai.runtime.pattern-registry::pattern-declaration-name condition)))
           (write-line "Pattern stale FASL rejected: Separate")
           (finish-output)
           ;; Terminate inside the signaling handler: HANDLER-CASE would
           ;; transfer across ABCL's reflected Java class initializer.
           ;; UIOP:QUIT throws a Lisp transfer on ABCL; Java reflection would
           ;; wrap it instead of terminating this isolated rejection process.
           #+abcl (java:jstatic "exit" "java.lang.System" 17)
           (uiop:quit 17))))
    (load consumer))
  (error "Stale pattern consumer unexpectedly loaded: ~A" consumer))
