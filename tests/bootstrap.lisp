(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-directory-pathname *load-truename*))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root)
      (:directory ,(merge-pathnames "generated/" root))
      (:tree ,(merge-pathnames "vendor/lisp/" root)) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "hol2cl-generated")
(unless (hol2cl.runtime:= (hol2cl.fusion:axioms hol2cl.runtime:unit)
                         (list hol2cl.nums:INFINITY_AX hol2cl.class:SELECT_AX hol2cl.class:ETA_AX))
  (error "Standard-core startup contains an unexpected source axiom"))
