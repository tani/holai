(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
              (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
   `(:source-registry (:directory ,root) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")
(in-package :holai.runtime)
(defvariant inspection-term (InspectionVar name ty) (InspectionComb left right))
(defunc inspect-pattern (tm)
  (match tm
    ((InspectionComb (InspectionVar name _) arg) (tuple name arg))
    (_ nil)))
(pprint (macroexpand-1 '(match tm
                       ((InspectionComb (InspectionVar name _) arg) (tuple name arg))
                       (_ nil))))
(disassemble #'inspect-pattern)
