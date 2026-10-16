(load (merge-pathnames "bootstrap.lisp" *load-truename*))
(asdf:load-system "holai/user")
(load (merge-pathnames "user-contracts.lisp" *load-truename*))
(uiop:symbol-call :holai.tests.user-contracts :run-contract-tests)
