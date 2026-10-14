(asdf:defsystem "holai-runtime"
  :description "Small compatibility boundary for structurally translated HOL Light"
  :version "1.0.0"
  :license "MIT; Random section LGPL-2.1 with OCaml linking exception"
  :serial t
  :components ((:file "holai/runtime/package") (:file "holai/runtime/pattern") (:file "holai/runtime/core") (:file "holai/runtime/format") (:file "holai/runtime/stdlib")))
