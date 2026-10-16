;; Regenerate the public binding inventory against the initialized pinned core.
(load (merge-pathnames "bootstrap.lisp" *load-truename*))
(asdf:load-system "holai/user")
(let* ((root (asdf:system-source-directory "holai"))
       (path (merge-pathnames "docs/USER-DSL-NATIVE-DESCRIPTORS.tsv" root))
       (descriptors (holai.user:standard-descriptors))
       (*package* (find-package :cl-user)))
  (with-open-file (stream path :direction :output :if-exists :supersede)
    (format stream "owner~csymbol~ckind~cterm-constant~capplication~%" #\Tab #\Tab #\Tab #\Tab)
    (dolist (entry descriptors)
      (format stream "~a~c~s~c~(~a~)~c~a~c~(~a~)~%"
              (getf entry :owner) #\Tab (getf entry :symbol) #\Tab
              (getf entry :kind) #\Tab (or (getf entry :term-constant) "") #\Tab
              (getf entry :application))))
  (format t "User standard descriptors written: ~d~%" (length descriptors)))
