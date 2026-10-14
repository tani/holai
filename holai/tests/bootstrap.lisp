(require :asdf)
(uiop:define-package :holai.tests.bootstrap (:use :cl))
(in-package :holai.tests.bootstrap)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai")
(unless (holai.runtime.core:= (holai.fusion:axioms holai.runtime.data:unit)
                         (list holai.nums:INFINITY_AX holai.class:SELECT_AX holai.class:ETA_AX))
  (error "Standard-core startup contains an unexpected source axiom"))
