"""Gate SBCL full-core evidence and selected additional runtime-fixture profiles."""
import argparse
import hashlib
import json
import os
import subprocess
from lisp_host import ROOT, IMPLEMENTATIONS, selected_implementations

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("phase", choices=["test", "diagnostics", "release", "full-core"],
                    help="full-core explicitly opts every selected host into the expensive full suite")
options = parser.parse_args()
selected = selected_implementations()
optional_full_core = options.phase == "full-core"
required = tuple(os.environ.get("HOLAI_REQUIRED_LISPS", "sbcl").split(","))
if not optional_full_core and ("sbcl" not in required or any(host not in selected for host in required)):
    raise SystemExit("SBCL and all required implementations must be selected: " + ",".join(required))
availability = json.loads(os.environ.get("HOLAI_LISP_AVAILABILITY", "{}"))
report = ROOT / "misc/reports" / ("implementation-full-core-matrix.json" if optional_full_core
                                else "implementation-matrix.json")
matrix = json.loads(report.read_text()) if report.exists() else {}
matrix.update(selected=list(selected), required=[] if optional_full_core else list(required),
              availability=availability, full_core_required=[] if optional_full_core else ["sbcl"],
              compatibility_required=[] if optional_full_core else [host for host in selected if host != "sbcl"])
rows = matrix.setdefault("hosts", {})
failed = False
for host in IMPLEMENTATIONS:
    row = rows.setdefault(host, {})
    if host not in selected:
        row.update(status="unavailable", full_core_verified=False,
                   reason=availability.get(host, {}).get("reason") or "Not selected or executable not available on PATH")
        continue
    env = dict(os.environ, HOLAI_LISP=host)
    directory = ROOT / "misc/reports/implementations" / host
    directory.mkdir(parents=True, exist_ok=True)
    full_core = optional_full_core or host == "sbcl"
    profile = "full-core" if full_core else "runtime-fixtures"
    # Never carry an old full-core claim into an additional host's ordinary row.
    if not full_core or row.get("profile") != profile:
        row.clear()
    row.update(profile=profile, full_core_verified=False)
    if not full_core:
        phases = ("compatibility",)
    elif options.phase in ("release", "full-core"):
        phases = ("test", "diagnostics")
    else:
        phases = (options.phase,)
    if "test" in phases:
        row.pop("diagnostics", None)
    for phase in phases:
        script = {"test": "holai/tests/run.py",
                  "diagnostics": "misc/scripts/check-compile-diagnostics.py",
                  "compatibility": "holai/tests/compatibility.py"}[phase]
        log = directory / (("full-core-" if optional_full_core else "") + phase + "-runner.log")
        with log.open("w") as output:
            try:
                result = subprocess.run(["python3", script], cwd=ROOT, env=env,
                                        stdout=output, stderr=subprocess.STDOUT)
                code = result.returncode
            except OSError as error:
                output.write(str(error) + "\n")
                code = 127
        row[phase] = {"exit_code": code, "log": str(log.relative_to(ROOT)),
                      "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
        passed = code == 0
        if phase == "compatibility":
            evidence = directory / "compatibility.json"
            try:
                result = json.loads(evidence.read_text())
                passed &= (result["status"] == "passed" and result["profile"] == profile
                           and result["full_core_verified"] is False
                           and result["host"]["implementation"] == host)
                row[phase]["report"] = str(evidence.relative_to(ROOT))
                row[phase]["report_sha256"] = hashlib.sha256(evidence.read_bytes()).hexdigest()
            except (OSError, ValueError, KeyError, TypeError) as error:
                passed = False
                row[phase]["evidence_error"] = str(error)
            row["compatibility_passed"] = passed
            row["status"] = "compatibility_passed" if passed else "failed"
        else:
            row[phase]["passed"] = passed
            complete = all(row.get(p, {}).get("passed") is True for p in ("test", "diagnostics"))
            row["full_core_verified"] = complete
            row["status"] = "full_core_verified" if complete else "failed" if any(
                row.get(p, {}).get("passed") is False for p in ("test", "diagnostics")) else "pending"
        failed |= not passed
        print(f"{host} {profile} {phase}: {row['status']} (exit {code})", flush=True)
        report.write_text(json.dumps(matrix, indent=2) + "\n")
report.write_text(json.dumps(matrix, indent=2) + "\n")
raise SystemExit(1 if failed else 0)
