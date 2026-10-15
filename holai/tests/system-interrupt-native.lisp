;; Exercise native Lisp interrupt delivery, independently of OS SIGINT routing.
;; The shared lifecycle requires two Sys.Break catches and one delivery through
;; the exact independent hook restored after disable, then exits normally.
(let ((*features* (cons :holai-native-interrupt-test *features*)))
  (load (merge-pathnames "system-interrupt.lisp" *load-truename*)))
