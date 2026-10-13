"""Measure a fresh FASL-only startup; compilation is a fatal error."""
from pathlib import Path
import json
import os
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
BUILD = ROOT / "_build"
BUILD.mkdir(exist_ok=True)
start = time.perf_counter()
with (BUILD / "defunc-fasl-startup.log").open("w") as log:
    result = subprocess.run(["sbcl", "--control-stack-size", "256", "--noinform",
                             "--disable-debugger", "--script", "tests/measure-startup.lisp"],
                            stdout=log, stderr=subprocess.STDOUT, timeout=600)
elapsed = time.perf_counter() - start
text = (BUILD / "defunc-fasl-startup.log").read_text()
if result.returncode:
    raise RuntimeError(text[-3000:])
assert "CORE_INITIALIZATION_COMPLETE" in text
assert "INITIAL_COUNTS 22 303 263 3" in text
rows = [line.split() for line in text.splitlines() if line.startswith("LOAD_METRIC ")]
assert len(rows) == 46
baseline = json.loads((ROOT / "reports/history/defunc-baseline.json").read_text())
base_seconds = baseline["fasl_restart"]["wall_seconds_start_to_exit"]
report = {
    "variant": "defunc-list-tuples", "fresh_process": True, "restored_heap": False,
    "compiled_source_files": 0, "loaded_core_files": 46,
    "wall_seconds_start_to_exit": round(elapsed, 3),
    "load_wall_seconds_sum": round(sum(float(row[2]) for row in rows), 3),
    "load_cpu_seconds_sum": round(sum(float(row[3]) for row in rows), 3),
    "load_gc_seconds_sum": round(sum(float(row[4]) for row in rows), 3),
    "load_allocated_bytes_sum": sum(int(row[5]) for row in rows),
    "source_files": [{"file": row[1]+".ml", "wall_seconds": float(row[2]),
                      "cpu_seconds": float(row[3]), "gc_seconds": float(row[4]),
                      "allocated_bytes": int(row[5])} for row in rows],
    "baseline_fasl_restart_wall_seconds": base_seconds,
    "baseline_original_ocaml_wall_seconds": baseline["original_ocaml_wall_seconds"],
    "baseline_original_mode": baseline["original_ocaml_mode"],
    "baseline_profiled_core_allocated_bytes": baseline["cpu_profile"]["load_allocated_bytes_sum"],
    "baseline_profiled_core_gc_seconds": baseline["cpu_profile"]["load_gc_seconds_sum"],
    "allocation_comparison_scope": "core loads; profiled baseline versus unprofiled experiment",
    "speedup_against_fasl_baseline": round(base_seconds/elapsed, 3),
    "reduction_percent_against_fasl_baseline": round(100*(1-elapsed/base_seconds), 2),
    "initial_counts": {"types": 22, "constants": 303, "definitions": 263, "axioms": 3},
}
(ROOT / "reports/tuple-list-timing.json").write_text(json.dumps(report, indent=2)+"\n")
(ROOT / "reports/tuple-list-fasl-startup.txt").write_text(text)
print(f"Fresh FASL startup: {elapsed:.3f}s; 46 inputs; zero source compilations.")
