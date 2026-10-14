# Retained upstream inputs

This directory contains the pinned translation inputs, their licenses and
sources needed to reproduce or inspect the retained implementation. The
production Common Lisp runtime has no external Lisp-library dependency.

| Item | Purpose |
|---|---|
| `hol-light/*.ml` listed in `CORE_FILES.json` | The 46 unchanged translation inputs, also run by the original OCaml oracle |
| `hol-light/pa_j_4.xx_8.02.ml` | The real Camlp5 HOL Light grammar used to build the translator |
| `hol-light/bignum_num.ml` | Num support for the original OCaml oracle |
| `hol-light/hol_lib.ml` | Original load manifest, checked against `CORE_FILES.json` |
| `ocaml-stdlib/map.ml`, `set.ml` | Original whole declarations used as specialization templates by the translator |
| `ocaml-stdlib/random.ml` | Original seeded Random algorithms translated in `holai/runtime/stdlib.lisp`, retained as provenance |
| Licenses and `CAMLP5-COPYRIGHT` | Notices for the retained originals and derived code |
| `SOURCES.json` | Active revisions, original-input hashes and toolchain information |

`hol-light/trivia.ml` is a HOL Light theory input. It is unrelated to the
former Common Lisp Trivia pattern library and remains part of the core.

The removed `lisp/` directory contained Trivia, lisp-namespace, trivial-cltl2,
Alexandria and closer-mop. For historical comparisons, use an independent
checkout of commit `1730c0299f7d677ba25be29d2dfbff0538fea354`, which retains
those exact dependencies and their original license notices. Current scripts
must not search the removed directory.
