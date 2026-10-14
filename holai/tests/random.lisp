;;;; Behavioral checks for the standard Common Lisp Random source API.
(require :asdf)
(let ((root (uiop:pathname-parent-directory-pathname
             (uiop:pathname-parent-directory-pathname
               (uiop:pathname-directory-pathname *load-truename*)))))
  (asdf:initialize-source-registry
    `(:source-registry (:directory ,root) :inherit-configuration)))
(setf asdf:*asdf-verbose* nil *compile-verbose* nil *load-verbose* nil)
(asdf:load-system "holai/runtime")

(defpackage :holai.tests.random (:use :cl))
(in-package :holai.tests.random)

(defvar *random-checks* 0)
(defun check-random (test description)
  (incf *random-checks*)
  (unless test (error "Standard Random check failed: ~A" description)))

;; All source and host draws are isolated from the enclosing test process.
(let* ((*random-state* (make-random-state *random-state*))
       (holai.runtime.stdlib::*source-random-state*
         (make-random-state holai.runtime.stdlib::*source-random-state*)))
  (check-random (random-state-p holai.runtime.stdlib::*source-random-state*)
                "private state is a standard RANDOM-STATE")

  ;; Exact cloned-state comparisons prove use of the actual host engine and
  ;; advancement after every call, without requiring a particular sequence.
  (let ((expected (make-random-state holai.runtime.stdlib::*source-random-state*)))
    (dotimes (i 128)
      (declare (ignorable i))
      (let ((bits (holai.runtime.stdlib:random-bits holai.runtime.data:unit)))
        (check-random (and (integerp bits) (<= 0 bits) (< bits #x40000000))
                      "bits is a nonnegative 30-bit integer")
        (check-random (= bits (random #x40000000 expected))
                      "bits advances the standard engine"))
      (dolist (bound '(1 2 3 97 65537 #x3fffffff))
        (let ((value (holai.runtime.stdlib:random-int bound)))
          (check-random (and (integerp value) (<= 0 value) (< value bound))
                        "int stays within the requested bound")
          (check-random (= value (random bound expected))
                        "int advances the standard engine")))))

  ;; Invalid source bounds preserve the exception and do not consume state.
  (let ((expected (make-random-state holai.runtime.stdlib::*source-random-state*)))
    (dolist (bound '(-7 -1 0 #x40000000 #x40000001))
      (check-random
        (handler-case (progn (holai.runtime.stdlib:random-int bound) nil)
          (holai.runtime.core:invalid_argument (condition)
            (string= "Random.int"
                     (holai.runtime.core::invalid_argument-message condition))))
        "invalid integer bounds retain Random.int Invalid_argument"))
    (check-random
      (= (holai.runtime.stdlib:random-bits holai.runtime.data:unit)
         (random #x40000000 expected))
      "rejected bounds leave the state unchanged"))

  ;; A copied snapshot replays a mixed source-API stream within this host.
  (let* ((snapshot (make-random-state holai.runtime.stdlib::*source-random-state*))
         (first-pass
           (loop repeat 32 collect
             (list (holai.runtime.stdlib:random-bits holai.runtime.data:unit)
                   (holai.runtime.stdlib:random-int 97)))))
    (setf holai.runtime.stdlib::*source-random-state* (make-random-state snapshot))
    (check-random
      (equal first-pass
             (loop repeat 32 collect
               (list (holai.runtime.stdlib:random-bits holai.runtime.data:unit)
                     (holai.runtime.stdlib:random-int 97))))
      "a standard-state snapshot replays the source stream"))


  ;; INIT accepts the source integer signature but has no integer-seed replay
  ;; promise. Test replacement/type/unit, never freshness by stream inequality.
  (dolist (seed '(0 1 -7 4611686018427387903))
    (let ((previous holai.runtime.stdlib::*source-random-state*))
      (check-random (eq (holai.runtime.stdlib:random-init seed) holai.runtime.data:unit)
                    "init returns the source unit value")
      (check-random (and (random-state-p holai.runtime.stdlib::*source-random-state*)
                         (not (eq previous holai.runtime.stdlib::*source-random-state*)))
                    "init replaces the private standard state")
      (let ((expected (make-random-state holai.runtime.stdlib::*source-random-state*)))
        (check-random
          (= (holai.runtime.stdlib:random-bits holai.runtime.data:unit)
             (random #x40000000 expected))
          "initialized bits uses the standard engine")
        (check-random (= (holai.runtime.stdlib:random-int 97) (random 97 expected))
                      "initialized int uses the standard engine")))))

(format t "~&Standard Random checks passed: ~D~%" *random-checks*)
