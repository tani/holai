> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname.

> Historical measurements for 1.0.0-structural-match, before percent naming and the remaining IGNORABLE declarations. Current diagnostic counts are in compile-diagnostics.json.

# Structural matching: 1.0.0-structural-match

The production ASDF runtime has no external pattern-library dependency.
Patterns are parsed/validated and compiled to standard CL at macro expansion.
Tuple lists, Variant/Record vectors, refs, conditions and curried source
function entries are unchanged. Every used access follows its type check.
Wildcard fields are not read. OR joins share guards/bodies, with guard failure
advancing to the next clause rather than retrying a structurally matched arm.

## Validation

- All 46 pinned HOL Light files compile, load and initialize in source order.
- 122 native, 27 protocol, 84 OPTIONAL, 16 tuple and 46 new pattern checks pass.
- 1,124 original OCaml/SBCL observation rows match, including existing scopes,
  local modules, constructor history, records, exceptions and original proofs.
- 194,839 core / 205,341 total source-map entries; ten rejection cases;
  deterministic regeneration; 94 clean-build outputs identical; pins unchanged.
- OR left priority and binding equality, alias identity, outer guard scope,
  guard/body exception propagation, typed literals, signed zero, SBCL NaN EQL
  compatibility, 128-wide tuples and 60-deep constructors are checked.
- Separate compile-file/load works. Loaded matches do not consult descriptors;
  reloading an old dependent FASL after declaration ABI changes rejects.
- runtime/src/generated contain no Trivia references. Historical source snapshots remain; licensed Lisp vendors are available
  in the baseline Git commit rather than the current tree.
- Final runtime refinement was followed by a fresh full differential validation;
  all 46 default-cache core FASLs were newer than the final macro source.

## Single-run comparison

Baseline is Git commit1730c0299f7d677ba25be29d2dfbff0538fea354, the existing
star-names/OPTIONAL/list-tuple Trivia implementation. Each backend has an
independent fresh cache. Compilation and FASL-only restart are separate child
processes; a hook rejects any ASDF compilation in the restart. Both initialize
22 types,303 constants,263 definitions and3 original axioms.

| Metric | Trivia | Structural |
|---|---:|---:|
| Compilation operations, all units (s) | 33.857 | 24.181 |
| Compilation operations, generated core only (s) | 32.685 | 23.797 |
| Cold compile + load process (s) | 112.681 | 111.217 |
| Cold process peak RSS (MiB) | 1822.102 | 1079.875 |
| All cached FASLs (MiB) | 19.936 | 20.807 |
| Generated core FASLs (MiB) | 18.826 | 20.538 |
| Fresh FASL startup (s) | 80.927 | 82.044 |
| Fresh startup peak RSS (MiB) | 239.762 | 205.594 |
| Core cumulative allocation (GiB) | 51.900 | 51.907 |

Compilation-operation time is 28.6% lower (27.2% for generated core alone).
Cold-process peak RSS is 40.7% lower, and fresh-startup peak RSS is14.3% lower.
Startup takes1.4% longer in this single comparison: there is no demonstrated
startup speed improvement. Core cumulative allocation is essentially unchanged
(+0.012%). Total cached FASL size increases4.4%; removal of the dependency does
not imply smaller generated machine code.

Cold peak RSS includes compilation **and prerequisite/core initialization**.
It is not an isolated compile-only RSS measurement. CPU/wall compile-operation
totals are timed around each ASDF compile operation, independently of loads.
Cold processes use2GiB dynamic-space capacity and256MiB control stack; fresh
restart uses default1GiB capacity and256MiB stack. These capacities are not RSS.
Peak RSS is per-child Linux wait4.ru_maxrss (KiB); allocation is a separate
SBCL bytes-consed total across46 core loads. The comparison is one serial run
per final backend, not a repeated ABBA experiment or statistical speed claim.

The original prototype had3942 style warnings. Wildcard-read elimination and
IGNORABLE bindings reduce the final cold build to97, versus324 in the baseline.
Neither final build has ordinary compiler warnings. No type declarations,
optimization policy changes or source algorithm transformations were added.
The sample nested-constructor function disassembles to444 bytes; its expansion
and assembly are retained in pattern-expansion-and-assembly.txt. Simple
structural patterns have no runtime continuation function; OR uses a fixed-
argument local FLET join with explicit values. Further OR/code-size optimizations
and data representation changes remain separate tasks.

## Reproduction

Run make test and make clean-build. Prepare an independent checkout/archive of
the baseline commit, then run:

```sh
python3 misc/scripts/measure-pattern.py --baseline /absolute/baseline
```

The caches _build/pattern-cache-trivia and _build/pattern-cache-structural must
be absent for a fresh measurement. Candidate-only remeasurement requires the
prior report and a fresh structural cache; it preserves the baseline evidence.
Raw compile/startup logs and runtime SHA256 hashes accompany the JSON report.
The provisional prototype summary is retained under misc/reports/history; its
measurement is not the final candidate result.

The complete ZIP retains DESIGN.md, AGENTS.md, translator/runtime sources,
generated Lisp and maps, tests, source pins, licenses and measured evidence.
