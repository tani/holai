(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
              (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
   `(:source-registry (:directory ,root) :inherit-configuration))
  (setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
  (asdf:load-system "holai/runtime")
  (load (merge-pathnames "_build/star-names/star_names.lisp" root)))
(dolist (name '("T%" "T%%" "NIL%" "PI%" "PI%%" "NAME" "NAME%" "NAME%%" "NAME%%%"))
  (unless (eq :external (nth-value 1 (find-symbol name :holai.star_names)))
    (error "Missing allocated export: ~a" name)))
(format t "~&__STAR_OBSERVATIONS__~%")
(dolist (line (holai.star_names:observations holai.runtime:unit)) (write-line line))
