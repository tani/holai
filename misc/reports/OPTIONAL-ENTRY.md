> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname. Prepare the historical OPTIONAL baseline from commit 1730c0299f7d677ba25be29d2dfbff0538fea354, using that revision’s scripts/prepare-optional-baseline.py; current misc/scripts/measure-optional.py selects each checkout’s own matching benchmark/API.

# OPTIONAL/supplied-p curried entries: 1.0.0-defunc-optional

Only the shared calling-entry implementation changes. defunc, lambdac, labelsc
and fletc retain ordinary CL function values and the same curried protocol.
No fixed worker, callc, call-site specialization, global arity lookup, compare
annotation, optimization-policy change or data-representation change is added.
The OCaml translator and all94generated files match the restored list-tuples
release byte for byte. rt:funcall, partial and native adapter caching are unchanged.

## Implementation

A three-argument function conceptually receives:

```lisp
(&optional (a nil a-p) (b nil b-p) (c nil c-p) &rest excess)
```

The complete branch checks only c-p, evaluates the original body exactly once,
retains its primary value and applies excess arguments to that returned value.
The insufficient branch selects the supplied prefix and invokes existing partial
with the captured function object. NIL arguments are distinct from omission.
Arity0 uses REST only and executes its body immediately as before.
Fletc closure initializers remain outside the new function-name scope; forwarding
entries use this same generator and CL:FUNCALL with complete parameters. Partial
applications retain the initializer closure, as in the original fletc protocol.
Global named calls still go through the replaceable FDEFINITION; old function
values and old partial closures continue to use their captured definitions.

## Validation

27existing protocol checks +84additional OPTIONAL boundary checks +16tuple
checks +122native checks passed. All46core inputs initialize, with exactly
22types/303constants/263definitions/3axioms and unchanged source axioms.
All1124OCaml/SBCL observation rows match. The existing documented initialization
message difference remains accepted; raw OCaml/SBCL transcripts are not equal.
All94clean-generated files match; source pins, map validation,10rejections and
deterministic regeneration pass. Baseline initializes independently from its
own old-macro FASLs and is not a runtime override of new generated FASLs.

## Disassembly

Displayed function-body sizes for a three-argument addition example:

| Entry | Before | OPTIONAL |
|---|---:|---:|
| defunc | 329 bytes | 211 bytes |
| named caller | 40 bytes | 40 bytes |
| lambdac | 329 bytes | 211 bytes |
| labelsc | 329 bytes | 211 bytes |
| fletc forwarding | 78 bytes | 382 bytes |

LENGTH/list walking and POP parameter extraction are removed from source-function
entries. Supplied-p checks remain in the displayed generic entry; complete calls
are not universally transformed into branch-free fixed calls. Fletc forwarding
code grows. SBCL optional-argument dispatch/XEP code is not fully accounted for
by these displayed body sizes; this table is not total code-image size.
Use optional-before.asm/optional-after.asm and optional-inspect.lisp for evidence.
Actual allocation measurements, not body size alone, determine the benefit.

## Whole-core measurements

Sequential fresh processes in OPTIONAL→baseline→baseline→OPTIONAL order.
FASL-only, no saved heap, zero source compilation,46loaded files, same final counts.
No compiler or other benchmark ran in parallel with these measurements.

| Run | Start-to-exit | Core CPU | Core GC | Peak RSS | Cumulative core allocation |
|---|---:|---:|---:|---:|---:|
| optional 1 | 81.876s | 81.574s | 3.261s | 243.492MiB | 55,728,067,232 bytes |
| baseline 1 | 98.261s | 97.978s | 5.650s | 208.262MiB | 113,611,753,552 bytes |
| baseline 2 | 97.419s | 97.121s | 5.730s | 209.562MiB | 113,611,417,920 bytes |
| optional 2 | 82.039s | 81.748s | 3.250s | 243.969MiB | 55,728,246,304 bytes |

| Median metric | Baseline | OPTIONAL |
|---|---:|---:|
| Start-to-exit | 97.840 s | 81.957 s |
| Core CPU | 97.549 s | 81.661 s |
| Core GC | 5.690 s | 3.255 s |
| Peak RSS | 208.912 MiB | 243.730 MiB |
| Cumulative allocation | 113611585736.000 bytes | 55728156768.000 bytes |

Elapsed-time median shortened **16.23%**; cumulative core allocation
fell **50.95%**. Median peak RSS changed **+16.67%**.
Allocation is not resident memory or peak memory. Peak RSS is per-child Linux
wait4.ru_maxrss in KiB. An observed RSS increase must not be described as a
memory reduction merely because fewer bytes were allocated.
Two trials per variant do not establish statistical significance. Independent
roots/caches may affect layout; the comparison is not a universal speed claim.
The already-recorded OCamlopt native timing remains a historical comparison,
not a new contemporaneous native measurement in this experiment.

## Isolated calling-protocol benchmarks

Three trials per variant in separate processes; same addition bodies and counts.
Function construction/warmup are outside the loop except explicitly named
partial-create-call and excess cases. Result checks require6 in all cases.
The body still uses ordinary generic arithmetic and default SBCL optimization.
Whole process order is baseline then OPTIONAL, so these are diagnostic rather
than fully interleaved statistical benchmarks. Full GC precedes each loop.

| Case | Baseline CPU median | OPTIONAL CPU median | CPU ratio baseline/OPTIONAL | Baseline allocated | OPTIONAL allocated |
|---|---:|---:|---:|---:|---:|
| excess | 0.014351s | 0.006698s | 2.143x | 33,562,112 bytes | 9,568,256 bytes |
| flet-complete | 0.034453s | 0.017738s | 1.942x | 95,993,216 bytes | 0 bytes |
| global-complete | 0.037393s | 0.017251s | 2.168x | 95,975,424 bytes | 0 bytes |
| labels-complete | 0.033409s | 0.015448s | 2.163x | 95,993,216 bytes | 0 bytes |
| lambda-complete | 0.038623s | 0.016630s | 2.322x | 95,975,424 bytes | 0 bytes |
| partial-create-call | 0.022976s | 0.013800s | 1.665x | 47,964,928 bytes | 28,750,336 bytes |
| partial-existing | 0.038326s | 0.028637s | 1.338x | 95,975,424 bytes | 47,987,712 bytes |
| runtime-funcall | 0.029154s | 0.012021s | 2.425x | 47,987,712 bytes | 0 bytes |

## Reproduction and build capacity

Use make test to compile/initialize/check the complete corpus. The full native
compile+corpus validation process and compile-core.sh use2GiB dynamic-space
capacity; the minimum necessary compiler capacity is not established here.
There are no compiler-GC hooks or NOTINLINE workarounds. Timed whole-core
processes use default1GiB capacity and256MiB control stack. These capacities
are not measured RSS. Compilation is outside timing.

Prepare a fresh independent baseline with
`python3 scripts/prepare-optional-baseline.py --output /absolute/new-baseline`.
Then run `python3 scripts/measure-optional.py --baseline /absolute/new-baseline`.
The included optional-baseline-core.lisp is the exact runtime used for the
baseline; the rest of production sources/generated files are shared identical
bytes. Baseline/candidate SHA256 hashes and raw logs accompany the report.
The package retains DESIGN.md, AGENTS.md and all translator/runtime sources.
