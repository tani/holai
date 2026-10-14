(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root)
      :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")
;; Each flushed readiness marker precedes a real SIGINT from the parent.
;; Re-enable after disabling, then require the third signal to use SIG_DFL.
(dotimes (cycle 2)
  (declare (ignorable cycle))
  (let (#+abcl (installing-thread (threads:current-thread)))
    (holai.runtime:catch-break t)
    (let ((caught (handler-case
                     (progn
                       (write-line "SIGINT catch ready")
                       (finish-output)
                       (loop (sleep 1)))
                   (holai.runtime:sys_break ()
                     #+abcl
                     (unless (eq installing-thread (threads:current-thread))
                       (error "Sys.Break delivered on a different Lisp thread"))
                     t))))
      (holai.runtime:catch-break nil)
      ;; Repeated disable must not overwrite CLISP's saved native handler.
      (holai.runtime:catch-break nil)
      (unless caught
        (error "SIGINT did not signal the OCaml-compatible break condition"))))
  (write-line "SIGINT adapter check passed"))
(write-line "SIGINT default ready")
(finish-output)
(loop (sleep 1))
