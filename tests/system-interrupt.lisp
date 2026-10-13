(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-directory-pathname *load-truename*))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root)
      (:tree ,(merge-pathnames "vendor/lisp/" root)) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "hol2cl-runtime")
(hol2cl.runtime:catch-break t)
(let ((caught (handler-case
                 (progn
                   (sb-unix:unix-kill (sb-unix:unix-getpid) sb-unix:sigint)
                   (sleep 0.1) nil)
               (hol2cl.runtime:sys_break () t))))
  (hol2cl.runtime:catch-break nil)
  (unless caught (error "SIGINT did not signal the OCaml-compatible break condition")))
(format t "SIGINT adapter check passed~%")
