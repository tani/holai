# Repository inclusion policy

The published project is Holai. The current translator CLI is `bin/ml2cl`.
Package names are `holai.runtime.<unit>` and `holai.<stem>`, with dot-delimited
static descendants. Root `holai.asd` handwrites ordinary serial systems:
load `holai` for the core or `holai/runtime` for the runtime. No inferred
per-source systems or old-name compatibility aliases remain.

The current explicit-load-order/dotted-package `make release` passed locally on
ARM64 Linux in 287.53 seconds: SBCL full-core, all three additional-host
compatibility profiles, cold diagnostics, 93 identical clean outputs, 55 unchanged
pins and packaging (427 payload files). Older measurements remain historical;
ZIP byte size is not fixed after final documentation edits.
Runtime physical order is data, pattern-registry, pattern, core, format, stdlib;
then the 46 generated files in vendor order (52 production units).
Load the literal root `holai.asd` with `asdf:load-asd` before selecting `holai`
or `holai/runtime`; `holai-runtime` is not a current system ID. Package ownership
is `holai.define`, `holai.runtime.<unit>` and `holai.<stem>` with dotted children.
Data/registry own leaf state, pattern matching, core calling/proof macros,
format printing and stdlib library adapters; no aliases/shared facade are provided.

## Keep in Git

- DESIGN.md, AGENTS.md, translator/runtime sources, Makefile and root holai.asd.
- flake.nix/flake.lock: one NixOS 26.05 source, with explicit compatible
  Camlp5/Num source overrides. .github/workflows/ci.yml: SHA-pinned, read-only
  3 host × 4 implementation Cartesian CI, with host/implementation-specific artifacts.
- Generated Lisp: source comparison and debugging are core project goals.
- Generated inventory.json: readable supported scope. Load order is handwritten
  in the root ASD, not emitted as provider or load-order S-expression data.
- Original pinned HOL Light/OCaml inputs, with every applicable license and
  input digest. They permit reproducible offline builds.
- Tests and reusable scanning, validation, packaging and measurement scripts.
- Current verification, raw and canonical observation streams and measurement raw data.
- Current host evidence under `misc/reports/implementations/<id>/`, with
  explicit implementation/version tags. SBCL retains full verification,
  diagnostics, raw/canonical streams and their hashes, with separate exact,
  property-Random and structural-initial-registry counts (see DESIGN's observer
  contract); additional hosts retain `compatibility.json`
  and its digest-matched `compatibility/` logs. Optional full-core attempts and
  incomplete timeout evidence remain distinct, never compatibility passes.
  Root SBCL-named streams/reports remain historical; producers never write
  other host output there. Shared clean-generation and inventory reports stay
  at the report root.
- Older evidence under misc/reports/history/, including vector-tuple experiments.
- The old-entry control used by the OPTIONAL benchmark is test-only, not another
  production runtime. Its maintained source now uses standard FUNCALL; original
  timings belong to the pre-cutover committed snapshot, not this updated control.

## Exclude from Git; regenerate as needed

- _build/: compiler outputs, temporary trees, fixture output and working logs.
- bin/: machine/toolchain-dependent executable translator.
- dist/: release ZIPs; these duplicate repository contents.
- FASLs/object files/bytecode archives and Python caches.
- holai/generated/*.map.json: approximately 28 MiB of reproducible node-offset data.
  make regenerate and make test create/check them. Source ZIPs retain all maps.
- Toolchain installations, rollback workspaces and downloaded service helpers.
  They are outside this repository, not prerequisites shipped as project files.

Historical data are relocated, not silently reinterpreted as current results.
Older reports retain their original wording; relative references in those
reports may name the original layout. Current scripts and release requirements
use the new paths. Generated Lisp/maps are regenerated for the renamed API; upstream input bytes and provenance identities remain unchanged.

The organization places five OCaml source modules directly in `ml2cl/`, Lisp runtime/generated/tests in `holai/`, and scripts/reports in `misc/`.
Release notes live in `docs/`; root DESIGN.md, AGENTS.md, build files, licensing and vendor inputs remain.
The explicit ASDF/dotted-package cutover preserves the CLI and actual runtime
ownership without aliases. No algorithm or data representation changes are
included. Packaging verifies mandatory files, pins, observation digests and
52 unique production compile/load pathnames in explicit vendor-manifest order.
The 93 generated outputs are 46 Lisp/map pairs plus inventory; the hand-maintained
root ASD is separate. Previous measurements remain historical.

Current launchers share `misc/scripts/lisp_host.py`; `run-lisp.sh` selects
the explicit candidate IDs through `HOLAI_LISP`, without an SBCL-only alias.
`test-matrix.py` collects every selected profile's failures and records selection,
required hosts and availability in `implementation-matrix.json`. SBCL alone is
required for full-core verification and 52-unit cold diagnostics. Every selected
additional host must pass `holai/tests/compatibility.py`'s `runtime-fixtures`
profile (120 seconds per process), with current source fingerprints, concrete
counts and digest-matched logs. That status never establishes full-core
verification. `make test-full-core` explicitly opts selected hosts into complete
tests and cold diagnostics, recorded in `implementation-full-core-matrix.json`;
ECL/ABCL/CLISP full-core processes retain the approved 3600-second guard.
Retained previous-distribution reports record SBCL full-core and ECL/ABCL/CLISP
runtime-fixture passes, with source fingerprints and digest-matched logs. Each additional host passed
three runtime fixtures and 33 exact rows; its full core remains unverified.
Current fixture fingerprints cover Lisp/maps/inventory only, not compiled
FASLs; compiled FASLs are not shipped. The preceding release exited 0 in
269.03 seconds, including SBCL-backed inventory, fresh 94-output identical clean
generation and 55 unchanged input pins. The archive producer reported 427
payload files. The preceding inventory failure is historical, not a pending gate.
The preceding NixOS 26.05 profile separately passed local ARM64 Linux flake
checks, a forced fresh compiler build and ordinary release with all four hosts;
the combined flake-check/release invocation took 293.62 seconds. Those reports
retain 94 identical clean-generated outputs and 55 unchanged input pins; the
archive producer reported 428 payload files before final documentation edits.
That historical CI ran `nix flake check` plus ordinary `make release` independently
on each platform. Current CI crosses three systems with all eight candidate IDs,
with eight explicit unavailable ARM exclusions: 16 runnable jobs. Only SBCL runs
release; other implementations run bounded runtime fixtures with separate artifacts.
The prior four-implementation
[run 38661471081](https://github.com/tani/holai/actions/runs/38661471081)
at `ac56ca3` passed 12/12. Its OS-interoperability contract is historical;
the expanded native-Lisp-only 16-job matrix remains pending.
The shell selects eight pinned packages on x86 Linux and four on each ARM64 host;
CMUCL is a 32-bit x86 binary, not an ARM package. Genuine unsupported, broken and
evaluation-unavailable cells remain explicit. Packaging verifies actual host
type, feature, version and executable binding against pinned-shell metadata.
Launchers load real ASDF separately before reading package-qualified forms;
`HOLAI_ASDF_SOURCE` supplies the pinned dependency if REQUIRE cannot load it.
The mandatory direct-native interrupt fixture and its log establish two Sys.Break
catches and exact previous-hook restoration. Real OS-SIGINT evidence is separate:
ABCL reports not applicable because there is no native SIGINT-specific Lisp hook,
not a passing OS test. No Java/OS signal rewiring or forced-death pass is used.
Flake checks cover ASDF startup only; they do not establish runtime/full-core
compatibility. Captured phase logs and annotations support diagnosis without
turning skipped, incomplete or historical evidence into a current pass.

The proof readability policy applies to **software development code** throughout
the maintained translator-generated and handwritten sources, not just end-user
examples. Generated PROOF heads are finalized only after the complete actual
reader-owner namespace is known: safe owners explicitly import the runtime
macro and emit bare `proof`; owned, lexical, imported-symbol or maker-shadow
conflicts retain `holai.runtime.core:proof` without renaming source bindings.
Lexical modules share their enclosing reader owner; static child packages decide
separately. Handwritten ordinary proof code uses explicit UIOP runtime PROOF
imports, while intentionally qualified external-API/collision examples and the
separate CL-only distinct-symbol regression retain qualification. Generated
files/maps remain regeneration-only, never hand-edited. This extension passed
the parent release run: 129 native/69 PROOF checks and 1,149 matching differential
rows, including all six reader-owner collision observations and native symbol
assertions. A separate fresh bare-PROOF smoke proved a closed identity theorem.
Prior cutover measurements remain historical in DESIGN37.3.

The structural-match release adds holai/runtime/pattern.lisp and removes production
Trivia dependencies. The OPTIONAL runtime snapshot is a historical control. Former Lisp libraries
are available in the baseline Git revision, not the current vendor tree. To reproduce the historical OPTIONAL
comparison, check out commit1730c0299f7d677ba25be29d2dfbff0538fea354 first.
