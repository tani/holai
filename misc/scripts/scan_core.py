"""Inventory every pinned static hol_lib.ml input without evaluating it."""
from pathlib import Path
import json
import re
import subprocess
from lisp_host import selected_implementations
IMPLEMENTATIONS = selected_implementations()

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "misc/reports"
manifest = json.loads((ROOT / "vendor/CORE_FILES.json").read_text())
declared = re.findall(r'\bloads\s+"([^"]+)"', (ROOT / "vendor/hol-light/hol_lib.ml").read_text())
assert declared == manifest, "Static core manifest differs from pinned hol_lib.ml"
result = subprocess.run(
    ["ocamlrun", "bin/ml2cl", "scan"] + ["vendor/hol-light/" + f for f in manifest],
    cwd=ROOT, capture_output=True, text=True, timeout=120)
assert result.returncode in {0, 1}, result.stderr
inventory = json.loads(result.stdout)
assert [entry["file"] for entry in inventory] == manifest
assert all(entry["parsed"] for entry in inventory), "Pinned core parsing failed"
matrix = json.loads((REPORTS / "implementation-matrix.json").read_text())
assert set(matrix["selected"]) == set(IMPLEMENTATIONS), "Selected implementation matrix differs"
assert "sbcl" in IMPLEMENTATIONS, "The full-core inventory requires SBCL"
assert matrix["hosts"]["sbcl"]["status"] == "full_core_verified"
assert matrix["hosts"]["sbcl"]["full_core_verified"] is True
verification = json.loads((REPORTS / "implementations/sbcl/verification.json").read_text())
assert verification["status"] == "passed"
assert verification["host"]["implementation"] == "sbcl"
tested = {Path(f).name for f in verification["compiled_loaded_inputs"]}
assert set(manifest) <= tested, "SBCL verification omits pinned core inputs"
compatibility = {}
for host in IMPLEMENTATIONS:
    if host == "sbcl":
        continue
    record = matrix["hosts"][host]
    assert record["status"] == "compatibility_passed", host
    assert record["compatibility_passed"] is True, host
    assert record["full_core_verified"] is False, host
    report = json.loads((ROOT / record["compatibility"]["report"]).read_text())
    assert report["status"] == "passed", host
    assert report["host"]["implementation"] == host
    assert report["profile"] == record["profile"] == "runtime-fixtures", host
    assert report["full_core_verified"] is False, host
    assert report["timeout_seconds"] == 120, host
    compatibility[host] = report
for entry in inventory:
    loaded = entry["file"] in tested
    entry["sbcl_compiled_loaded"] = loaded
    entry["differential_corpus_loaded"] = loaded
    entry["compiled_loaded_implementations"] = ["sbcl"] if loaded else []
    entry["differential_corpus_implementations"] = entry["compiled_loaded_implementations"].copy()
REPORTS.mkdir(exist_ok=True)
(REPORTS / "core-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
parsed = sum(entry["parsed"] for entry in inventory)
lowered = sum(entry.get("translated", False) for entry in inventory)
lines = [
    "# Pinned HOL Light core inventory", "",
    f"{parsed}/{len(manifest)} files parsed; {lowered} structurally lowered in this scan; "
    f"{sum(entry['file'] in tested for entry in inventory)} compiled/loaded for the "
    "release differential corpus on SBCL.", "",
    "Every pinned manifest input is compiled, initialized and included in the "
    "original-execution differential corpus on SBCL only. Other selected hosts "
    "have the bounded runtime-fixtures profile described separately below; "
    "that profile does not verify core loading, initialization or differential execution. "
    "The scan itself does not execute inputs; compilation and corpus states come "
    "from the separately recorded passed SBCL verification and implementation matrix.", "",
    "system.ml uses the documented per-host startup capacities, logical "
    "GC-control record and real interrupt adapter. The immutable manifest supplies "
    "the loader order. Generic OCaml/runtime completeness is outside this profile.", "",
    "Source Random uses private standard Common Lisp RANDOM state passed explicitly "
    "to draws; init ignores integer seeds and resets with MAKE-RANDOM-STATE T, "
    "without seed replay guarantees. Fresh-state creation may consume host entropy "
    "or the default RNG; default-RNG entropy isolation is not claimed. "
    "Only language_random= is shape/range validated and canonicalized. "
    "The init_constants and init_definitions rows compare structurally using a shared "
    "generated-name identity map; all remaining rows compare exactly. "
    "Raw and canonical streams are preserved.", "",
    f"sbcl: {verification['exact_differential_observations']} exact rows + "
    f"{verification['structurally_compared_registry_observations']} structurally compared "
    "initial-registry rows + "
    f"{verification['property_validated_random_observations']} property-validated Random row "
    f"= {verification['differential_observations']} total.", "",
    "## Bounded host compatibility", "",
    "These passed runtime-fixtures reports are not full-core verification. Counts "
    "below are measured per host; subprocess guards are taken from each report.", "",
    *[f"- {host} ({report['host']['implementation_type']} "
      f"{report['host']['version']}): profile `{report['profile']}`, "
      f"{report['timeout_seconds']}s guard; "
      + ", ".join(f"{name}={count}" for name, count in report["counts"].items()) + "."
      for host, report in compatibility.items()], "",
    *[f"- {host}: unavailable — {record['reason']}."
      for host, record in matrix["hosts"].items()
      if record["status"] == "unavailable"], "",
    "## Per-input core inventory", "",
    "Reproduce with `make test inventory`. Raw counts and source diagnostics are "
    "in sibling `core-inventory.json`; the repository-root-relative load manifest is `vendor/CORE_FILES.json`.", "",
    "| File | Parsed | Lowered | Implementations loaded | First blocker |",
    "| --- | --- | --- | --- | --- |",
]
for entry in inventory:
    blocker = entry.get("diagnostic", "—").replace("|", "\\|").replace("\n", " ")
    lines.append(f'| `{entry["file"]}` | yes | '
                 f'{"yes" if entry.get("translated") else "no"} | '
                 f'{", ".join(entry["compiled_loaded_implementations"]) or "unverified"} | {blocker} |')
(REPORTS / "COVERAGE.md").write_text("\n".join(lines) + "\n")
print(f"Inventory: {parsed}/{len(manifest)} parsed, {lowered} lowered, "
      f"{sum(entry['file'] in tested for entry in inventory)} release inputs loaded on SBCL; "
      f"{len(compatibility)} bounded runtime-fixtures hosts.")
