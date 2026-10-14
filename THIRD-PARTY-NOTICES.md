# Third-party source and licenses

The revision lock is `vendor/SOURCES.json`. Vendored sources are unmodified.

| Source | Location | Retained license / notice |
| --- | --- | --- |
| HOL Light | `vendor/hol-light/` | BSD notice in `vendor/hol-light/LICENSE` |
| HOL Light grammar, derived from Camlp5 | `vendor/hol-light/pa_j_4.xx_8.02.ml` | INRIA copyright and `vendor/CAMLP5-COPYRIGHT` |
| Generated HOL Light library/kernel | `generated/` | Original headers and `vendor/hol-light/LICENSE` |
| OCaml 4.14.1 standard-library Map and Set | `vendor/ocaml-stdlib/map.ml`, `set.ml`; instantiated within `generated/nets.lisp` and `generated/metis.lisp` | LGPL-2.1 with the OCaml linking exception; `vendor/ocaml-stdlib/COPYRIGHT` and `LGPL-2.1` |
| OCaml 4.14.1 seeded Random algorithms | `vendor/ocaml-stdlib/random.ml`, translated Random section in `runtime/stdlib.lisp` | Damien Doligez / INRIA, copyright 1996; LGPL-2.1 with the OCaml linking exception, same retained notices |
| Trivia | `vendor/lisp/trivia/` | Original LLGPL `LICENSE` |
| lisp-namespace | `vendor/lisp/lisp-namespace/` | LLGPL, original source headers and ASDF declaration |
| trivial-cltl2 | `vendor/lisp/trivial-cltl2/` | LLGPL, original source headers and ASDF declaration |
| Alexandria | `vendor/lisp/alexandria/` | Original permissive headers and packaged copyright notices |
| closer-mop | `vendor/lisp/closer-mop/` | Original license headers and packaged copyright notices |

The production runtime has no external pattern-library dependency. Complete
vendored Trivia and its dependencies retain their original licenses for
historical benchmark reproduction; they are not loaded by hol2cl-runtime.
OCaml, Camlp5 binaries, and SBCL are prerequisites and are not shipped as
machine binaries in this release.

The Map/Set specializations translate selected whole declarations from the original
source, without changing their bodies. The original OCaml source and its license
are included so the generated specialization is traceable and reproducible.

The Random section preserves the original seeded init, bits and int algorithms
and default state. Its raw-byte MD5 operation uses SBCL's bundled SB-MD5 module.
The remaining new translator/runtime code is MIT licensed.
