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
make regenerate        # Regenerate Lisp, source maps and inventory
make test              # SBCL full suite + selected hosts' runtime/fixture checks
make clean-build       # Compare isolated clean-generated outputs
make release           # Add SBCL cold diagnostics, validation and source ZIP
```

For a one-shot release: `nix develop path:. --command make release`.
`flake.lock` pins one [NixOS 26.05](https://nixos.org/download/) package set for
the compiler and all Lisp hosts. The OCaml 4.14 profile retains explicit
Camlp5 8.02.01 and Num 1.5 source pins for the vendored HOL Light grammar.
`HOLAI_TOOLCHAIN_VERSIONS` reports the exact compiler/library package versions.

The shell selects **SBCL** plus available **ECL, ABCL and CLISP** packages for
each platform. `HOLAI_LISPS` selects hosts; `HOLAI_LISP_AVAILABILITY` records
all eight candidates and package/platform/broken/unsupported-adapter exclusions.
SBCL is mandatory for the full 46-file/OCaml differential suite and release's
52-unit cold diagnostics. Every selected additional host must pass the
**runtime-fixtures** compatibility profile, with 120 seconds per process.
Compatibility does **not** verify its full HOL core. Release packaging checks
observed versions and executable bindings against `HOLAI_LISP_VERSIONS` and
`HOLAI_LISP_EXECUTABLES` exported by the pinned shell, not arbitrary host tools.
The current explicit-ASDF release passed locally on ARM64 Linux in 287.53 seconds:
SBCL full-core verification, ECL/ABCL/CLISP runtime-fixture compatibility,
cold diagnostics, clean regeneration and packaging (see evidence below).
The shell supplies OCaml 4.14.4, Camlp5 8.02.01, Num 1.5, camlp-streams 5.0.1,
SBCL 2.6.4, ECL 26.5.5, ABCL 1.9.3 and CLISP 2.49.95.
See [DESIGN §38](DESIGN.md#38-common-lisp-host-portability) for exact coverage,
host limitations and retained timeout evidence.

GitHub Actions uses a **3 host × 4 implementation Cartesian matrix**: aarch64-linux
(`ubuntu-24.04-arm`), aarch64-darwin (`macos-15`) and x86_64-linux
(`ubuntu-24.04`), each with SBCL/ECL/ABCL/CLISP. All 12 jobs validate the Nix
system and selected package availability; a missing target fails rather than skips.
SBCL jobs run `HOLAI_LISPS=sbcl make release`; other jobs build the translator and
run the selected implementation's runtime-fixture compatibility profile only.
Fail-fast is disabled. SHA-pinned actions, read-only permissions and checkout
without persisted credentials are retained; artifacts include host and implementation.
Hosted run 38657307376 passed 10 of 12 jobs: SBCL, ECL and ABCL on all three
hosts, plus ARM64 Linux CLISP. Its x86 Linux CLISP failure exposed threaded
SIGINT dispatch; Darwin CLISP lacks FFI. The approved policy now restores the
previous native Lisp hook when catch-break is disabled, rather than OS SIG_DFL.
Stock NixOS 26.05 Lisp packages remain unchanged on all three targets; no CLISP
thread or FFI rebuild is required. The runtime-only regression delivers three
real SIGINTs: two Sys.Break catches across re-enable, then the independently
installed prior hook with normal exit 0. This policy's new hosted verification
is not yet claimed. Phase stdout/stderr and public failure annotations remain.

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
(asdf:load-asd #p"/absolute/path/to/holai/holai.asd")
(asdf:load-system "holai/runtime")   ; Runtime only
(asdf:load-system "holai")           ; Full 46-file core
```

The single root `holai.asd` handwrites two ordinary serial systems:
`holai/runtime` loads the six runtime files; `holai` then loads the 46 generated
files in pinned vendor order. Package names are independent of filesystem and
system names: the definition package is `holai.define`, runtime owners are
`holai.runtime.<unit>` and generated packages are `holai.<stem>` with dot-delimited
static children. There are no inferred
per-source systems, provider/load-order data files, umbrella runtime package,
or compatibility aliases.
The runtime system ID is `holai/runtime`, not `holai-runtime`; explicitly loading
the literal `holai.asd` above avoids relying on secondary-system discovery.
Data and pattern-registry own the leaf representation/declaration state;
pattern owns matching, core owns calling/proof macros, format owns printing,
and stdlib owns the OCaml library adapters, without shared reexports.

The explicit order covers 52 physical production files (six runtime plus 46 core);
regeneration produces 93 outputs (46 Lisp/map pairs plus inventory), with no empty
`holai/all` entry or `holai.generated` package layer.

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
  (:import-from :holai.runtime.core :proof :lambdac :labelsc)
  (:import-from :holai.runtime.data :tuple)
  (:import-from :holai.tactics :prove :DISCH_TAC :THEN :FIRST_ASSUM :ACCEPT_TAC)
  (:import-from :holai.parser :parse_term))
(in-package :my-hol-development)

(prove (tuple (parse_term "p ==> p")
              (proof DISCH_TAC THEN (FIRST_ASSUM ACCEPT_TAC))))
```

Use bare `proof` for ordinary development notation; nest it for non-left
grouping. Named functions use `#'name`, while function-valued operators such as
`THEN` use their symbols. Namespace conflicts retain `holai.runtime.core:proof`.
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
The current local `make release` exited 0 in 283.44 seconds. All four selected
profiles passed; clean regeneration reproduced all 93 outputs and retained all
55 input pins. Tagged SBCL evidence records 128 native checks, 69 PROOF checks
and 1,149 observations: 1,146 exact, two structural registry rows and one Random
property row. All 194,839 core and 207,058 fixture-inclusive source-map ranges
passed, as did ten protected rejections. The fresh-cache compiler audit covered
all 52 physical production files in literal ASD order (six runtime plus 46 core),
with zero compiler errors, warnings, style warnings or notices. Load/initialization
accounting is separate: zero errors/warnings, 21 style warnings and 164 notices.
The archive producer reported 427 payload files; ZIP byte size is not a fixed contract.
The three additional hosts each passed three runtime fixtures and 33 exact rows,
not full-core verification. ECL's weak-GC test uses a native MP worker and join,
retaining 28 assertions and two explicit collections without production cache changes.
All four hosts delivered three real SIGINTs, caught two as Sys.Break and restored
the independent previous native hook with exit 0; current metadata records
`sigint_previous_hook_restored` (SBCL) or `system_interrupt_previous_hook_restored`
(additional hosts), not historical OS-default termination.
Earlier 269.03-second and 94-output measurements remain historical.
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
