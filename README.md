# Holai

Holai translates the pinned HOL Light standard core from OCaml to readable
Common Lisp for **SBCL**. The translator itself is written in OCaml.
It preserves source bindings, scopes, declaration order and recursive
algorithms. It accepts Common Lisp's argument evaluation order rather than
adding temporaries to reproduce OCaml's order.

The supported profile is the 46 unchanged files listed in
[`vendor/CORE_FILES.json`](vendor/CORE_FILES.json), through `define.ml`.
This is not a general-purpose OCaml compiler or support for every HOL Light
extension. See [DESIGN.md](DESIGN.md) for rules and limitations.

## Build and run

Prerequisites: OCaml 4.14.1, Camlp5 8.02, camlp-streams, Num 1.5, SBCL and
Python 3.9 or later. Validation used SBCL 2.2.9 on Linux. Matching is compiled
to standard Common Lisp by runtime/pattern.lisp; no external Lisp library is
required. Vendored Trivia sources remain only for historical comparisons.

```sh
make build                         # bin/hol2cl, built from the OCaml sources
make regenerate                    # Lisp, source maps and ASDF load manifest
make test                          # full OCaml/SBCL differential validation
make clean-build                   # isolated source build; compare 94 outputs
scripts/run-sbcl.sh                 # load the generated core in fresh SBCL
make release                       # validated source ZIP in dist/
```

Set `CAMLPLIB` and `STREAMLIB` when your Camlp5/camlp-streams installation is
not found by the Makefile. Cold core compilation uses a 2 GiB SBCL heap capacity
in the test runner; `scripts/compile-core.sh` provides the same setting.
The core uses a 256 MiB control stack. Linux is required for the peak-RSS
measurement scripts, which use per-child `wait4.ru_maxrss`.

The existing `hol2cl` CLI, Lisp package names and ASDF systems are retained.
For example, `ocamlrun bin/hol2cl translate --output-dir generated <files...>`
translates inputs; `scan` reports supported constructs and source diagnostics.

## Generated names

Ordinary names stay unchanged. Primes become percent signs (`x'` → `x%`), reserved
binders become `t%`/`nil%`, and collisions add percent signs (`mk_comb` / `MK_COMB%`).
Allocated names are shared by definitions, references and exports. Generated
core source no longer requires `|...|` symbol quoting; literal strings are
unchanged. See [PERCENT-NAMES.md](reports/PERCENT-NAMES.md) for exact rules and examples.
Literal source operator stars and native special-variable names are retained.
Public Lisp spellings change in this version; update manually written callers
using the generated declarations. The OPTIONAL/OCamlopt and structural-match timing results predate this naming change.

## Current implementation and validation

Source functions use `defunc`, `lambdac`, `labelsc` and `fletc`. Their shared
OPTIONAL/supplied-p entry supports complete, partial and excess application.
Function values capture their original definitions; global named calls retain
runtime redefinition. Tuples keep their original argument list.
No fixed-worker or call-site specialization is enabled. Matching uses a static
IR at macro expansion time and standard Common Lisp control/binding forms.
Constructor/record descriptors are resolved before execution; guards and OR
binding joins preserve clause order. See [PATTERN-MATCH.md](reports/PATTERN-MATCH.md).

The validated corpus includes 122 native checks, 27 calling-protocol checks,
84 OPTIONAL-entry checks, 16 tuple checks, 46 structural-pattern checks and
1,124 matching OCaml/SBCL output
rows. All 46 inputs initialize with 22 types, 303 constants, 263 definitions
and 3 original axioms. The documented initialization-output difference is
retained; the raw OCaml/SBCL initialization transcripts are not identical.
See [verification.json](reports/verification.json) and
[COVERAGE.md](reports/COVERAGE.md).

Two fresh runs per version gave median FASL-only start-to-exit times of
97.840 s before the OPTIONAL change and 81.957 s after it. Cumulative core
allocation fell from 113.6 GB to 55.7 GB; peak RSS rose from 208.9 MiB to
243.7 MiB. Allocation totals are not peak memory. OCamlopt's separately measured
native initialization median was 13.715 s; it is a historical comparison.
See [OPTIONAL-ENTRY.md](reports/OPTIONAL-ENTRY.md) and
[OCAMLOPT-STARTUP.md](reports/OCAMLOPT-STARTUP.md) for methods and limits.

## Repository contents

| Directory/file | Purpose |
|---|---|
| `src/` | OCaml translator and command-line interface |
| `runtime/` | Curried calling protocol and compatibility boundary |
| `generated/` | Generated Lisp, inventory and ASDF system, kept for source comparison |
| `vendor/` | Pinned original inputs, real Lisp dependencies and licenses |
| `tests/` | Semantic, kernel, differential and boundary tests; benchmark harnesses |
| `scripts/` | Build verification, scanning, packaging and reproducible measurements |
| `reports/` | Current validation and benchmark evidence |
| `reports/history/` | Older experiments, kept separately from current results |
| `docs/` | Repository policy and design history |
| `DESIGN.md` | Detailed translation design and measured status |
| `AGENTS.md` | Instructions for maintaining this repository |

`_build/`, `bin/`, `dist/`, FASLs, Python caches and generated source-map JSON
are not tracked. `make regenerate` recreates source maps; release ZIPs include
them, DESIGN.md, AGENTS.md and the complete translator. See
[REPOSITORY-LAYOUT.md](docs/REPOSITORY-LAYOUT.md) for the keep/exclude decisions.

## License

New translator/runtime code is MIT licensed. HOL Light, Trivia and the
vendored OCaml algorithms retain their original licenses and notices.
See [LICENSE](LICENSE) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
