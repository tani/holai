(require :asdf)
(asdf:initialize-source-registry `(:source-registry (:directory ,(truename ".")) :inherit-configuration))
(setf *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "hol2cl-runtime")
(in-package :hol2cl.runtime)
(defvariant inspection-term (InspectionVar name ty) (InspectionComb left right))
(defunc inspect-pattern (tm)
  (match tm
    ((InspectionComb (InspectionVar name _) arg) (tuple name arg))
    (_ nil)))
(pprint (macroexpand-1 '(match tm
                       ((InspectionComb (InspectionVar name _) arg) (tuple name arg))
                       (_ nil))))
(disassemble #'inspect-pattern)
