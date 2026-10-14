(asdf:defsystem "holai"
  :description "Structurally translated HOL Light"
  :version "1.0.0"
  :license "MIT; upstream sources retain their original licenses"
  :class :package-inferred-system
  :pathname "holai/"
  :depends-on ("holai/all"))

;; These five sources share a package and retain their explicit runtime order.
(asdf:defsystem "holai/runtime"
  :description "Small compatibility boundary for structurally translated HOL Light"
  :version "1.0.0"
  :license "MIT; Random section LGPL-2.1 with OCaml linking exception"
  :pathname "holai/runtime/"
  :serial t
  :components ((:file "package") (:file "pattern") (:file "core")
               (:file "format") (:file "stdlib")))

(asdf:register-system-packages "holai/runtime" '("HOLAI.RUNTIME"))

;; Every package in a generated source is provided by that source's inferred
;; system, including private children and packages with no public exports.
(dolist (entry (uiop:read-file-form
                (merge-pathnames "holai/generated/package-systems.sexp"
                                 (uiop:pathname-directory-pathname
                                   (or *load-truename* *compile-file-truename*)))))
  (asdf:register-system-packages
    (format nil "holai/generated/~A" (first entry)) (rest entry)))
