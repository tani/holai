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

The Nix development shell uses nixpkgs `nixos-23.11` for OCaml 4.14.2,
Camlp5 8.02.01 and camlp-streams 5.0.1, with Num pinned to upstream 1.5,
together with SBCL, Python and GNU Make. With Nix flakes enabled, enter it and use the existing
Makefile workflow:

```sh
nix develop
make build                         # bin/ml2cl, built from the OCaml sources
```

`flake.lock` pins the shell's nixpkgs input. The shell sets `CAMLPLIB` and
`STREAMLIB`; its `ocamlc`/`ocamlopt` wrappers add Num's include directory so
direct compiler calls such as `ocamlc nums.cma` work without switching the
build to `ocamlfind`.
The shell exports `CAML_LD_LIBRARY_PATH` for Num's bytecode runtime stub.
Validated on aarch64-linux: a forced translator build, bytecode/native Num
execution, SBCL execution, and `make release` (1,124 differential observations,
51 production files with zero diagnostics, and 94 identical regenerated files).
The other declared Linux/Darwin platforms were evaluated, not build-tested.
This OCaml 4.14.2/SBCL 2.3.9 shell is separate from the historical OCaml 4.14.1
profile; historical timing results below were not remeasured.

Without Nix, prerequisites are OCaml 4.14.1, Camlp5 8.02.x, camlp-streams,
Num 1.5, SBCL, Python 3.9 or later and GNU Make. Historical validation used
SBCL 2.2.9 on Linux. Matching is compiled
to standard Common Lisp by holai/runtime/pattern.lisp; no external Lisp library is
required. Former Trivia dependencies are available in the historical Git
revision used by the comparison scripts.

```sh
make build                         # bin/ml2cl, built from the OCaml sources
make regenerate                    # Lisp, source maps and ASDF load manifest
make test                          # full OCaml/SBCL differential validation
make clean-build                   # isolated source build; compare 94 outputs
misc/scripts/run-sbcl.sh                 # load the generated core in fresh SBCL
make release                       # validated source ZIP in dist/
```

Set `CAMLPLIB` and `STREAMLIB` when your Camlp5/camlp-streams installation is
not found by the Makefile. Cold core compilation uses a 2 GiB SBCL heap capacity
in the test runner; `misc/scripts/compile-core.sh` provides the same setting.
The core uses a 256 MiB control stack. Linux is required for the peak-RSS
measurement scripts, which use per-child `wait4.ru_maxrss`.

The translator CLI is `ml2cl`; production Lisp packages are `holai.*` (runtime `holai.runtime`), and ASDF systems are `holai-runtime` and `holai-generated`.
For example, `ocamlrun bin/ml2cl translate --output-dir holai/generated <files...>`
translates inputs; `scan` reports supported constructs and source diagnostics.

## Generated names

Ordinary names stay unchanged. Primes become percent signs (`x'` → `x%`), reserved
binders become `t%`/`nil%`, and collisions add percent signs (`mk_comb` / `MK_COMB%`).
Allocated names are shared by definitions, references and exports. Generated
core source no longer requires `|...|` symbol quoting; literal strings are
unchanged. See [PERCENT-NAMES.md](misc/reports/PERCENT-NAMES.md) for exact rules and examples.
Literal source operator stars and native special-variable names are retained.
Public Lisp spellings change in this version; update manually written callers
using the generated declarations. The OPTIONAL/OCamlopt and structural-match timing results predate this naming change.

## Writing proofs in Lisp

After loading the generated core (for example with `misc/scripts/run-sbcl.sh`),
use the exported `holai.runtime:proof` macro with the existing prover:

```lisp
(holai.tactics:prove
  (holai.runtime:tuple
    (holai.parser:parse_term "p ==> p")
    (holai.runtime:proof
      holai.tactics:DISCH_TAC holai.tactics:THEN
      (holai.tactics:FIRST_ASSUM holai.tactics:ACCEPT_TAC))))
```

PROOF accepts an operand followed by operator/operand pairs, all left
associative. Use an inner PROOF for explicit right grouping. THEN/THENL are
values; the named function ORELSE uses `#'holai.tactics:ORELSE`. The same
value/function distinction applies to operands (for example,
`#'holai.tactics:REFL_TAC`) and lexical operators. THENL takes an ordinary
list expression or list variable; composed branches use their own PROOF.
One operand is accepted; empty or malformed sequences are macro errors.

The runtime also installs an explicitly authorized sharp-backquote reader for
function values/expressions, alongside unchanged standard `#'` named functions.
After loading the runtime, the same real proof can be written:

```lisp
(holai.tactics:prove
  (holai.runtime:tuple
    (holai.parser:parse_term "p ==> p")
    (holai.runtime:proof
      #`holai.tactics:DISCH_TAC holai.tactics:THEN
      (holai.tactics:FIRST_ASSUM #`holai.tactics:ACCEPT_TAC))))
```

Sharp-backquote reads one form and wraps it in a `CL:LAMBDA` with a gensym rest
parameter. Each invocation evaluates the function expression anew and uses
`CL:APPLY` to forward all arguments and multiple values; it does not capture
the function value at wrapper construction. Its lambda is valid as a PROOF
operand, not directly as an operator: bind it to a lexical value symbol for
that role. PROOF's operator grammar and translator output are unchanged.

Installation affects the active `*readtable*` during runtime compile/load/execute.
Load the runtime before reading a file using sharp-backquote; readtable copies
inherit it, fresh standard readtables made from NIL do not. Neither standard
`#'` dispatch nor `readtable-case` nor source identifier spelling is changed.

Keep `holai.runtime:proof` fully qualified unless deliberately importing it.
Likewise qualify generated names with their defining package, or explicitly
import them into your working package after inspecting their declarations.
Do not assume every tactic is a named function or import the runtime wholesale
into a CL-using package. A local function named `proof` can coexist with the
fully qualified macro. PROOF only constructs the existing tactic calls: it
does not change proof algorithms, justification checks or kernel operations.
The translator emits this notation only for resolved canonical tactical
bindings; aliases, shadowing and ordinary partial/direct-goal calls retain
their existing calling conventions. See DESIGN §33 for the exact contract.

The native `holai/tests/proof-dsl.lisp` matrix is compiled/loaded after observation
capture and std_formatter stream restoration, with an isolated measured
`proof_dsl_checks` counter. The completed reader-inclusive release passed all
61 PROOF checks and eight new OCaml/SBCL fixture observations; a separate fresh
sharp-backquote handwritten smoke proved the actual closed identity theorem.
Release packaging includes the new unit,
translator, design, generated Lisp/maps, reports and matching streams.
No PROOF timing or publication result is claimed; the version remains
1.0.0-percent-names.
The reader's runtime-only compile/load smoke passed (per-call evaluation,
dynamic rebinding, argument/multiple-value forwarding, hygiene and unchanged
`#'`). The measured 61 PROOF checks include thirteen permanent reader checks
with actual computations, including zero-argument sum, positional decimal
calculation, NIL classification, floor quotient/remainder and lexical-argument
hygiene.

## Current implementation and validation

Source functions use `defunc`, `lambdac`, `labelsc` and `fletc`. Their shared
OPTIONAL/supplied-p entry supports complete, partial and excess application.
Function values capture their original definitions; global named calls retain
runtime redefinition. Tuples keep their original argument list.
No fixed-worker or call-site specialization is enabled. Matching uses a static
IR at macro expansion time and standard Common Lisp control/binding forms.
Constructor/record descriptors are resolved before execution; guards and OR
binding joins preserve clause order. See [PATTERN-MATCH.md](misc/reports/PATTERN-MATCH.md).

Current reader-inclusive validation ran `nix develop path:. --command make release` on
aarch64-linux with OCaml 4.14.2, Camlp5 8.02.01 and SBCL 2.3.9.nixos:
122 existing native checks, 61 independent PROOF checks, 27 calling-protocol,
84 OPTIONAL-entry, 16 tuple and 46 structural-pattern checks passed.
All 1,132 OCaml/SBCL output rows matched (1,125 serialized observations and
seven actual side-effect rows). All 46 inputs initialized with 22 types,
303 constants, 263 definitions and exactly the three original source axioms.
The 5,519 OCaml/5,517 SBCL initialization rows retain the documented exact
two OCaml-only messages; raw initialization transcripts are not identical.
All 194,839 core/205,472 fixture-inclusive map entries passed audit, and ten
rejection checks kept output unchanged. Fresh-cache compilation of 51
production units had zero errors, warnings or style warnings; all 94 clean
outputs were identical and all 55 retained input hashes unchanged.
See [verification.json](misc/reports/verification.json),
[clean-build.json](misc/reports/clean-build.json),
[compile-diagnostics.json](misc/reports/compile-diagnostics.json) and
[COVERAGE.md](misc/reports/COVERAGE.md).

Two fresh runs per version gave median FASL-only start-to-exit times of
97.840 s before the OPTIONAL change and 81.957 s after it. Cumulative core
allocation fell from 113.6 GB to 55.7 GB; peak RSS rose from 208.9 MiB to
243.7 MiB. Allocation totals are not peak memory. OCamlopt's separately measured
native initialization median was 13.715 s; it is a historical comparison.
See [OPTIONAL-ENTRY.md](misc/reports/OPTIONAL-ENTRY.md) and
[OCAMLOPT-STARTUP.md](misc/reports/OCAMLOPT-STARTUP.md) for methods and limits.

## Repository contents

| Directory/file | Purpose |
|---|---|
| `ml2cl/` | OCaml translator and command-line interface |
| `holai/runtime/` | Curried calling protocol and compatibility boundary |
| `holai/generated/` | Generated Lisp, inventory and ASDF system, kept for source comparison |
| `vendor/` | Pinned HOL Light/OCaml inputs and their licenses |
| `holai/tests/` | Semantic, kernel, differential and boundary tests; benchmark harnesses |
| `misc/scripts/` | Build verification, scanning, packaging and reproducible measurements |
| `misc/reports/` | Current validation and benchmark evidence |
| `misc/reports/history/` | Older experiments, kept separately from current results |
| `docs/` | Repository policy, release notes and design history |
| `DESIGN.md` | Detailed translation design and measured status |
| `AGENTS.md` | Instructions for maintaining this repository |
| `flake.nix`, `flake.lock` | Reproducible development shell and pinned nixpkgs input |

`_build/`, `bin/`, `dist/`, FASLs, Python caches and generated source-map JSON
are not tracked. `make regenerate` recreates source maps; release ZIPs include
them, DESIGN.md, AGENTS.md and the complete translator. See
[REPOSITORY-LAYOUT.md](docs/REPOSITORY-LAYOUT.md) for the keep/exclude decisions.

## License

New translator/runtime code is MIT licensed. HOL Light, Trivia and the
vendored OCaml algorithms retain their original licenses and notices.
See [LICENSE](LICENSE) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
