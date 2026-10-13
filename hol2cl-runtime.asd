(asdf:defsystem "hol2cl-runtime"
  :description "Small compatibility boundary for structurally translated HOL Light"
  :version "1.0.0"
  :license "MIT; Random section LGPL-2.1 with OCaml linking exception"
  :depends-on ("trivia.trivial")
  :serial t
  :components ((:file "runtime/package") (:file "runtime/core") (:file "runtime/format") (:file "runtime/stdlib")))
