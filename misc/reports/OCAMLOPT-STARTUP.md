> Relocation note: this narrative and its measurements describe their original revision, not a new run. Raw evidence, hashes and old API/path attribution are preserved. Current layout/API is specified in docs/REPOSITORY-LAYOUT.md (repository-root relative); current scripts live in misc/scripts/ and Lisp tests in holai/tests/. Historical baseline commands/packages require their matching old checkout; rt: is explanatory shorthand, not an installed nickname.

# OCamlopt initialization measurement

Same unchanged pinned46-file HOL Light core through define.ml; OCaml4.14.1,
Num1.5 and actual Camlp58.02/pa_j. The initialization-only harness uses the
existing oracle's needs stub, float_sqrt alias and lexer transitions around
bignum_num.ml. Core initialization algorithms are unmodified. No fixtures run
inside the timed initialization. Compilation and linking are completed first.
No translator, production runtime or generated Lisp changes.

The native compiler uses default optimization settings, with no -O2/-O3,
flambda, unsafe operations or custom runtime/GC settings. -w -a only suppresses
warnings. Link unix.cmxa and nums.cmxa. A monolithic compilation initially hit
the compiler's stack limit; a64MiB compiler-only stack permits compilation in
21.490s. Timed executable processes use the inherited ordinary
stack limit and the original system.ml settings. Compilation time is excluded.

| Native run | Initialization wall | Initialization CPU | Start-to-exit | Peak RSS |
|---|---:|---:|---:|---:|
| 1 | 13.715s | 13.711s | 13.727s | 42.723MiB |
| 2 | 13.781s | 13.778s | 13.794s | 42.500MiB |
| 3 | 13.562s | 13.555s | 13.577s | 42.348MiB |
| Median | 13.715s | 13.711s | 13.727s | 42.500MiB |

Three sequential fresh native executable processes; no compilation during runs.
Internal wall/CPU timers start before the core and end after flushing its output,
before observing initial counts. Separate start-to-exit wall time is Python
perf_counter and includes process launch/exit plus observer output. Peak RSS is
per-child Linux wait4.ru_maxrss in KiB; it is neither allocation nor live heap.
Every run reaches22types/303constants/263definitions/3axioms. All initialization
messages match the existing original-OCaml transcript after normalization of
only CPU-duration numbers. Every vendor source digest is verified unchanged.
These are initialization checks, not a new full differential proof corpus run.

## Comparison with the restored SBCL version

| Measurement | OCamlopt median of3 | SBCL previous single run |
|---|---:|---:|
| Start-to-exit | 13.727s | 93.567s |
| Peak RSS | 42.500MiB | 199.230MiB |

The historical SBCL/OCamlopt elapsed-time ratio is 6.816x. Thus the earlier
rough1.5x statement relative to the bytecode oracle does not extend to ocamlopt.
The SBCL measurement is the unchanged defunc-list-tuples variant, FASL-only,
without restored heap and with zero compilation. The SBCL result was not rerun
contemporaneously, so this is a cross-run indication, not an interleaved paired
comparison. There are only3native trials and1historical SBCL trial.

Reproduce with `python3 misc/scripts/measure-ocamlopt.py` after `make build` and with
OCaml/Camlp5/Num available. The script defaults to the toolchain on PATH and
accepts CAMLPLIB. Compiler command, source hash, raw logs and all measurements
are retained in ocamlopt-startup.json, ocamlopt-build.txt and run1/run2/run3.txt.
The source harness and executable are regenerable scratch build products.
