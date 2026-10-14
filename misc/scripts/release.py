"""Package the complete project, with mandatory design and translator sources."""
from pathlib import Path
import hashlib
import json
import zipfile
from lisp_host import HOST_TYPES, NATIVE_NAN_LIMITATIONS, full_core_timeout, selected_implementations

root = Path(__file__).resolve().parents[2]
version = "1.0.0-percent-names"
IMPLEMENTATIONS = selected_implementations()
matrix = json.loads((root / "misc/reports/implementation-matrix.json").read_text())
assert matrix["selected"] == list(IMPLEMENTATIONS)
assert "sbcl" in IMPLEMENTATIONS, "SBCL full-core evidence is mandatory"
assert matrix["full_core_required"] == ["sbcl"]
assert matrix["compatibility_required"] == [host for host in IMPLEMENTATIONS if host != "sbcl"]
assert "sbcl" in matrix["required"] and set(matrix["required"]) <= set(IMPLEMENTATIONS)
for host in IMPLEMENTATIONS:
    row = matrix["hosts"][host]
    if host == "sbcl":
        assert row["profile"] == "full-core" and row["status"] == "full_core_verified"
        assert row["full_core_verified"] is True
    else:
        assert row["profile"] == "runtime-fixtures" and row["status"] == "compatibility_passed"
        assert row["compatibility_passed"] is True and row["full_core_verified"] is False
    for phase in (("test", "diagnostics") if host == "sbcl" else ("compatibility",)):
        phase_evidence = row[phase]
        assert phase_evidence["exit_code"] == 0
        expected_log = f"misc/reports/implementations/{host}/{phase}-runner.log"
        assert phase_evidence["log"] == expected_log
        assert hashlib.sha256((root / expected_log).read_bytes()).hexdigest() == phase_evidence["log_sha256"]
        if phase == "compatibility":
            expected_report = f"misc/reports/implementations/{host}/compatibility.json"
            assert phase_evidence["report"] == expected_report
            assert hashlib.sha256((root / expected_report).read_bytes()).hexdigest() == phase_evidence["report_sha256"]
core = [Path(name).stem for name in json.loads((root / "vendor/CORE_FILES.json").read_text())]
required = ["DESIGN.md", "AGENTS.md", "README.md", "docs/RELEASE-NOTES.md", "Makefile", "holai.asd", "holai/all.lisp",
            "flake.nix", "flake.lock",
            "ml2cl/sexp.ml", "ml2cl/scope.ml", "ml2cl/compiler.ml", "ml2cl/frontend.ml", "ml2cl/cli.ml",
            "holai/runtime/package.lisp", "holai/runtime/core.lisp", "holai/runtime/format.lisp", "holai/runtime/stdlib.lisp",
            "holai/tests/run.py", "holai/tests/lisp-tests.lisp", "holai/tests/bootstrap.lisp", "holai/tests/profile-core.lisp", "holai/tests/system-interrupt.lisp",
            "holai/tests/proof-dsl.lisp",
            "holai/tests/fixtures/semantics.ml", "holai/tests/fixtures/differential.ml", "holai/tests/fixtures/extended.ml", "holai/tests/fixtures/logic.ml",
            "holai/tests/fixtures/tactical.ml", "holai/tests/fixtures/foundation.ml",
            "holai/tests/fixtures/language.ml", "holai/tests/fixtures/provers.ml",
            "holai/tests/fixtures/execution.ml", "holai/tests/fixtures/ambiguous_contents.ml", "holai/tests/fixtures/hidden_constructor_history.ml",
            "holai/tests/fixtures/arithmetic.ml", "holai/tests/fixtures/recursive_dependency.ml",
            "holai/tests/fixtures/standard.ml",
            "holai/tests/fixtures/recursive_cycle.ml", "holai/tests/fixtures/recursive_module_dependency.ml",
            "holai/tests/fixtures/optional_argument.ml", "holai/tests/fixtures/dynamic_label.ml",
            "holai/tests/fixtures/quotation.ml", "holai/tests/fixtures/unsupported.ml",
            "holai/tests/fixtures/private_constructor.ml", "holai/tests/fixtures/opaque_constructor.ml",
            "misc/scripts/scan_core.py", "misc/scripts/release.py", "misc/scripts/check-clean-build.py", "misc/scripts/run-lisp.sh", "misc/scripts/lisp_host.py", "vendor/SOURCES.json", "vendor/CORE_FILES.json",
            "misc/reports/core-inventory.json", "misc/reports/COVERAGE.md", "misc/reports/verification.json",
            "misc/reports/core-profile.json",
            "misc/reports/clean-build.json",
            "holai/tests/defunc-protocol.lisp", "holai/tests/measure-startup.lisp", "misc/scripts/measure-startup.py",
            "misc/reports/history/defunc-experiment.json", "misc/reports/history/defunc-baseline.json", "misc/reports/history/DEFUNC-EXPERIMENT.md",
            "misc/reports/history/defunc-protocol.txt", "misc/reports/history/defunc-fasl-startup.txt",
            "misc/scripts/measure-peak-memory.py", "misc/reports/history/peak-memory-comparison.json",
            "misc/reports/history/peak-memory-baseline.txt", "misc/reports/history/peak-memory-defunc.txt",
            "misc/reports/ocaml-observations.txt", "misc/reports/sbcl-observations.txt",
            "misc/reports/ocaml-initialization.txt", "misc/reports/sbcl-initialization.txt",
            "holai/generated/inventory.json", "holai/generated/package-systems.sexp",
            "LICENSE", "THIRD-PARTY-NOTICES.md"]
required += ["misc/scripts/measure-tuple-list.py", "holai/tests/tuple-list.lisp", "misc/reports/history/TUPLE-LIST.md", "misc/reports/history/tuple-list-startup.json", "misc/reports/history/tuple-list-startup.txt", "misc/reports/history/tuple-list-checks.txt", "holai/tests/profile-performance.lisp", "holai/tests/profile-sets.lisp", "holai/tests/probe-tuple.lisp",
             "misc/reports/history/NEXT-BOTTLENECKS.md", "misc/reports/history/next-bottlenecks.json",
             "misc/reports/history/defunc-cpu-self.txt", "misc/reports/history/defunc-cpu-inclusive.txt", "misc/reports/history/defunc-cpu-startup.txt",
             "misc/reports/history/defunc-sets-graph.txt", "misc/reports/history/defunc-sets-startup.txt", "misc/reports/history/tuple-probe.txt"]
required += [f"holai/generated/{name}{suffix}" for name in core for suffix in [".lisp", ".map.json"]]
required += ["misc/scripts/measure-ocamlopt.py", "misc/reports/OCAMLOPT-STARTUP.md", "misc/reports/ocamlopt-startup.json", "misc/reports/ocamlopt-build.txt"]
required += [f"misc/reports/ocamlopt-startup-run{i}.txt" for i in [1,2,3]]
required += ["docs/STATIC-CALL-PLAN.md", "docs/REPOSITORY-LAYOUT.md"]
required += ["misc/scripts/compile-core.sh", "misc/scripts/prepare-optional-baseline.py", "misc/scripts/measure-optional.py", "holai/tests/optional-baseline-core.lisp", "holai/tests/optional-entry.lisp", "holai/tests/optional-inspect.lisp", "holai/tests/optional-benchmark.lisp", "misc/reports/OPTIONAL-ENTRY.md", "misc/reports/optional-entry.json", "misc/reports/optional-before.asm", "misc/reports/optional-after.asm", "misc/reports/optional-baseline-micro.txt", "misc/reports/optional-optional-micro.txt", "misc/reports/optional-checks.txt"]
required += [f"misc/reports/optional-{mode}-startup-run{i}.{suffix}" for mode in ["baseline", "optional"] for i in [1,2] for suffix in ["json", "txt"]]
required += ["vendor/README.md", "misc/scripts/check-compile-diagnostics.py", "misc/reports/compile-diagnostics.json", "misc/reports/compile-diagnostics.txt", "misc/reports/PERCENT-NAMES.md"]
required += ["holai/runtime/pattern.lisp", "holai/tests/pattern.lisp", "holai/tests/pattern-inspect.lisp", "holai/tests/pattern-stale.lisp",
             "misc/scripts/measure-pattern.py", "misc/reports/PATTERN-MATCH.md", "misc/reports/pattern-performance.json",
             "misc/reports/pattern-expansion-and-assembly.txt", "misc/reports/pattern-checks.txt"]
required += ["holai/tests/star-allocator.ml", "holai/tests/fixtures/star_names.ml", "holai/tests/star-names.py", "holai/tests/star-names.lisp", "misc/reports/star-names.json", "misc/reports/STAR-NAMES.md"]
pins = json.loads((root / "vendor/SOURCES.json").read_text())["input_sha256"]
required += ["holai/tests/random.lisp"]
required += ["misc/scripts/test-matrix.py", "misc/reports/implementation-matrix.json"]
required += [f"misc/reports/implementations/sbcl/{name}"
             for name in ["verification.json", "compile-diagnostics.json", "compile-diagnostics.txt",
                          "lisp-observations.txt", "ocaml-observations.txt", "lisp-initialization.txt",
                          "ocaml-initialization.txt", "star-names.json", "system-interrupt.log",
                          "random.log", "ocaml-comparison.txt", "lisp-comparison.txt",
                          "defunc-protocol.log", "lisp-tests.log", "test-runner.log",
                          "pattern.log", "pattern-stale.log",
                          "diagnostics-runner.log"]]
required += ["holai/tests/compatibility.py", "holai/tests/compatibility-fixtures.lisp",
             "holai/tests/fixtures/compatibility_observations.ml"]
required += [f"misc/reports/implementations/{host}/{name}" for host in IMPLEMENTATIONS if host != "sbcl"
             for name in ("compatibility.json", "compatibility-runner.log")]
required += list(pins)
for name in required:
    assert (root / name).is_file(), f"Required release file missing: {name}"
for name, digest in pins.items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Pinned source changed: {name}"
runtime_units = [f"holai/runtime/{name}.lisp" for name in ["package", "pattern", "core", "format", "stdlib"]]
expected_units = runtime_units + [f"holai/generated/{name}.lisp" for name in core] + ["holai/all.lisp"]
expected_fingerprints = {"holai.asd", "holai/generated/package-systems.sexp", *expected_units,
                         *(str(p.relative_to(root)) for p in (root / "ml2cl").glob("*.ml"))}
import sys
sys.path.insert(0, str(root / "holai/tests"))
from run import verify_initialization, compare_observations, verify_registry_provenance
from compatibility import FIXTURES, source_fingerprints
compatibility_fingerprints = source_fingerprints()
for host in IMPLEMENTATIONS:
    if host == "sbcl":
        continue
    evidence = root / "misc/reports/implementations" / host
    compatibility = json.loads((evidence / "compatibility.json").read_text())
    assert compatibility["status"] == "passed" and compatibility["profile"] == "runtime-fixtures"
    assert compatibility["full_core_verified"] is False and compatibility["timeout_seconds"] == 120
    identity = compatibility["host"]
    assert identity["implementation"] == host and identity["implementation_type"].lower() == HOST_TYPES[host]
    assert identity["version"] and identity["executable"], f"Missing exact {host} identity"
    if host == "ecl":
        assert identity["version"] == "21.2.1", "Release ECL must match the pinned 21.2.1 profile"
    assert compatibility["code_sha256"] == compatibility_fingerprints, f"Stale or incomplete {host} source fingerprints"
    counts = compatibility["counts"]
    for name, count in {"defunc_protocol_checks": 28, "optional_entry_checks": 84,
                        "tuple_list_checks": 16, "standard_random_checks": 1816,
                        "structural_pattern_checks": 45 if host in NATIVE_NAN_LIMITATIONS else 46,
                        "system_interrupt_deliveries": 3, "star_naming_observations": 9,
                        "fixture_sources": 3, "translated_fixture_units": 3}.items():
        assert counts[name] == count, f"Incomplete {host} compatibility check: {name}"
    assert counts["differential_observations"] > 0
    assert counts["exact_differential_observations"] == counts["differential_observations"]
    logs = compatibility["logs"]
    assert logs and compatibility["subprocesses"]
    for name, digest in logs.items():
        relative = Path(name)
        assert not relative.is_absolute() and ".." not in relative.parts
        assert relative.parts[0] == "compatibility", f"Unexpected compatibility log: {name}"
        assert hashlib.sha256((evidence / relative).read_bytes()).hexdigest() == digest, f"Stale {host} log: {name}"
        required.append(str((evidence / relative).relative_to(root)))
    for process in compatibility["subprocesses"]:
        assert process["timeout_seconds"] == 120 and process["elapsed_seconds"] >= 0
        assert process["command"] and process["log"] in logs
        assert process["exit_code"] == process["expected_exit_code"]
    expected_logs = {"host.log", "pattern.log", "pattern-stale.log",
                     "defunc-protocol.log", "optional-entry.log", "tuple-list.log",
                     "random.log", "system-interrupt.log", "translate.log",
                     "ocaml-build.log", "ocaml-run.log", "fixtures.log",
                     "ocaml-observations.txt", "lisp-observations.txt"}
    assert {"compatibility/" + name for name in expected_logs} <= set(logs), f"Incomplete {host} compatibility logs"
    processes = {process["log"]: process for process in compatibility["subprocesses"]}
    assert len(processes) == len(compatibility["subprocesses"]), "Duplicate compatibility process logs"
    assert {"compatibility/" + name for name in expected_logs if name.endswith(".log")} <= set(processes)
    for name, process in processes.items():
        expected_exit = 17 if name == "compatibility/pattern-stale.log" else -2 if name == "compatibility/system-interrupt.log" else 0
        assert process["expected_exit_code"] == expected_exit
    host_log = (evidence / "compatibility/host.log").read_text().splitlines()
    assert [line for line in host_log if line.startswith("HOLAI_HOST_VERSION ")] == ["HOLAI_HOST_VERSION " + identity["version"]]
    assert [line for line in host_log if line.startswith("HOLAI_HOST_TYPE ")] == ["HOLAI_HOST_TYPE " + identity["implementation_type"]]
    for filename, marker, key in (
            ("defunc-protocol.log", "Protocol", "defunc_protocol_checks"),
            ("optional-entry.log", "Optional entry", "optional_entry_checks"),
            ("tuple-list.log", "Tuple-list", "tuple_list_checks"),
            ("random.log", "Standard Random", "standard_random_checks")):
        lines = (evidence / "compatibility" / filename).read_text().splitlines()
        assert [line for line in lines if line.startswith(marker + " checks passed:")] == [
            f"{marker} checks passed: {counts[key]}"]
    limitation = NATIVE_NAN_LIMITATIONS.get(host)
    nan = compatibility["native_nan_eql"]
    assert nan == {"status": "not_applicable" if limitation else "passed",
                   "reason": limitation["reason"] if limitation else None, "execution": "native-compiled"}
    rejection = compatibility["pattern_stale_fasl_rejection"]
    assert rejection["checked"] is True and rejection["exit_code"] == 17
    assert rejection["condition"] == "holai.runtime::pattern-declaration-changed"
    assert rejection["marker"] == "Pattern stale FASL rejected: Separate"
    assert rejection["log"] == "compatibility/pattern-stale.log"
    assert rejection["log_sha256"] == logs[rejection["log"]]
    assert (evidence / rejection["log"]).read_text().splitlines().count(rejection["marker"]) == 1
    observed = (evidence / "compatibility/ocaml-observations.txt").read_bytes()
    actual = (evidence / "compatibility/lisp-observations.txt").read_bytes()
    assert observed == actual and observed
    assert counts["differential_observations"] == len(observed.splitlines())
    assert sum(line.startswith(b"star-") for line in observed.splitlines()) == counts["star_naming_observations"]
    assert compatibility["raw_observation_streams_equal"] is True
    assert compatibility["property_validated_random_observations"] == 0
    assert b"language_random=" not in observed
    fixture_log = (evidence / "compatibility/fixtures.log").read_bytes()
    start, end = b"__HOLAI_COMPATIBILITY_OBSERVATIONS__\n", b"__HOLAI_COMPATIBILITY_END__\n"
    assert fixture_log.count(start) == fixture_log.count(end) == 1
    assert fixture_log.partition(start)[2].partition(end)[0] == actual
    tool_fingerprints = compatibility["tool_artifact_sha256"]
    assert set(tool_fingerprints) == {"bin/ml2cl", "_build/pa_j.cmo"}
    for name, digest in tool_fingerprints.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Stale {host} tool artifact: {name}"
    translated_prefix = f"_build/compatibility/{host}/translated/"
    translated_expected = {translated_prefix + name + suffix for name in FIXTURES for suffix in (".lisp", ".map.json")}
    translated_expected |= {translated_prefix + name for name in ("inventory.json", "package-systems.sexp")}
    assert set(compatibility["translated_sha256"]) == translated_expected
    for name, digest in compatibility["translated_sha256"].items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Stale {host} translated fixture: {name}"
    oracle_source = "\n".join((root / f"holai/tests/fixtures/{name}.ml").read_text() for name in FIXTURES)
    oracle_source += ("\nlet () = List.iter print_endline (compatibility_observations ()); "
                      "List.iter print_endline (observations ());;\n")
    assert hashlib.sha256(oracle_source.encode()).hexdigest() == compatibility["oracle_source_sha256"]
for host in ("sbcl",):
    evidence = root / "misc/reports/implementations" / host
    diagnostics = json.loads((evidence / "compile-diagnostics.json").read_text())
    verification = json.loads((evidence / "verification.json").read_text())
    assert verification["status"] == "passed", f"Incomplete or failed {host} native verification"
    assert diagnostics["host"]["implementation"] == verification["host"]["implementation"] == host
    assert diagnostics["host"]["version"] == verification["host"]["version"]
    assert diagnostics["fresh_asdf_cache"] and diagnostics["audit_complete"] and diagnostics["exit_code"] == 0
    assert not diagnostics["timed_out"] and diagnostics["timeout_seconds"] == full_core_timeout(host)
    assert verification["full_core_process_timeout_seconds"] == full_core_timeout(host)
    assert verification["ocaml_full_core_process_timeout_seconds"] == 600
    assert verification["test_process_timeout_seconds"] == 120
    assert diagnostics["compiler_scope_complete"] and not diagnostics["boundary_errors"]
    assert not diagnostics["active_operations"]
    assert diagnostics["compiled_unit_count"] == 52
    assert diagnostics["compiled_units"] == expected_units and len(set(diagnostics["compiled_units"])) == 52
    assert diagnostics["loaded_units"] == expected_units and diagnostics["inferred_load_order_matches_manifest"]
    assert diagnostics["inferred_units"] == expected_units[5:]
    assert set(diagnostics["code_sha256"]) == expected_fingerprints, "Diagnostic fingerprint coverage differs"
    assert all(diagnostics[k] == 0 for k in [
        "compiler_errors", "compiler_warnings", "compiler_style_warnings",
        "compiler_warning_notices", "load_initialization_errors"])
    for name, digest in diagnostics["code_sha256"].items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Stale {host} diagnostic report: {name}"
    assert verification["pattern_backend"] == "standard-common-lisp"
    limitation = NATIVE_NAN_LIMITATIONS.get(host)
    assert verification["structural_pattern_checks"] == (45 if limitation else 46)
    nan = verification["native_nan_eql"]
    assert nan["status"] == ("not_applicable" if limitation else "passed")
    assert nan["reason"] == (limitation["reason"] if limitation else None)
    assert nan["execution"] == "native-compiled"
    rejection = verification["pattern_stale_fasl_rejection"]
    assert rejection["checked"] is True and rejection["exit_code"] == 17
    assert rejection["condition"] == "holai.runtime::pattern-declaration-changed"
    assert rejection["marker"] == "Pattern stale FASL rejected: Separate"
    assert rejection["log"] == "pattern-stale.log"
    consumer = Path(rejection["consumer_fasl"])
    assert not consumer.is_absolute() and consumer.parts[0] == "_build"
    assert ".." not in consumer.parts and consumer.suffix in {".fasl", ".fas", ".abcl"}
    stale_log = (evidence / rejection["log"]).read_bytes()
    assert hashlib.sha256(stale_log).hexdigest() == rejection["log_sha256"]
    stale_markers = [line for line in stale_log.decode().splitlines()
                     if line.startswith("Pattern stale FASL rejected:")]
    assert stale_markers == [rejection["marker"]]
    assert verification["native_checks"] > 0 and verification["proof_dsl_checks"] > 0
    assert verification["defunc_protocol_checks"] > 0 and verification["standard_random_checks"] > 0
    assert verification["sigint_adapter_checked"] and verification["sigint_default_restored"]
    assert verification["sigint_catch_cycles"] == 2 and verification["sigint_reenable_verified"]
    assert verification["compiled_loaded_inputs"] == [f"vendor/hol-light/{name}.ml" for name in core]
    assert verification["identical_regeneration"] and verification["pinned_inputs_unchanged"]
    observed = (evidence / "ocaml-observations.txt").read_bytes()
    lisp_observed = (evidence / "lisp-observations.txt").read_bytes()
    original_comparison, lisp_comparison = compare_observations(observed.decode(), lisp_observed.decode())
    assert (evidence / "ocaml-comparison.txt").read_bytes() == original_comparison.encode()
    assert (evidence / "lisp-comparison.txt").read_bytes() == lisp_comparison.encode()
    assert original_comparison == lisp_comparison, "Canonical structural/property observations differ"
    baseline_comparison, _ = compare_observations(
        (root / "misc/reports/implementations/sbcl/ocaml-observations.txt").read_text(),
        observed.decode())
    assert baseline_comparison == original_comparison
    total = len(observed.splitlines())
    assert total == len(lisp_observed.splitlines()) == 1149
    assert verification["differential_observations"] == total
    assert verification["exact_differential_observations"] == total - 3
    assert verification["property_validated_random_observations"] == 1
    assert verification["structurally_compared_registry_observations"] == 2
    assert verification["structurally_compared_registry_rows"] == ["init_constants", "init_definitions"]
    provenance = verification["generated_registry_provenance"]
    assert provenance == verify_registry_provenance(), "Stale generated-name provenance evidence"
    assert provenance["status"] == "passed"
    assert provenance["source_files"] == [f"vendor/hol-light/{name}.ml" for name in core]
    assert provenance["source_locations"] == [], "Authored positive-decimal names cannot be classified as generated"
    assert verification["generated_registry_constant_normalization"]
    for stream in (observed, lisp_observed):
        rows = stream.decode().splitlines()
        for name in verification["structurally_compared_registry_rows"]:
            assert sum(row.startswith(name + "=") for row in rows) == 1
    assert verification["raw_observation_streams_equal"] == (observed == lisp_observed)
    assert hashlib.sha256(lisp_observed).hexdigest() == verification["lisp_observations_sha256"]
    assert hashlib.sha256(original_comparison.encode()).hexdigest() == verification["comparison_sha256"]
    assert hashlib.sha256(observed).hexdigest() == verification["observations_sha256"]
    original_init = (evidence / "ocaml-initialization.txt").read_bytes()
    lisp_init = (evidence / "lisp-initialization.txt").read_bytes()
    assert verification["initialization_difference_matches_profile"]
    assert (original_init == lisp_init) == verification["initialization_transcript_equal"]
    assert verify_initialization(original_init.decode(), lisp_init.decode()) == verification["initialization_difference"]
    assert hashlib.sha256(original_init).hexdigest() == verification["initialization_ocaml_sha256"]
    assert hashlib.sha256(lisp_init).hexdigest() == verification["initialization_lisp_sha256"]
clean_build = json.loads((root / "misc/reports/clean-build.json").read_text())
assert clean_build["build_from_sources"] and clean_build["identical_output"] and clean_build["source_pins_unchanged"]
assert clean_build["compared_generated_files"] == 2 * len(core) + 2
# Preserve and verify the preceding SBCL raw baseline independently of current
# per-host evidence. Its source fingerprints are historical, not current code.
baseline = json.loads((root / "misc/reports/verification.json").read_text())
baseline_observed = (root / "misc/reports/ocaml-observations.txt").read_bytes()
assert baseline_observed == (root / "misc/reports/sbcl-observations.txt").read_bytes()
assert hashlib.sha256(baseline_observed).hexdigest() == baseline["observations_sha256"]
baseline_original_init = (root / "misc/reports/ocaml-initialization.txt").read_bytes()
baseline_lisp_init = (root / "misc/reports/sbcl-initialization.txt").read_bytes()
verify_initialization(baseline_original_init.decode(), baseline_lisp_init.decode())
assert hashlib.sha256(baseline_original_init).hexdigest() == baseline["initialization_ocaml_sha256"]
assert hashlib.sha256(baseline_lisp_init).hexdigest() == baseline["initialization_sbcl_sha256"]
excluded = {"_build", "bin", "dist", ".git", "__pycache__"}
assert sorted(str(p.relative_to(root)) for p in root.rglob("*.asd")
              if not any(part in excluded for part in p.relative_to(root).parts)) == ["holai.asd"], "Release must contain only root holai.asd"
files = sorted(p for p in root.rglob("*") if p.is_file() and not any(part in excluded for part in p.relative_to(root).parts)
               and p.suffix not in {".cmo", ".cmi", ".cmx", ".o", ".fasl", ".fas", ".abcl", ".cls", ".class", ".pyc"})
dist = root / "dist"
dist.mkdir(exist_ok=True)
manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
archive = dist / f"holai-{version}.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zip:
    for file in files:
        info = zipfile.ZipInfo("holai/" + str(file.relative_to(root)), (2026, 10, 13, 0, 0, 0))
        info.external_attr = (0o100755 if file.stat().st_mode & 0o111 else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        zip.writestr(info, file.read_bytes())
    zip.writestr("holai/RELEASE-MANIFEST.json", json.dumps(manifest, indent=2, sort_keys=True) + "\n")
with zipfile.ZipFile(archive) as zip:
    names = set(zip.namelist())
    assert all("holai/" + file in names for file in required)
    assert zip.testzip() is None, "ZIP integrity check failed"
    for name, digest in manifest.items():
        assert hashlib.sha256(zip.read("holai/" + name)).hexdigest() == digest, name
print(f"Created {archive.name}: {len(files)} files, {archive.stat().st_size} bytes")
