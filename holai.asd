(asdf:defsystem "holai/runtime"
  :description "Common Lisp compatibility runtime for Holai"
  :version "1.0.0"
  :license "MIT"
  :pathname "holai/runtime/"
  :serial t
  :components ((:file "data")
               (:file "pattern-registry")
               (:file "pattern")
               (:file "core")
               (:file "format")
               (:file "stdlib")))

(asdf:defsystem "holai"
  :description "Structurally translated HOL Light"
  :version "1.0.0"
  :license "MIT; upstream sources retain their original licenses"
  :depends-on ("holai/runtime")
  :pathname "holai/generated/"
  :serial t
  :components ((:file "system")
               (:file "lib")
               (:file "fusion")
               (:file "basics")
               (:file "nets")
               (:file "printer")
               (:file "preterm")
               (:file "parser")
               (:file "equal")
               (:file "bool")
               (:file "drule")
               (:file "tactics")
               (:file "itab")
               (:file "simp")
               (:file "theorems")
               (:file "ind_defs")
               (:file "class")
               (:file "trivia")
               (:file "canon")
               (:file "meson")
               (:file "firstorder")
               (:file "metis")
               (:file "thecops")
               (:file "quot")
               (:file "impconv")
               (:file "pair")
               (:file "compute")
               (:file "nums")
               (:file "recursion")
               (:file "arith")
               (:file "wf")
               (:file "calc_num")
               (:file "normalizer")
               (:file "grobner")
               (:file "ind_types")
               (:file "lists")
               (:file "realax")
               (:file "calc_int")
               (:file "realarith")
               (:file "real")
               (:file "calc_rat")
               (:file "int")
               (:file "sets")
               (:file "iterate")
               (:file "cart")
               (:file "define")))

(asdf:defsystem "holai/user"
  :description "Type-inferred HOL proof language"
  :version "1.0.0"
  :license "MIT"
  :depends-on ("holai")
  :pathname "holai/user/"
  :serial t
  :components ((:file "package")
               (:file "terms")
               (:file "proofs")
               (:file "definitions")
               (:file "resources")
               (:file "constructions")
               (:file "recursive-definitions")
               (:file "development"))
  :in-order-to ((asdf:test-op (asdf:test-op "holai/user/tests"))))

(asdf:defsystem "holai/user/tests"
  :depends-on ("holai/user")
  :pathname "holai/tests/"
  :serial t
  :components ((:file "user-dsl")
               (:file "user-definitions")
               (:file "user-advanced"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (uiop:symbol-call :holai.tests.user-dsl :run-tests)
             (uiop:symbol-call :holai.tests.user-dsl :run-definition-tests)
             (uiop:symbol-call :holai.tests.user-dsl :run-advanced-tests)))
