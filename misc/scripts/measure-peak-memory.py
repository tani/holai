"""Measure per-process Linux peak RSS without cumulative-allocation counters."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--baseline", type=Path, help="optional original 1.0 project directory")
args = parser.parse_args()
if not sys.platform.startswith("linux"):
    parser.error("This script reports Linux wait4.ru_maxrss in KiB")
build = ROOT / "_build"
build.mkdir(exist_ok=True)
guard = build / "peak-memory-guard.lisp"
guard.write_text('''(require :asdf)
(defmethod asdf:perform :before ((operation asdf:compile-op) (component asdf:cl-source-file))
  (error "Unexpected compilation during FASL-only peak-RSS measurement: ~a" (asdf:component-pathname component)))
(load "tests/profile-core.lisp")
(finish-output)
''')
projects = []
if args.baseline:
    projects.append(("baseline", args.baseline.resolve(), str(guard)))
projects.append(("defunc-list-tuples", ROOT, "holai/tests/measure-startup.lisp"))
env = os.environ.copy()
env.pop("HOL2CL_DEVELOPMENT_IMAGE", None);env.pop('HOLAI_DEVELOPMENT_IMAGE',None)
results = []
for variant, directory, script in projects:
    log_path = build / f"peak-memory-{variant}.log"
    start = time.perf_counter()
    with log_path.open("w") as log:
        process = subprocess.Popen(["sbcl", "--control-stack-size", "256", "--noinform",
                                    "--disable-debugger", "--script", script],
                                   cwd=directory, env=env, stdout=log, stderr=subprocess.STDOUT)
        while True:
            pid, status, usage = os.wait4(process.pid, os.WNOHANG)
            if pid:
                process.returncode = os.waitstatus_to_exitcode(status)
                break
            if time.perf_counter()-start > 600:
                process.kill()
                os.wait4(process.pid, 0)
                process.returncode = -9
                raise TimeoutError(variant)
            time.sleep(0.25)
    elapsed = time.perf_counter()-start
    transcript = log_path.read_text()
    if process.returncode:
        raise RuntimeError(transcript[-3000:])
    assert "INITIAL_COUNTS 22 303 263 3" in transcript
    assert "CORE_INITIALIZATION_COMPLETE" in transcript
    marker = "PROFILE_END load " if variant == "baseline" else "LOAD_METRIC "
    assert sum(line.startswith(marker) for line in transcript.splitlines()) == 46
    results.append({"variant": variant, "peak_rss_kib": usage.ru_maxrss,
                    "peak_rss_mib": round(usage.ru_maxrss/1024, 3),
                    "elapsed_seconds": round(elapsed, 3),
                    "user_seconds": round(usage.ru_utime, 3),
                    "system_seconds": round(usage.ru_stime, 3),
                    "compiled_source_files": 0, "loaded_core_files": 46,
                    "fresh_process": True, "restored_heap": False,
                    "initial_counts": {"types": 22, "constants": 303, "definitions": 263, "axioms": 3}})
    (ROOT / "misc/reports/tuple-list-memory-comparison.json").write_text(json.dumps({
        "metric": "peak RSS from Linux wait4.ru_maxrss; KiB; per child process",
        "runs": results}, indent=2)+"\n")
    print(json.dumps(results[-1]), flush=True)
