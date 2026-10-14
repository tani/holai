# Holai

Holai translates HOL Light's pinned OCaml standard core into readable Common
Lisp, preserving source scope, bindings, declaration order and algorithms.
Common Lisp's left-to-right argument evaluation is accepted; this is not an
OCaml VM or a formally verified compiler. Translation success is not a proof
of kernel soundness.

The profile is **all 46 pinned core files**, through `define.ml`, listed in
[`vendor/CORE_FILES.json`](vendor/CORE_FILES.json). Optional HOL Light libraries
and arbitrary OCaml programs are outside this boundary. The production runtime
needs no external pattern library. See [DESIGN.md](DESIGN.md) for the contract,
host adapters, timeouts, limitations and diagnostic scopes.

## Build and test

Use the pinned Nix shell with flakes enabled:

```sh
nix develop path:.
make build             # Build bin/ml2cl
make regenerate        # Regenerate Lisp, source maps and provider data
make test              # SBCL full suite + selected hosts' runtime/fixture checks
make clean-build       # Compare isolated clean-generated outputs
make release           # Add SBCL cold diagnostics, validation and source ZIP
```

For a one-shot release: `nix develop path:. --command make release`.
The shell pins OCaml 4.14.2, Camlp5 8.02.01, camlp-streams 5.0.1 and Num 1.5.
`flake.lock` pins the original nixos-23.11 SBCL/ECL source and the additional
nix-common-lisp nixos-25.05 source.

On ARM64 Linux, the runnable packages are **SBCL, ECL, ABCL and CLISP**.
`HOLAI_LISPS` selects hosts; `HOLAI_LISP_AVAILABILITY` records all eight
candidates and exclusion reasons. SBCL is mandatory for the full 46-file/OCaml
differential suite and release's 52-unit cold diagnostics. Every selected
additional host must pass the **runtime-fixtures** compatibility profile, with
120 seconds per process. Compatibility does **not** verify its full HOL core.
Measured profiles passed: SBCL full core and ECL/ABCL/CLISP runtime fixtures.
See [DESIGN §38](DESIGN.md#38-common-lisp-host-portability) for exact coverage,
host limitations and retained timeout evidence.

Expensive additional-host full-core tests and cold diagnostics are opt-in:
`HOLAI_LISPS=ecl,abcl,clisp make test-full-core` (3600 seconds per full-core
process). This is not part of ordinary `make test` or `make release`.

`bin/ml2cl` provides `scan` and `translate`, for example:

```sh
ocamlrun bin/ml2cl translate --output-dir holai/generated <files...>
```

Generated Lisp is tracked for inspection. Do not hand-edit it: change the
translator and regenerate Lisp and source maps together.

## Load

Start a fresh full-core process, or compile/load and exit:

```sh
misc/scripts/run-lisp.sh                  # SBCL by default
HOLAI_LISP=ecl misc/scripts/run-lisp.sh    # Also abcl or clisp
misc/scripts/compile-core.sh
```

For your own Lisp process, first evaluate this separately:

```lisp
(require :asdf)
```

Then read and evaluate:

```lisp
(asdf:initialize-source-registry
  '(:source-registry (:directory #p"/absolute/path/to/holai/")
    :inherit-configuration))
(asdf:load-system "holai/runtime")   ; Runtime only
(asdf:load-system "holai")           ; Full 46-file core
```

The single root `holai.asd` defines both systems. Generated
`holai/generated/<stem>` systems use package inference; `holai/all.lisp`
preserves full-core initialization order.

**Evaluate `(require :asdf)` before reading ASDF/UIOP forms.** Separate
`--eval` arguments work; wrapping everything in one `progn` is too late for
the package reader. Likewise, **load the runtime before reading sharp-backquote
(``#` ``) code**. It installs the reader in the active readtable; a fresh
standard readtable does not contain it. Keep loading separate from source
files that use that reader.

## Development notation

After loading the full core, import only what your package needs:

```lisp
(uiop:define-package :my-hol-development
  (:use :cl)
  (:import-from :holai.runtime :proof :tuple :lambdac :labelsc)
  (:import-from :holai.tactics :prove :DISCH_TAC :THEN :FIRST_ASSUM :ACCEPT_TAC)
  (:import-from :holai.parser :parse_term))
(in-package :my-hol-development)

(prove (tuple (parse_term "p ==> p")
              (proof DISCH_TAC THEN (FIRST_ASSUM ACCEPT_TAC))))
```

Use bare `proof` for ordinary development notation; nest it for non-left
grouping. Named functions use `#'name`, while function-valued operators such as
`THEN` use their symbols. Namespace conflicts retain `holai.runtime:proof`.
Sharp-backquote (``#` ``) invokes a function-valued expression; `labelsc`
provides curried lexical functions. See [DESIGN](DESIGN.md) for syntax,
evaluation order, partial application and namespace rules.

## Randomness and evidence

`Random` uses standard Common Lisp `RANDOM` with a private random-state.
`Random.init` deliberately ignores its integer seed and resets with
`MAKE-RANDOM-STATE T`; integer-seed replay is not guaranteed across runs or
hosts. Draws use the explicit private state; fresh-state creation is
host-defined. The `language_random=` row is property-validated; two initial
registry rows compare structurally under the user-approved generated-name
contract in [DESIGN](DESIGN.md#observation-and-initialization-boundary).
All remaining rows compare exactly. Reports retain raw and canonical comparison
streams separately, without claiming raw equality.

Current implementation-tagged evidence is under
[`misc/reports/implementations/`](misc/reports/implementations/): SBCL full-core
reports and additional-host `compatibility.json` reports have distinct profiles.
The [aggregate matrix](misc/reports/implementation-matrix.json) records each
selected profile's actual status; failed or incomplete reports are not release
evidence. The root [`verification.json`](misc/reports/verification.json) and
SBCL-named streams are historical, **not a current validation pass**.
The current SBCL run passed 128 native and 69 PROOF checks, comparing 1,149
rows: 1,146 exact, two structural registry rows and one Random property row.
The three additional hosts each passed three runtime fixtures and 33 exact rows,
not full-core verification. The final `make release` exited 0 (269.03 seconds),
including SBCL's 52-unit cold compiler audit, inventory, 94 identical clean
outputs and 55 unchanged input pins. Initialization notices are counted separately.
See also [clean-generation evidence](misc/reports/clean-build.json),
[coverage](misc/reports/COVERAGE.md), [release notes](docs/RELEASE-NOTES.md)
and [historical reports](misc/reports/history/).

## Repository and licenses

See [repository layout](docs/REPOSITORY-LAYOUT.md), [design](DESIGN.md) and
[maintenance rules](AGENTS.md). Translator sources live in `ml2cl/`; runtime,
generated core and tests in `holai/`; tools and reports in `misc/`.

New translator/runtime code is [MIT licensed](LICENSE). HOL Light and vendored
OCaml algorithms retain their original licenses; see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and [`vendor/`](vendor/).
