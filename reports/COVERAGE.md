# Pinned HOL Light core inventory

46/46 files parsed; 46 structurally lowered in this scan; 46 compiled/loaded for the release differential corpus.

Every pinned manifest input is compiled, initialized and included in the original-execution differential corpus for the complete standard-core release. The scan itself does not execute inputs; compilation and corpus states come from the separately recorded verification results.

system.ml is translated with the documented SBCL startup stack, logical GC-control record and interrupt adapter. The immutable manifest supplies the loader order. Generic OCaml/runtime completeness is outside this profile.

Reproduce with `make test inventory`. Raw counts and source diagnostics are in `core-inventory.json`; the load manifest is `vendor/CORE_FILES.json`.

| File | Parsed | Lowered | SBCL loaded | First blocker |
| --- | --- | --- | --- | --- |
| `system.ml` | yes | yes | yes | — |
| `lib.ml` | yes | yes | yes | — |
| `fusion.ml` | yes | yes | yes | — |
| `basics.ml` | yes | yes | yes | — |
| `nets.ml` | yes | yes | yes | — |
| `printer.ml` | yes | yes | yes | — |
| `preterm.ml` | yes | yes | yes | — |
| `parser.ml` | yes | yes | yes | — |
| `equal.ml` | yes | yes | yes | — |
| `bool.ml` | yes | yes | yes | — |
| `drule.ml` | yes | yes | yes | — |
| `tactics.ml` | yes | yes | yes | — |
| `itab.ml` | yes | yes | yes | — |
| `simp.ml` | yes | yes | yes | — |
| `theorems.ml` | yes | yes | yes | — |
| `ind_defs.ml` | yes | yes | yes | — |
| `class.ml` | yes | yes | yes | — |
| `trivia.ml` | yes | yes | yes | — |
| `canon.ml` | yes | yes | yes | — |
| `meson.ml` | yes | yes | yes | — |
| `firstorder.ml` | yes | yes | yes | — |
| `metis.ml` | yes | yes | yes | — |
| `thecops.ml` | yes | yes | yes | — |
| `quot.ml` | yes | yes | yes | — |
| `impconv.ml` | yes | yes | yes | — |
| `pair.ml` | yes | yes | yes | — |
| `compute.ml` | yes | yes | yes | — |
| `nums.ml` | yes | yes | yes | — |
| `recursion.ml` | yes | yes | yes | — |
| `arith.ml` | yes | yes | yes | — |
| `wf.ml` | yes | yes | yes | — |
| `calc_num.ml` | yes | yes | yes | — |
| `normalizer.ml` | yes | yes | yes | — |
| `grobner.ml` | yes | yes | yes | — |
| `ind_types.ml` | yes | yes | yes | — |
| `lists.ml` | yes | yes | yes | — |
| `realax.ml` | yes | yes | yes | — |
| `calc_int.ml` | yes | yes | yes | — |
| `realarith.ml` | yes | yes | yes | — |
| `real.ml` | yes | yes | yes | — |
| `calc_rat.ml` | yes | yes | yes | — |
| `int.ml` | yes | yes | yes | — |
| `sets.ml` | yes | yes | yes | — |
| `iterate.ml` | yes | yes | yes | — |
| `cart.ml` | yes | yes | yes | — |
| `define.ml` | yes | yes | yes | — |
