# Holai

Holai translates HOL Light's pinned OCaml standard core into readable Common
Lisp, preserving source scope, bindings, declaration order and algorithms.
It is not an OCaml VM or a formally verified compiler; translation success
is not a proof of kernel soundness. Optional HOL Light libraries and arbitrary
OCaml programs are outside the supported profile.

See [DESIGN.md](DESIGN.md) for the translation contract and limitations,
[release notes](docs/RELEASE-NOTES.md) for measured evidence and CI coverage,
and [repository layout](docs/REPOSITORY-LAYOUT.md) for source organization.

## Setup and checks

Use the pinned Nix shell with flakes enabled:

```sh
nix develop path:.
make build             # Build bin/ml2cl
make regenerate        # Regenerate Lisp, source maps and inventory
make test              # SBCL full suite + selected hosts' runtime/fixture checks
make clean-build       # Compare isolated clean-generated outputs
make release           # Add cold diagnostics, validation and source ZIP
```

For a one-shot release: `nix develop path:. --command make release`.
The lock file pins the compiler, grammar dependencies and Lisp packages.
The shell selects all usable candidates from ABCL, SBCL, ECL, CCL, MKCL,
CLISP, CMUCL and Clasp. `HOLAI_LISPS` selects the execution profile;
`HOLAI_LISP_AVAILABILITY` records package/platform exclusions.
ECL and MKCL need their native compiler toolchains. MKCL's weak-pointer adapter
uses its bundled Boehm GC headers through native C interop, not signal FFI.
SBCL owns mandatory full-core verification. Every selected additional host
must pass bounded runtime/translated-fixture compatibility; that does not
establish its full-core compatibility. Extra full-core runs are explicitly
opt-in with `make test-full-core`.

Generated Lisp is tracked for inspection. Do not hand-edit it: change the
translator and regenerate Lisp and source maps together.

## Usage

Translate source files:

```sh
ocamlrun bin/ml2cl translate --output-dir holai/generated <files...>
```

Load the full core interactively, or compile/load and exit:

```sh
misc/scripts/run-lisp.sh                    # SBCL by default
HOLAI_LISP=ecl misc/scripts/run-lisp.sh      # Select a pinned host
misc/scripts/run-lisp.sh --batch
misc/scripts/compile-core.sh
```

Other `HOLAI_LISP` values are `abcl`, `ccl`, `mkcl`, `clisp`,
`cmucl_binary` and `clasp-common-lisp`, where available.
Launchers initialize real ASDF before reading package-qualified forms;
the pinned shell supplies an ASDF source dependency when a host lacks it.

For an existing Lisp process, first load ASDF separately with `(require :asdf)`
(or load its installed source if your implementation does not bundle it).
Then evaluate:

```lisp
(asdf:initialize-source-registry
  '(:source-registry (:directory #p"/absolute/path/to/holai/")
    :inherit-configuration))
(asdf:load-asd #p"/absolute/path/to/holai/holai.asd")
(asdf:load-system "holai/runtime")   ; Runtime only
(asdf:load-system "holai")           ; Full pinned core
```

The root ASD explicitly orders ordinary serial systems; packages are not
inferred from filenames. Load the runtime before reading sharp-backquote
(``#` ``) code, using its active readtable rather than a fresh standard one.

After loading the core, import only what your development needs:

```lisp
(uiop:define-package :my-hol-development
  (:use :cl)
  (:import-from :holai.runtime.core :proof)
  (:import-from :holai.runtime.data :tuple)
  (:import-from :holai.tactics :prove :DISCH_TAC :THEN :FIRST_ASSUM :ACCEPT_TAC)
  (:import-from :holai.parser :parse_term))
(in-package :my-hol-development)

(prove (tuple (parse_term "p ==> p")
              (proof DISCH_TAC THEN (FIRST_ASSUM ACCEPT_TAC))))
```

Use bare `proof` for development notation and nest it for non-left grouping.
Named functions use `#'name`; function-valued operators use their symbols.
Ordinary application uses standard bare `funcall`, not a runtime wrapper.
See DESIGN for currying, sharp-backquote and namespace rules.

## Licenses

New translator/runtime code is [MIT licensed](LICENSE). HOL Light and vendored
OCaml algorithms retain their original licenses; see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and [`vendor/`](vendor/).
