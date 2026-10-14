# Pinned HOL Light core inventory

46/46 files parsed; 46 structurally lowered in this scan; 46 compiled/loaded for the release differential corpus on SBCL.

Every pinned manifest input is compiled, initialized and included in the original-execution differential corpus on SBCL only. Other selected hosts have the bounded runtime-fixtures profile described separately below; that profile does not verify core loading, initialization or differential execution. The scan itself does not execute inputs; compilation and corpus states come from the separately recorded passed SBCL verification and implementation matrix.

system.ml uses the documented per-host startup capacities, logical GC-control record and real interrupt adapter. The immutable manifest supplies the loader order. Generic OCaml/runtime completeness is outside this profile.

Source Random uses private standard Common Lisp RANDOM state passed explicitly to draws; init ignores integer seeds and resets with MAKE-RANDOM-STATE T, without seed replay guarantees. Fresh-state creation may consume host entropy or the default RNG; default-RNG entropy isolation is not claimed. Only language_random= is shape/range validated and canonicalized. The init_constants and init_definitions rows compare structurally using a shared generated-name identity map; all remaining rows compare exactly. Raw and canonical streams are preserved.

sbcl: 1146 exact rows + 2 structurally compared initial-registry rows + 1 property-validated Random row = 1149 total.

## Bounded host compatibility

These passed runtime-fixtures reports are not full-core verification. Counts below are measured per host; subprocess guards are taken from each report.

- abcl (Armed Bear Common Lisp 1.9.3): profile `runtime-fixtures`, 120s guard; structural_pattern_checks=46, defunc_protocol_checks=28, optional_entry_checks=84, tuple_list_checks=16, standard_random_checks=1816, system_interrupt_deliveries=3, fixture_sources=3, translated_fixture_units=3, star_naming_observations=9, differential_observations=33, exact_differential_observations=33.
- ecl (ECL 21.2.1): profile `runtime-fixtures`, 120s guard; structural_pattern_checks=45, defunc_protocol_checks=28, optional_entry_checks=84, tuple_list_checks=16, standard_random_checks=1816, system_interrupt_deliveries=3, fixture_sources=3, translated_fixture_units=3, star_naming_observations=9, differential_observations=33, exact_differential_observations=33.
- clisp (CLISP 2.49.95+ (2024-11-03) (built on localhost [127.0.0.1])): profile `runtime-fixtures`, 120s guard; structural_pattern_checks=45, defunc_protocol_checks=28, optional_entry_checks=84, tuple_list_checks=16, standard_random_checks=1816, system_interrupt_deliveries=3, fixture_sources=3, translated_fixture_units=3, star_naming_observations=9, differential_observations=33, exact_differential_observations=33.

- ccl: unavailable — Unsupported platform aarch64-linux.
- mkcl: unavailable — Marked broken; actual allowBroken MKCL1.1.11 build failed: tinycc/lib-arm64.c:17 implicit declaration __arm64_clear_cache.
- cmucl_binary: unavailable — Package attribute missing or evaluation failed.
- clasp-common-lisp: unavailable — Unsupported platform aarch64-linux.

## Per-input core inventory

Reproduce with `make test inventory`. Raw counts and source diagnostics are in sibling `core-inventory.json`; the repository-root-relative load manifest is `vendor/CORE_FILES.json`.

| File | Parsed | Lowered | Implementations loaded | First blocker |
| --- | --- | --- | --- | --- |
| `system.ml` | yes | yes | sbcl | — |
| `lib.ml` | yes | yes | sbcl | — |
| `fusion.ml` | yes | yes | sbcl | — |
| `basics.ml` | yes | yes | sbcl | — |
| `nets.ml` | yes | yes | sbcl | — |
| `printer.ml` | yes | yes | sbcl | — |
| `preterm.ml` | yes | yes | sbcl | — |
| `parser.ml` | yes | yes | sbcl | — |
| `equal.ml` | yes | yes | sbcl | — |
| `bool.ml` | yes | yes | sbcl | — |
| `drule.ml` | yes | yes | sbcl | — |
| `tactics.ml` | yes | yes | sbcl | — |
| `itab.ml` | yes | yes | sbcl | — |
| `simp.ml` | yes | yes | sbcl | — |
| `theorems.ml` | yes | yes | sbcl | — |
| `ind_defs.ml` | yes | yes | sbcl | — |
| `class.ml` | yes | yes | sbcl | — |
| `trivia.ml` | yes | yes | sbcl | — |
| `canon.ml` | yes | yes | sbcl | — |
| `meson.ml` | yes | yes | sbcl | — |
| `firstorder.ml` | yes | yes | sbcl | — |
| `metis.ml` | yes | yes | sbcl | — |
| `thecops.ml` | yes | yes | sbcl | — |
| `quot.ml` | yes | yes | sbcl | — |
| `impconv.ml` | yes | yes | sbcl | — |
| `pair.ml` | yes | yes | sbcl | — |
| `compute.ml` | yes | yes | sbcl | — |
| `nums.ml` | yes | yes | sbcl | — |
| `recursion.ml` | yes | yes | sbcl | — |
| `arith.ml` | yes | yes | sbcl | — |
| `wf.ml` | yes | yes | sbcl | — |
| `calc_num.ml` | yes | yes | sbcl | — |
| `normalizer.ml` | yes | yes | sbcl | — |
| `grobner.ml` | yes | yes | sbcl | — |
| `ind_types.ml` | yes | yes | sbcl | — |
| `lists.ml` | yes | yes | sbcl | — |
| `realax.ml` | yes | yes | sbcl | — |
| `calc_int.ml` | yes | yes | sbcl | — |
| `realarith.ml` | yes | yes | sbcl | — |
| `real.ml` | yes | yes | sbcl | — |
| `calc_rat.ml` | yes | yes | sbcl | — |
| `int.ml` | yes | yes | sbcl | — |
| `sets.ml` | yes | yes | sbcl | — |
| `iterate.ml` | yes | yes | sbcl | — |
| `cart.ml` | yes | yes | sbcl | — |
| `define.ml` | yes | yes | sbcl | — |
