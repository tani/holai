(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root)
      (:directory ,(merge-pathnames "holai/generated/" root))
      :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai-generated")
(unless (holai.runtime:= (holai.fusion:axioms holai.runtime:unit)
                         (list holai.nums:INFINITY_AX holai.class:SELECT_AX holai.class:ETA_AX))
  (error "Standard-core startup contains an unexpected source axiom"))
