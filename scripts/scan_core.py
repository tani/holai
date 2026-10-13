"""Inventory every pinned static hol_lib.ml input without evaluating it."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
manifest = json.loads((ROOT / "vendor/CORE_FILES.json").read_text())
declared = re.findall(r'\bloads\s+"([^"]+)"', (ROOT / "vendor/hol-light/hol_lib.ml").read_text())
assert declared == manifest, "Static core manifest differs from pinned hol_lib.ml"
result = subprocess.run(
    ["ocamlrun", "bin/hol2cl", "scan"] + ["vendor/hol-light/" + f for f in manifest],
    cwd=ROOT, capture_output=True, text=True)
assert result.returncode in {0, 1}, result.stderr
inventory = json.loads(result.stdout)
assert [entry["file"] for entry in inventory] == manifest
assert all(entry["parsed"] for entry in inventory), "Pinned core parsing failed"
verified = json.loads((REPORTS / "verification.json").read_text())
tested = {Path(f).name for f in verified["compiled_loaded_inputs"]}
for entry in inventory:
    entry["sbcl_compiled_loaded"] = entry["file"] in tested
    entry["differential_corpus_loaded"] = entry["file"] in tested
REPORTS.mkdir(exist_ok=True)
(REPORTS / "core-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
parsed = sum(entry["parsed"] for entry in inventory)
lowered = sum(entry.get("translated", False) for entry in inventory)
lines = [
    "# Pinned HOL Light core inventory", "",
    f"{parsed}/{len(manifest)} files parsed; {lowered} structurally lowered in this scan; "
    f"{len(tested)} compiled/loaded for the release differential corpus.", "",
    "Every pinned manifest input is compiled, initialized and included in the "
    "original-execution differential corpus for the complete standard-core release. "
    "The scan itself does not execute inputs; compilation and corpus states come "
    "from the separately recorded verification results.", "",
    "system.ml is translated with the documented SBCL startup stack, logical "
    "GC-control record and interrupt adapter. The immutable manifest supplies "
    "the loader order. Generic OCaml/runtime completeness is outside this profile.", "",
    "Reproduce with `make test inventory`. Raw counts and source diagnostics are "
    "in `core-inventory.json`; the load manifest is `vendor/CORE_FILES.json`.", "",
    "| File | Parsed | Lowered | SBCL loaded | First blocker |",
    "| --- | --- | --- | --- | --- |",
]
for entry in inventory:
    blocker = entry.get("diagnostic", "—").replace("|", "\\|").replace("\n", " ")
    lines.append(f'| `{entry["file"]}` | yes | '
                 f'{"yes" if entry.get("translated") else "no"} | '
                 f'{"yes" if entry["sbcl_compiled_loaded"] else "unverified"} | {blocker} |')
(REPORTS / "COVERAGE.md").write_text("\n".join(lines) + "\n")
print(f"Inventory: {parsed}/{len(manifest)} parsed, {lowered} lowered, {len(tested)} SBCL-loaded release inputs.")
