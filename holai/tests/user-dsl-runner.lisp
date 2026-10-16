;; Bootstrap requires ASDF before the reader reaches the second form.
(load (merge-pathnames "bootstrap.lisp" *load-truename*))
(asdf:test-system "holai/user")
