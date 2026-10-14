# Repository inclusion policy

The published project is Holai; existing hol2cl CLI/package/ASDF identifiers
are retained to avoid changing the validated implementation during organization.

## Keep in Git

- DESIGN.md, AGENTS.md, translator/runtime sources, Makefile and ASDF systems.
- Generated Lisp: source comparison and debugging are core project goals.
- Generated inventory/ASDF manifest: readable supported scope and load order.
- Original pinned HOL Light/OCaml inputs, with every applicable license and
  input digest. They permit reproducible offline builds.
- Tests and reusable scanning, validation, packaging and measurement scripts.
- Current verification, exact observation streams and measurement raw data.
- Older evidence under reports/history/, including vector-tuple experiments.
- The old runtime snapshot used by the OPTIONAL benchmark: it is a deliberate
  test-only control, not another production runtime.

## Exclude from Git; regenerate as needed

- _build/: compiler outputs, temporary trees, fixture output and working logs.
- bin/: machine/toolchain-dependent executable translator.
- dist/: release ZIPs; these duplicate repository contents.
- FASLs/object files/bytecode archives and Python caches.
- generated/*.map.json: approximately 28 MiB of reproducible node-offset data.
  make regenerate and make test create/check them. Source ZIPs retain all maps.
- Toolchain installations, rollback workspaces and downloaded service helpers.
  They are outside this repository, not prerequisites shipped as project files.

Historical data are relocated, not silently reinterpreted as current results.
Older reports retain their original wording; relative references in those
reports may name the original layout. Current scripts and release requirements
use the new paths. Generated core and upstream input contents are unchanged.

The organization changes README/working instructions, report locations,
ignore rules, historical report references and the ZIP's holai/ top directory.
It does not rename the CLI/ASDF/package API, rewrite algorithms or add new
optimization. Packaging verifies mandatory files, pins and observation digests.

The structural-match release adds runtime/pattern.lisp and removes production
Trivia dependencies. The OPTIONAL runtime snapshot is a historical control. Former Lisp libraries
are available in the baseline Git revision, not the current vendor tree. To reproduce the historical OPTIONAL
comparison, check out commit1730c0299f7d677ba25be29d2dfbff0538fea354 first.
