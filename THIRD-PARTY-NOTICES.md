# Third-party source and licenses

The revision lock is `vendor/SOURCES.json`. Vendored sources are unmodified.

| Source | Location | Retained license / notice |
| --- | --- | --- |
| HOL Light | `vendor/hol-light/` | BSD notice in `vendor/hol-light/LICENSE` |
| HOL Light grammar, derived from Camlp5 | `vendor/hol-light/pa_j_4.xx_8.02.ml` | INRIA copyright and `vendor/CAMLP5-COPYRIGHT` |
| Generated HOL Light library/kernel | `holai/generated/` | Original headers and `vendor/hol-light/LICENSE` |
| OCaml 4.14.1 standard-library Map and Set | `vendor/ocaml-stdlib/map.ml`, `set.ml`; instantiated within `holai/generated/nets.lisp` and `holai/generated/metis.lisp` | LGPL-2.1 with the OCaml linking exception; `vendor/ocaml-stdlib/COPYRIGHT` and `LGPL-2.1` |
| OCaml 4.14.1 seeded Random algorithms | `vendor/ocaml-stdlib/random.ml`, translated Random section in `holai/runtime/stdlib.lisp` | Damien Doligez / INRIA, copyright 1996; LGPL-2.1 with the OCaml linking exception, same retained notices |

The production runtime has no external pattern-library dependency. Former Trivia dependencies and their original licenses are available in
Git commit1730c0299f7d677ba25be29d2dfbff0538fea354 for historical reproduction;
they are not shipped in the current version.
OCaml, Camlp5 binaries, and SBCL are prerequisites and are not shipped as
machine binaries in this release.

The Map/Set specializations translate selected whole declarations from the original
source, without changing their bodies. The original OCaml source and its license
are included so the generated specialization is traceable and reproducible.

The Random section preserves the original seeded init, bits and int algorithms
and default state. Its raw-byte MD5 operation uses SBCL's bundled SB-MD5 module.
The remaining new translator/runtime code is MIT licensed.
