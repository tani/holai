# Repository inclusion policy

The published project is Holai. The current translator CLI is `bin/ml2cl`,
packages remain `holai.*`, and systems are `holai`/`holai/runtime` plus inferred
`holai/generated/<stem>` systems. Exactly one root `holai.asd` provides discovery;
no old-name compatibility aliases are retained.

## Keep in Git

- DESIGN.md, AGENTS.md, translator/runtime sources, Makefile, root holai.asd
  and maintained holai/all.lisp inferred entry.
- Generated Lisp: source comparison and debugging are core project goals.
- Generated inventory/package-systems.sexp: readable supported scope and complete
  package-provider mapping. Runtime/predecessor/external imports infer load order.
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
- The old runtime snapshot used by the OPTIONAL benchmark: it is a deliberate
  test-only control, not another production runtime.

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
The unified ASDF/UIOP cutover preserves the CLI and public package API while
replacing old systems without aliases. No algorithm or data representation
changes are included. Packaging verifies mandatory files, pins, observation
digests and 52 unique production pathnames/classes/order. The 94 generated
outputs remain 46 Lisp/map pairs plus inventory and provider data; the maintained
entry and root ASD are separate. Prior 51-unit measurements remain historical.

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
Current reports record SBCL full-core and ECL/ABCL/CLISP runtime-fixture passes,
with source fingerprints and digest-matched logs. Each additional host passed
three runtime fixtures and 33 exact rows; its full core remains unverified.
Fixture fingerprints cover Lisp/maps/provider/inventory only, not compiled
FASLs; compiled FASLs are not shipped. The final `make release` exited 0 in
269.03 seconds, including SBCL-backed inventory, fresh 94-output identical clean
generation and 55 unchanged input pins. The archive producer reported 427
payload files. The preceding inventory failure is historical, not a pending gate.

The proof readability policy applies to **software development code** throughout
the maintained translator-generated and handwritten sources, not just end-user
examples. Generated PROOF heads are finalized only after the complete actual
reader-owner namespace is known: safe owners explicitly import the runtime
macro and emit bare `proof`; owned, lexical, imported-symbol or maker-shadow
conflicts retain `holai.runtime:proof` without renaming source bindings.
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
