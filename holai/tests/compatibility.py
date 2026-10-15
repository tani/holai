"""Bounded runtime and translated-fixture compatibility, never full HOL core.

Run with HOLAI_LISP=<host> python3 holai/tests/compatibility.py after make build.
Every child process has a 120-second deadline. Full-core evidence is separate.
"""
from pathlib import Path
import difflib
import hashlib
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "misc/scripts"))
from lisp_host import HOST_TYPES, command, executable, implementation, report_directory

TIMEOUT = 120
FIXTURES = ("semantics", "compatibility_observations", "star_names")
RUNTIME_TESTS = ("defunc-protocol", "optional-entry", "tuple-list", "random",
                 "pattern", "pattern-stale", "system-interrupt")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_fingerprints():
    """Complete maintained source coverage, also consumed by the release gate."""
    paths = [*ROOT.glob("holai/runtime/*.lisp"), *ROOT.glob("ml2cl/*.ml")]
    paths += [ROOT / name for name in (
        "holai.asd", "vendor/SOURCES.json", "vendor/CORE_FILES.json",
        "vendor/hol-light/pa_j_4.xx_8.02.ml", "misc/scripts/lisp_host.py",
        "holai/tests/run.py", "holai/tests/compatibility.py",
        "holai/tests/compatibility-fixtures.lisp")]
    paths += [ROOT / f"holai/tests/{name}.lisp" for name in RUNTIME_TESTS]
    paths += [ROOT / f"holai/tests/fixtures/{name}.ml" for name in FIXTURES]
    return {str(path.relative_to(ROOT)): sha256(path) for path in sorted(paths)}


def main():
    os.chdir(ROOT)
    reports = report_directory()
    logs = reports / "compatibility"
    logs.mkdir(exist_ok=True)
    build = ROOT / "_build" / "compatibility" / implementation()
    build.mkdir(parents=True, exist_ok=True)
    evidence = {"status": "failed", "profile": "runtime-fixtures",
                "full_core_verified": False, "timeout_seconds": TIMEOUT,
                "host": {"implementation": implementation()},
                "code_sha256": source_fingerprints(), "logs": {},
                "counts": {}, "subprocesses": []}

    def save():
        evidence["logs"] = {
            str(path.relative_to(reports)): sha256(path)
            for path in sorted(logs.iterdir()) if path.is_file()}
        (reports / "compatibility.json").write_text(json.dumps(evidence, indent=2) + "\n")

    def run(args, *, log=None, expected=0, core=False, env=None, timeout_seconds=None):
        if core or timeout_seconds not in (None, TIMEOUT):
            raise ValueError("Compatibility forbids full-core and extended timeouts")
        name = log or f"command-{len(evidence['subprocesses']) + 1}.log"
        record = {"command": [str(arg) for arg in args], "timeout_seconds": TIMEOUT,
                  "expected_exit_code": expected, "exit_code": None,
                  "log": "compatibility/" + name}
        evidence["subprocesses"].append(record)
        started = time.monotonic()
        try:
            result = subprocess.run(args, text=True, capture_output=True,
                                    timeout=TIMEOUT, env=env)
            record["exit_code"] = result.returncode
            (logs / name).write_text(result.stdout + result.stderr)
            if result.returncode != expected:
                print(f"--- Failed compatibility command: {record['log']} ---", flush=True)
                print(result.stdout, end="")
                print(result.stderr, end="")
                print(f"\n--- end {record['log']} ---", flush=True)
                raise RuntimeError(f"Command exited {result.returncode}, expected {expected}: {shlex.join(record['command'])}; see {record['log']}")
            return result
        except subprocess.TimeoutExpired as error:
            def text(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            (logs / name).write_text(text(error.stdout) + text(error.stderr))
            record["status"] = "timed_out"
            raise
        finally:
            record["elapsed_seconds"] = time.monotonic() - started
            save()

    save()
    try:
        identity = run(command(extra=["--eval", '(format t "~&HOLAI_HOST_VERSION ~a~%HOLAI_HOST_TYPE ~a~%" (lisp-implementation-version) (lisp-implementation-type))']),
                       log="host.log").stdout
        version = re.findall(r"(?m)^HOLAI_HOST_VERSION (.+)$", identity)
        types = re.findall(r"(?m)^HOLAI_HOST_TYPE (.+)$", identity)
        assert len(version) == len(types) == 1, "Missing or duplicate host identity"
        assert types[0].lower() == HOST_TYPES[implementation()], "Selected host identity mismatch"
        evidence["host"] = {"implementation": implementation(), "implementation_type": types[0],
                            "version": version[0], "executable": executable()}

        # Reuse the same native-compiled pattern and actual SIGINT assertions as
        # the full suite, with isolated logs and our bounded process wrapper.
        spec = importlib.util.spec_from_file_location("holai_full_test_helpers", ROOT / "holai/tests/run.py")
        helpers = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helpers)
        helpers.run = run
        helpers.report_directory = lambda: logs
        pattern, nan, stale = helpers.verify_pattern()
        stale["log"] = "compatibility/" + stale["log"]
        evidence.update(native_nan_eql=nan, pattern_stale_fasl_rejection=stale)
        evidence["counts"]["structural_pattern_checks"] = pattern

        for name, marker, key, expected in (
                ("defunc-protocol", "Protocol", "defunc_protocol_checks", 28),
                ("optional-entry", "Optional entry", "optional_entry_checks", 84),
                ("tuple-list", "Tuple-list", "tuple_list_checks", 16),
                ("random", "Standard Random", "standard_random_checks", 1816)):
            output = run(command(f"holai/tests/{name}.lisp"), log=name + ".log").stdout
            counts = re.findall(r"(?m)^" + re.escape(marker) + r" checks passed: (\d+)$", output)
            assert len(counts) == 1 and int(counts[0]) == expected, f"Incomplete {name} profile: {counts}"
            evidence["counts"][key] = int(counts[0])

        started = time.monotonic()
        interrupt = {"command": command("holai/tests/system-interrupt.lisp"),
                     "timeout_seconds": TIMEOUT, "expected_exit_code": 0,
                     "exit_code": None, "log": "compatibility/system-interrupt.log"}
        evidence["subprocesses"].append(interrupt)
        try:
            interrupt["exit_code"] = helpers.verify_interrupt()
            evidence["counts"]["system_interrupt_deliveries"] = 3
            evidence["counts"]["system_interrupt_catch_cycles"] = 2
            evidence["system_interrupt_policy"] = "restore-previous-native-lisp-hook"
            evidence["system_interrupt_previous_hook_restored"] = True
        finally:
            interrupt["elapsed_seconds"] = time.monotonic() - started
            save()

        files = [f"holai/tests/fixtures/{name}.ml" for name in FIXTURES]
        translated = build / "translated"
        run(["ocamlrun", "bin/ml2cl", "translate", "--output-dir", str(translated), *files],
            log="translate.log")
        evidence["counts"]["fixture_sources"] = len(files)
        evidence["counts"]["translated_fixture_units"] = len(FIXTURES)
        generated = [translated / (name + suffix)
                     for name in FIXTURES for suffix in (".lisp", ".map.json")]
        generated += [translated / "inventory.json"]
        evidence["translated_sha256"] = {
            str(path.relative_to(ROOT)): sha256(path)
            for path in sorted(generated)}
        evidence["tool_artifact_sha256"] = {
            name: sha256(ROOT / name) for name in ("bin/ml2cl", "_build/pa_j.cmo")}

        # These exact fixture bodies and observations run in both languages;
        # there is no HOL setup, sliced source, or replacement Lisp oracle.
        source = "\n".join((ROOT / file).read_text() for file in files)
        source += ("\nlet () = List.iter print_endline (compatibility_observations ()); "
                   "List.iter print_endline (observations ());;\n")
        original = build / "original.ml"
        original.write_text(source)
        evidence["oracle_source_sha256"] = sha256(original)
        camlplib = os.environ.get("CAMLPLIB") or run(["camlp5r", "-where"], log="camlp5-location.log").stdout.strip()
        pp = shlex.join(["camlp5r", "-I", camlplib, "-I", str(ROOT / "_build"), "pa_j.cmo"])
        run(["ocamlc", "-w", "-a", "-pp", pp, str(original), "-o", str(build / "original")],
            log="ocaml-build.log")
        observed = run(["ocamlrun", str(build / "original")], log="ocaml-run.log").stdout
        native = run(command("holai/tests/compatibility-fixtures.lisp"), log="fixtures.log",
                     env=dict(os.environ, HOLAI_COMPATIBILITY_FIXTURES=str(translated))).stdout
        start, end = "__HOLAI_COMPATIBILITY_OBSERVATIONS__\n", "__HOLAI_COMPATIBILITY_END__\n"
        assert native.count(start) == native.count(end) == 1, "Missing or duplicate fixture boundaries"
        _, _, tail = native.partition(start)
        actual, _, _ = tail.partition(end)
        # No random observation exists in these fixtures: compare every byte.
        assert "language_random=" not in observed and "language_random=" not in actual
        if observed != actual:
            raise AssertionError("Fixture differential mismatch:\n" + "\n".join(
                difflib.unified_diff(observed.splitlines(), actual.splitlines(), fromfile="OCaml", tofile=implementation())))
        assert observed and sum(line.startswith("star-") for line in observed.splitlines()) == 9
        for name, text in (("ocaml-observations.txt", observed), ("lisp-observations.txt", actual)):
            (logs / name).write_text(text)
        evidence["counts"].update(star_naming_observations=9,
                                  differential_observations=len(observed.splitlines()),
                                  exact_differential_observations=len(observed.splitlines()))
        evidence["raw_observation_streams_equal"] = True
        evidence["property_validated_random_observations"] = 0
        evidence["status"] = "passed"
    except Exception as error:
        evidence["error"] = f"{type(error).__name__}: {error}"
        if os.environ.get("GITHUB_ACTIONS") == "true":
            message = evidence["error"][:2000]
            failed = next((record for record in reversed(evidence["subprocesses"])
                           if record["exit_code"] != record["expected_exit_code"]), None)
            if failed is not None:
                try:
                    message += "\n" + (reports / failed["log"]).read_text(errors="replace")[-7999:]
                except OSError:
                    pass
            message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::error title=Lisp compatibility failure ({implementation()})::{message}", flush=True)
        raise
    finally:
        save()
    print(f"{implementation()}: runtime-fixtures compatibility passed; full core NOT verified")


if __name__ == "__main__":
    main()
