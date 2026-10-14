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
- Current verification, exact observation streams and measurement raw data.
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

The structural-match release adds holai/runtime/pattern.lisp and removes production
Trivia dependencies. The OPTIONAL runtime snapshot is a historical control. Former Lisp libraries
are available in the baseline Git revision, not the current vendor tree. To reproduce the historical OPTIONAL
comparison, check out commit1730c0299f7d677ba25be29d2dfbff0538fea354 first.
