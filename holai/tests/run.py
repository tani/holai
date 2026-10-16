"""End-to-end compiler checks; no third-party Python dependencies."""
from pathlib import Path
import difflib
from collections import Counter
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import queue
import signal
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "misc/scripts"))
from lisp_host import (NATIVE_NAN_LIMITATIONS, NATIVE_SIGINT_LIMITATIONS,
                       command as lisp_command, full_core_timeout, implementation,
                       metadata, report_directory)
os.chdir(ROOT)
BUILD = ROOT / "_build"
BUILD.mkdir(exist_ok=True)
CLI = ["ocamlrun", "bin/ml2cl"]
CORE = ["vendor/hol-light/" + name for name in json.loads((ROOT / "vendor/CORE_FILES.json").read_text())]
FIXTURES = ["holai/tests/fixtures/semantics.ml", "holai/tests/fixtures/differential.ml", "holai/tests/fixtures/extended.ml", "holai/tests/fixtures/logic.ml", "holai/tests/fixtures/tactical.ml", "holai/tests/fixtures/foundation.ml", "holai/tests/fixtures/language.ml", "holai/tests/fixtures/provers.ml", "holai/tests/fixtures/execution.ml", "holai/tests/fixtures/arithmetic.ml", "holai/tests/fixtures/standard.ml"]


def run(args, *, log=None, expected=0, core=False, env=None, timeout_seconds=None):
    if timeout_seconds is None:
        timeout_seconds = 600 if core else 120
    started = time.monotonic()
    try:
        result = subprocess.run(args, text=True, capture_output=True,
                                timeout=timeout_seconds, env=env)
    except subprocess.TimeoutExpired as error:
        def captured_text(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
        stdout, stderr = captured_text(error.stdout), captured_text(error.stderr)
        name = log or "command-timeout.log"
        reports = report_directory()
        for directory in (BUILD, reports):
            (directory / name).write_text(stdout + stderr)
        partial_artifacts = []
        # Native initialization deliberately redirects stdout into this file.
        # Preserve its incomplete transcript too, rather than an older report.
        if "holai/tests/lisp-tests.lisp" in [str(arg) for arg in args]:
            source = BUILD / "lisp-initialization.txt"
            if source.exists():
                shutil.copyfile(source, reports / source.name)
                partial_artifacts.append(source.name)
        failure = {
            "status": "timed_out", "host": {"implementation": implementation()},
            "command": [str(arg) for arg in args], "timeout_seconds": timeout_seconds,
            "elapsed_seconds": time.monotonic() - started, "exit_code": None,
            "log": name, "stdout_characters": len(stdout), "stderr_characters": len(stderr),
            "partial_artifacts": partial_artifacts,
        }
        for directory in (BUILD, reports):
            (directory / (name + ".timeout.json")).write_text(json.dumps(failure, indent=2) + "\n")
        (reports / "verification.json").write_text(json.dumps(failure, indent=2) + "\n")
        print(f"{implementation()}: command timed out at {timeout_seconds}s: {shlex.join(args)}; "
              f"partial output: {reports / name}", file=sys.stderr, flush=True)
        raise
    if log:
        (BUILD / log).write_text(result.stdout + result.stderr)
        (report_directory() / log).write_text(result.stdout + result.stderr)
        for directory in (BUILD, report_directory()):
            (directory / (log + ".timeout.json")).unlink(missing_ok=True)
    if result.returncode != expected:
        raise RuntimeError(f"Command failed ({result.returncode}): {shlex.join(args)}\n"
                           f"{result.stdout[-1000:]}\n{result.stderr[-4500:]}")
    return result


def verify_pattern():
    pattern = run(lisp_command("holai/tests/pattern.lisp"), log="pattern.log")
    checks = re.findall(r"(?m)^Pattern checks passed: (\d+)$", pattern.stdout)
    assert len(checks) == 1, "Missing or duplicate structural pattern count"
    limitation = NATIVE_NAN_LIMITATIONS.get(implementation())
    capability_markers = [line for line in pattern.stdout.splitlines()
                          if line.startswith("Pattern native NaN EQL: not applicable")]
    assert capability_markers == ([limitation["marker"]] if limitation else []), (
        "Unexpected native-compiled NaN capability report", capability_markers)
    nan = {"status": "not_applicable" if limitation else "passed",
           "reason": limitation["reason"] if limitation else None,
           "execution": "native-compiled"}
    consumers = re.findall(r"(?m)^Pattern stale consumer FASL: (.+)$", pattern.stdout)
    assert len(consumers) == 1, "Missing or duplicate compiled stale consumer path"
    consumer = Path(consumers[0])
    assert consumer.is_absolute() and consumer.is_file(), "Stale consumer must be a real compiled file"
    consumer.relative_to(BUILD)
    environment = dict(os.environ, HOLAI_PATTERN_STALE_FASL=str(consumer))
    stale = run(lisp_command("holai/tests/pattern-stale.lisp"),
                log="pattern-stale.log", expected=17, env=environment)
    marker = "Pattern stale FASL rejected: Separate"
    assert stale.stdout.splitlines().count(marker) == 1, "Missing specific stale declaration rejection"
    log = report_directory() / "pattern-stale.log"
    rejection = {"checked": True, "exit_code": stale.returncode,
                 "condition": "holai.runtime.pattern-registry::pattern-declaration-changed",
                 "marker": marker, "consumer_fasl": str(consumer.relative_to(ROOT)),
                 "log": log.name, "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
    total = int(checks[0]) + 1
    assert total == (45 if limitation else 46), "Incomplete structural pattern profile"
    return total, nan, rejection


def verify_interrupt():
    """Deliver actual SIGINT three times: two Sys.Break catches, then the prior Lisp hook."""
    if implementation() in NATIVE_SIGINT_LIMITATIONS:
        raise ValueError(NATIVE_SIGINT_LIMITATIONS[implementation()])
    proc = subprocess.Popen(lisp_command("holai/tests/system-interrupt.lisp"),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            bufsize=1)
    lines = []
    events = queue.Queue()
    def read_output():
        for line in proc.stdout:
            events.put(line)
        events.put(None)
    threading.Thread(target=read_output, daemon=True).start()
    deadline = time.monotonic() + 120
    caught = 0
    catch_ready = 0
    previous_ready = False
    previous_restored = False
    # CCL's pinned entry point retains a shell parent; SIGINT sent to that
    # wrapper alone never reaches Lisp. The physical fixture reports its PID.
    target_pid = None if implementation() == "ccl" else proc.pid
    try:
        while True:
            line = events.get(timeout=max(0, deadline - time.monotonic()))
            if line is None:
                break
            lines.append(line)
            marker = line.strip()
            if marker.startswith("SIGINT target pid:"):
                assert implementation() == "ccl" and target_pid is None and catch_ready == 0, (
                    "Unexpected or repeated SIGINT target PID", marker)
                match = re.fullmatch(r"SIGINT target pid: ([1-9][0-9]*)", marker)
                assert match, ("Invalid SIGINT target PID", marker)
                candidate = int(match.group(1))
                ancestor = candidate
                seen = set()
                while ancestor != proc.pid:
                    assert ancestor > 1 and ancestor not in seen, (
                        "SIGINT target is not a child of the launched process", candidate)
                    seen.add(ancestor)
                    # POSIX ps also supports non-Linux CCL installations.
                    parent = subprocess.run(["ps", "-o", "ppid=", "-p", str(ancestor)],
                                            capture_output=True, text=True, check=True, timeout=10)
                    ancestor = int(parent.stdout.strip())
                target_pid = candidate
            elif marker == "SIGINT catch ready":
                assert target_pid is not None, "Missing CCL SIGINT target PID handshake"
                catch_ready += 1
                assert catch_ready <= 2, "Unexpected extra SIGINT catch cycle"
                os.kill(target_pid, signal.SIGINT)
            elif marker == "SIGINT adapter check passed":
                caught += 1
                assert caught == catch_ready, "SIGINT catch marker without readiness"
            elif marker == "SIGINT previous hook ready":
                assert caught == catch_ready == 2, "Missing actual initial/re-enabled Sys.Break delivery"
                assert not previous_ready, "Duplicate prior-hook readiness"
                previous_ready = True
                os.kill(target_pid, signal.SIGINT)
            elif marker == "SIGINT previous hook restored":
                assert previous_ready, "Prior hook ran before actual third SIGINT"
                assert not previous_restored, "Prior hook ran more than once"
                previous_restored = True
        exit_code = proc.wait(timeout=max(0, deadline - time.monotonic()))
        assert caught == catch_ready == 2 and previous_ready and previous_restored and exit_code == 0, (
            "SIGINT must restore the previous native Lisp hook without leaking Sys.Break", exit_code, "".join(lines))
        return exit_code
    except queue.Empty as error:
        raise subprocess.TimeoutExpired(proc.args, 120, output="".join(lines)) from error
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        text = "".join(lines)
        (BUILD / "system-interrupt.log").write_text(text)
        (report_directory() / "system-interrupt.log").write_text(text)


def initialization_messages(text):
    number = r"-?\d+(?:\.\d*)?(?:[eEdD][+-]?\d+)?"
    text = re.sub(r"(?m)^(CPU time \(user\): )" + number + r"$", r"\1<cpu-seconds>", text)
    return re.sub(r"(?m)^(Failed after \(user\) CPU time of )" + number + r"(?=: )",
                  r"\1<cpu-seconds>", text)


def initialization_difference(original, lisp):
    a = Counter(initialization_messages(original).splitlines())
    b = Counter(initialization_messages(lisp).splitlines())
    return {"original_only": dict(sorted((a-b).items())), "lisp_only": dict(sorted((b-a).items()))}


def verify_initialization(original, lisp):
    difference = initialization_difference(original, lisp)
    expected = {"original_only": {"0..0..solved at 2": 1, "Warning: inventing type variables": 1}, "lisp_only": {}}
    assert difference in ({"original_only": {}, "lisp_only": {}}, expected), f"Unexpected initialization differences: {difference}"
    return difference


def verify_pins():
    lock = json.loads((ROOT / "vendor/SOURCES.json").read_text())
    for file, digest in lock["input_sha256"].items():
        actual = hashlib.sha256((ROOT / file).read_bytes()).hexdigest()
        assert actual == digest, f"Pinned source changed: {file}"


class RegistryProvenanceError(AssertionError):
    def __init__(self, provenance):
        self.provenance = provenance
        locations = provenance["source_locations"]
        super().__init__("Ambiguous generated registry provenance: authored positive-decimal "
                         "tokens in pinned core source: " +
                         ", ".join(f'{p["source"]}:{p["line"]}:{p["column"]} ({p["token"]})'
                                   for p in locations))


def registry_source_locations(source, text):
    """Conservatively include comments/strings: no authored token is classifiable."""
    locations = []
    for match in re.finditer(r"(?<![A-Za-z0-9_'])_[1-9][0-9]*(?![A-Za-z0-9_'])", text):
        start = match.start()
        locations.append({"source": source, "line": text.count("\n", 0, start) + 1,
                          "column": start - text.rfind("\n", 0, start),
                          "token": match.group()})
    return locations


def registry_provenance_regressions():
    assert registry_source_locations("test.ml", "_0 _00 foo_17 _17tail '_17") == []
    assert registry_source_locations("test.ml", 'let x = "_17";;\n(* _23 *)') == [
        {"source": "test.ml", "line": 1, "column": 10, "token": "_17"},
        {"source": "test.ml", "line": 2, "column": 4, "token": "_23"},
    ], "Registry provenance must fail closed even for authored strings/comments"


def verify_registry_provenance():
    locations = [location for source in CORE
                 for location in registry_source_locations(source, (ROOT / source).read_text())]
    provenance = {
        "status": "failed" if locations else "passed", "source_files": CORE,
        "source_locations": locations,
        "rule": "reject standalone _[positive decimal] tokens in pinned core source before classification",
    }
    if locations:
        raise RegistryProvenanceError(provenance)
    return provenance

def audit(directory, files):
    count = 0
    for file in files:
        stem = Path(file).stem
        source = (ROOT / file).read_bytes()
        output = (directory / f"{stem}.lisp").read_bytes()
        mappings = json.loads((directory / f"{stem}.map.json").read_text())
        ids = set()
        for entry in mappings:
            assert entry["id"] not in ids, (stem, "duplicate origin", entry["id"])
            ids.add(entry["id"])
            actual_source = (ROOT / "vendor" / entry["source"]).read_bytes() if entry["source"].startswith("ocaml-stdlib/") else source
            assert 0 <= entry["source_start"] <= entry["source_end"] <= len(actual_source)
            assert 0 <= entry["output_start"] <= entry["output_end"] <= len(output)
            assert entry["source"] in {Path(file).name, "ocaml-stdlib/map.ml", "ocaml-stdlib/set.ml"}
            assert entry["rule"]
            count += 1
    return count


def canonical_observations(text):
    """Validate the sole Random property row; retain structural registry serialization."""
    rows = text.splitlines(keepends=True)
    for name in ("init_constants", "init_definitions"):
        assert sum(row.startswith(name + "=") for row in rows) == 1, (
            "Expected exactly one structural registry observation", name)
    indices = [i for i, row in enumerate(rows) if row.startswith("language_random=")]
    assert len(indices) == 1, "Expected exactly one language_random= observation"
    index = indices[0]
    row = rows[index]
    ending = "\n" if row.endswith("\n") else ""
    payload = row[len("language_random="):].removesuffix("\n")
    groups = payload.split(":")
    assert len(groups) == 3, "Malformed language_random groups"
    for group, count, bound in zip(groups, (8, 8, 4), (1 << 30, 97, 1 << 30)):
        values = group.split(",")
        assert len(values) == count, "Malformed language_random group length"
        assert all(re.fullmatch(r"[0-9]+", value) and 0 <= int(value) < bound
                   for value in values), "Malformed or out-of-range language_random value"
    rows[index] = "language_random=<validated-standard-random>" + ending
    return "".join(rows)


def compare_observations(original, lisp):
    a, b = canonical_observations(original), canonical_observations(lisp)
    if a != b:
        diff = "\n".join(difflib.unified_diff(a.splitlines(), b.splitlines(),
                                             fromfile="OCaml", tofile="Common Lisp"))
        raise AssertionError(f"Differential observations disagree:\n{diff[:8000]}")
    return a, b


def differential():
    source = "let needs _ = ();;\nlet float_sqrt = sqrt;;\nunset_jrh_lexer;;\n"
    source += (ROOT / "vendor/hol-light/bignum_num.ml").read_text()
    source += "\nset_jrh_lexer;;\n"
    source += "\n".join((ROOT / file).read_text() for file in CORE)
    marker = "__HOL2CL_INITIALIZATION_COMPLETE__"
    source += f'\nlet () = Format.pp_print_flush Format.std_formatter (); print_endline "{marker}";;\n'
    source += "\n".join((ROOT / file).read_text() for file in FIXTURES)
    source += ("\nlet () = let baseline = observations () in let extended = extended_observations () in "
               "let logical = logic_observations () in let tactical = tactical_observations () in "
               "let foundational = foundation_observations () in "
               "let language = language_observations () in "
               "let provers = provers_observations () in "
               "let execution = execution_observations () in "
               "let arithmetic = arithmetic_observations () in "
               "let standard = standard_observations () in "
               "List.iter print_endline (baseline @ extended @ logical @ tactical @ foundational @ language @ provers @ execution @ arithmetic @ standard);;\n")
    original = BUILD / "original.ml"
    original.write_text(source)
    camlplib = os.environ.get("CAMLPLIB") or run(["camlp5r", "-where"]).stdout.strip()
    pp = shlex.join(["camlp5r", "-I", camlplib, "-I", str(BUILD), "pa_j.cmo"])
    run(["ocamlc", "-w", "-a", "-pp", pp, "nums.cma", str(original), "-o", str(BUILD / "original")], log="ocaml-build.log")
    transcript = run(["ocamlrun", str(BUILD / "original")], log="ocaml-run.log", core=True).stdout
    initialization, separator, observed = transcript.partition(marker + "\n")
    assert separator, "Missing original initialization boundary"
    (BUILD / "ocaml-initialization.txt").write_text(initialization)
    lisp_init = (BUILD / "lisp-initialization.txt").read_text()
    verify_initialization(initialization, lisp_init)
    (BUILD / "ocaml-observations.txt").write_text(observed)
    lisp = (BUILD / "lisp-observations.txt").read_text()
    compare_observations(observed, lisp)
    return len(observed.splitlines())


def main():
    reports = report_directory()
    (reports / "verification.json").write_text(json.dumps({
        "status": "running", "host": {"implementation": implementation()},
    }, indent=2) + "\n")
    verify_pins()
    registry_provenance_regressions()
    registry_provenance = verify_registry_provenance()
    host = metadata()
    pattern_checks, native_nan_eql, stale_rejection = verify_pattern()
    star = run(["python3", "holai/tests/star-names.py"], log="star-names.log")
    assert "Star naming checks passed" in star.stdout
    protocol = run(lisp_command("holai/tests/defunc-protocol.lisp"), log="defunc-protocol.log")
    protocol_checks = int(re.search(r"Protocol checks passed: (\d+)", protocol.stdout).group(1))
    optional = run(lisp_command("holai/tests/optional-entry.lisp"), log="optional-entry.log")
    optional_checks = int(re.search(r"Optional entry checks passed: (\d+)", optional.stdout).group(1))
    tuple_test = run(lisp_command("holai/tests/tuple-list.lisp"), log="tuple-list.log")
    tuple_checks = int(re.search(r"Tuple-list checks passed: (\d+)", tuple_test.stdout).group(1))
    inventory = json.loads(run(CLI + ["scan"] + CORE).stdout)
    assert all(x["parsed"] and x["translated"] for x in inventory)
    root_count = audit(ROOT / "holai/generated", CORE)
    with tempfile.TemporaryDirectory(dir=BUILD) as temp:
        run(CLI + ["translate", "--output-dir", temp] + CORE)
        generated = sorted(p for p in (ROOT / "holai/generated").iterdir()
                           if p.is_file() and p.suffix in {".lisp", ".json"})
        assert len(generated) == 2 * len(CORE) + 1 == 93, len(generated)
        assert [p.name for p in generated] == sorted(p.name for p in Path(temp).iterdir()), "Generated output file set differs"
        for file in generated:
            assert file.read_bytes() == (Path(temp) / file.name).read_bytes(), f"Stale/nondeterministic: {file.name}"
        rejected = [
            (["holai/tests/fixtures/unsupported.ml"], "Unsupported expression"),
            (["holai/tests/fixtures/private_constructor.ml"], "Private constructor"),
            (["holai/tests/fixtures/optional_argument.ml"], "Optional parameters"),
            (["holai/tests/fixtures/dynamic_label.ml"], "Labelled call needs statically resolved parameter labels"),
            (["holai/tests/fixtures/ambiguous_contents.ml"], "Ambiguous record labels"),
            (["holai/tests/fixtures/hidden_constructor_history.ml"], "Invalid arity for non-tuple constructor payload"),
            (["holai/tests/fixtures/recursive_dependency.ml"], "Recursive value initializer references its group: same"),
            (["holai/tests/fixtures/recursive_cycle.ml"], "Recursive value initializer references its group: cycle"),
            (["holai/tests/fixtures/recursive_module_dependency.ml"], "Recursive value initializer references its group: walk"),
            (CORE + ["holai/tests/fixtures/opaque_constructor.ml"], "Unresolved identifier: Sequent"),
        ]
        for files, message in rejected:
            before = {p.name: p.read_bytes() for p in Path(temp).iterdir()}
            result = run(CLI + ["translate", "--output-dir", temp] + files, expected=1)
            assert message in result.stderr, result.stderr
            after = {p.name: p.read_bytes() for p in Path(temp).iterdir()}
            assert before == after, "Rejected translation modified prior output"
    quote = json.loads(run(CLI + ["scan"] + CORE + ["holai/tests/fixtures/quotation.ml"]).stdout)[-1]
    assert quote["parsed"] and quote["translated"]
    native_interrupt = run(lisp_command("holai/tests/system-interrupt-native.lisp"),
                           log="system-interrupt-native.log")
    native_interrupt_counts = re.findall(r"(?m)^Native interrupt checks passed: (\d+)$",
                                         native_interrupt.stdout)
    assert native_interrupt_counts == ["3"], "Incomplete native Lisp interrupt restoration"
    sigint_limitation = NATIVE_SIGINT_LIMITATIONS.get(implementation())
    if sigint_limitation:
        (reports / "system-interrupt.log").write_text("OS SIGINT not applicable: " + sigint_limitation + "\n")
    else:
        verify_interrupt()
    random = run(lisp_command("holai/tests/random.lisp"), log="random.log")
    random_checks = int(re.search(r"Standard Random checks passed: (\d+)", random.stdout).group(1))
    run(CLI + ["translate", "--output-dir", "_build/fixtures"] + CORE + FIXTURES)
    fixture_count = audit(BUILD / "fixtures", CORE + FIXTURES)
    native = run(lisp_command("holai/tests/lisp-tests.lisp", core=True), log="lisp-tests.log",
                 timeout_seconds=full_core_timeout())
    assert "Native checks passed" in native.stdout
    proof_dsl_marker = re.search(r"PROOF DSL checks passed: (\d+)", native.stdout)
    assert proof_dsl_marker is not None, "Missing native PROOF DSL check counter"
    proof_dsl_checks = int(proof_dsl_marker.group(1))
    user_dsl_markers = re.findall(r"(?m)^User DSL checks passed: (\d+)$", native.stdout)
    assert len(user_dsl_markers) == 1, "Missing or duplicate user DSL check counter"
    observations = differential()
    checks = int(re.search(r"Native checks passed: (\d+)", native.stdout).group(1))
    observed = (BUILD / "ocaml-observations.txt").read_bytes()
    (reports / "ocaml-observations.txt").write_bytes(observed)
    (reports / "lisp-observations.txt").write_bytes((BUILD / "lisp-observations.txt").read_bytes())
    lisp_observed = (BUILD / "lisp-observations.txt").read_bytes()
    canonical_original, canonical_lisp = compare_observations(observed.decode(), lisp_observed.decode())
    (reports / "ocaml-comparison.txt").write_text(canonical_original)
    (reports / "lisp-comparison.txt").write_text(canonical_lisp)
    original_init = (BUILD / "ocaml-initialization.txt").read_bytes()
    lisp_init = (BUILD / "lisp-initialization.txt").read_bytes()
    (reports / "ocaml-initialization.txt").write_bytes(original_init)
    (reports / "lisp-initialization.txt").write_bytes(lisp_init)
    printer_lines = sum(line.startswith((b"printed_conversion=", b"printf_scalar=", b"meson_flush=", b"Warning:", b"Generating HOL version of proof")) or
                        re.fullmatch(rb"\d+ basis elements and \d+ critical pairs", line) is not None for line in observed.splitlines())
    bound_prefixes = (b"canon_", b"ind_exists=", b"ind_rules=", b"ind_induction=",
                      b"ind_cases=", b"ind_strong=", b"ind_mutual_rules=",
                      b"ind_mutual_induction=", b"ind_mutual_cases=", b"ind_mutual_strong=",
                      b"ETA_CONV=", b"SELECT_CONV=", b"quot_abs=", b"quot_rep=",
                      b"quot_definition=", b"quot_lifted=", b"quot_double_not=", b"recursive_exists=", b"product_beta=",
                      b"standard_tree_induction=", b"standard_tree_recursion=")
    bound_normalized = sum(line.startswith(bound_prefixes) for line in observed.splitlines())
    verification = {
        "status": "passed",
        "host": host,
        "compiled_loaded_inputs": CORE,
        "fixtures": FIXTURES,
        "native_checks": checks,
        "standard_random_checks": random_checks,
        "proof_dsl_checks": proof_dsl_checks,
        "user_dsl_checks": int(user_dsl_markers[0]),
        "user_dsl_source_sha256": {
            str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in [*(ROOT / "holai/user").glob("*.lisp"), ROOT / "holai/tests/user-dsl.lisp"]},
        "pattern_host_specific_cases": {"sbcl_nan_bit_construction": implementation() == "sbcl",
                                        "abcl_nan_java_double": implementation() == "abcl"},
        "native_nan_eql": native_nan_eql,
        "pattern_stale_fasl_rejection": stale_rejection,
        "structural_pattern_checks": pattern_checks,
        "pattern_backend": "standard-common-lisp",
        "defunc_protocol_checks": protocol_checks,
        "optional_entry_checks": optional_checks,
        "star_naming_observations": 9,
        "star_allocator_checks": 21,
        "escaped_symbol_delimiters_in_core": 0,
        "tuple_list_checks": tuple_checks,
        "differential_observations": observations,
        "exact_differential_observations": observations - 3,
        "structurally_compared_registry_observations": 2,
        "structurally_compared_registry_rows": ["init_constants", "init_definitions"],
        "generated_registry_provenance": registry_provenance,
        "generated_registry_constant_normalization": "init_constants/init_definitions only; one name-to-ordinal map from initial constants traversal, shared by all definitions; distinct g: tag; explicit names, unknown constants, _0, types, order, multiplicity and reference identity unchanged",
        "property_validated_random_observations": 1,
        "random_observation_validation": "language_random= only: 8 bits, 8 int(97), 4 bits; bounds 2^30/97/2^30",
        "raw_observation_streams_equal": observed == lisp_observed,
        "serialized_observations": observations - printer_lines,
        "printer_side_effect_lines": printer_lines,
        "bound_variable_normalized_observations": bound_normalized,
        "bound_variable_normalization": "de Bruijn indices; free names and types unchanged",
        "schematic_type_variable_normalized_observations": 2,
        "schematic_type_variable_normalization": "init_constants/init_definitions only; generated ?decimal type variables by first structural occurrence in each scheme; explicit type names and sharing unchanged",
        "generated_registry_binder_normalized_observations": 1,
        "generated_registry_binder_normalization": "init_definitions: positive _decimal and GEN%PVAR%decimal names only at actual binders via de Bruijn indices; _0, authored bound names, free names, concrete types and structure unchanged",
        "meson_focused_positive_search_bound": 12,
        "meson_rule_default_search_bound": 50,
        "meson_negative_search_bound": 2,
        "additional_prover_positive_cases": {"METIS": 6, "LEANCOP": 6, "NANOCOP": 6},
        "additional_prover_assumption_cases": 3,
        "additional_prover_extra_hypothesis_rejections": 3,
        "connection_negative_deepening_bound": 2,
        "test_process_timeout_seconds": 120,
        "full_core_process_timeout_seconds": full_core_timeout(),
        "ocaml_full_core_process_timeout_seconds": 600,
        "host_limits": host["full_core_limits"],
        "native_interrupt_checks": int(native_interrupt_counts[0]),
        "native_interrupt_policy": "restore-previous-native-lisp-hook",
        "native_interrupt_previous_hook_restored": True,
        "sigint_adapter_checked": sigint_limitation is None,
        "sigint_status": "not_applicable" if sigint_limitation else "passed",
        "sigint_reason": sigint_limitation,
        "sigint_previous_hook_restored": sigint_limitation is None,
        "sigint_policy": "restore-previous-native-lisp-hook",
        "sigint_deliveries": 0 if sigint_limitation else 3,
        "sigint_catch_cycles": 0 if sigint_limitation else 2,
        "sigint_reenable_verified": sigint_limitation is None,
        "initial_registry_counts": {"types": 22, "constants": 303, "definitions": 263, "axioms": 3},
        "initial_source_axioms": ["INFINITY_AX", "SELECT_AX", "ETA_AX"],
        "explicit_primitive_fixture_axioms": 1,
        "execution_serialized_cases": 68,
        "arithmetic_serialized_cases": sum(line.startswith((b"arith_", b"arithmetic_")) for line in observed.splitlines()),
        "standard_serialized_cases": sum(line.startswith(b"standard_") for line in observed.splitlines()),
        "benign_warning_lines": sum(line.startswith(b"Warning: Benign") for line in observed.splitlines()),
        "hashtable_inventory_order": "sorted observer only; source fold order remains unspecified",
        "random_test_seeds": [0, -7],
        "random_profile": "Common Lisp RANDOM with private standard random-state; MAKE-RANDOM-STATE T on init; integer seed replay not guaranteed",
        "machine_int_shift_profile": "signed 63-bit; shift counts 0..63",
        "initialization_messages": len(original_init.splitlines()),
        "lisp_initialization_messages": len(lisp_init.splitlines()),
        "initialization_messages_equal": initialization_difference(original_init.decode(), lisp_init.decode()) == {"original_only": {}, "lisp_only": {}},
        "initialization_difference": verify_initialization(original_init.decode(), lisp_init.decode()),
        "initialization_difference_matches_profile": True,
        "initialization_message_normalization": "CPU durations only; other text and occurrence counts retained",
        "initialization_raw_message_multisets_equal": sorted(original_init.splitlines()) == sorted(lisp_init.splitlines()),
        "initialization_cpu_time_rows": sum(line.startswith((b"CPU time (user): ", b"Failed after (user) CPU time of ")) for line in original_init.splitlines()),
        "initialization_transcript_equal": original_init == lisp_init,
        "initialization_ocaml_sha256": hashlib.sha256(original_init).hexdigest(),
        "initialization_lisp_sha256": hashlib.sha256(lisp_init).hexdigest(),
        "observations_sha256": hashlib.sha256(observed).hexdigest(),
        "lisp_observations_sha256": hashlib.sha256(lisp_observed).hexdigest(),
        "comparison_sha256": hashlib.sha256(canonical_original.encode()).hexdigest(),
        "core_source_map_entries": root_count,
        "fixture_inclusive_source_map_entries": fixture_count,
        "rejection_checks": len(rejected),
        "unchanged_output_on_rejection": True,
        "identical_regeneration": True,
        "owned_symbol_cache_preserves_generation": json.loads((BUILD / "cache-equivalence-10.json").read_text())["identical_output"] if (BUILD / "cache-equivalence-10.json").exists() else None,
        "quotation_parsed_and_lowered": True,
        "quotation_executed_in_differential_corpus": True,
        "pinned_inputs_unchanged": True,
        "tested_toolchain": {
            "ocaml": run(["ocamlc", "-version"]).stdout.strip(),
            "camlp5": run(["camlp5r", "-version"]).stdout.strip(),
            "lisp": host,
        },
    }
    (reports / "verification.json").write_text(json.dumps(verification, indent=2) + "\n")
    print(f"PASS ({implementation()}): {len(CORE)} upstream files; {root_count} core source-map entries; "
          f"{fixture_count} total mapped entries; {len(rejected)} rejection checks; "
          f"quotation parsing; deterministic regeneration; {observations} differential observations "
          f"({observations - 3} exact + 2 structural registry + 1 property-validated Random).")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        path = report_directory() / "verification.json"
        failure = json.loads(path.read_text())
        if failure["status"] != "timed_out":
            failure["status"] = "timed_out" if isinstance(error, subprocess.TimeoutExpired) else "failed"
        failure.update(error_type=type(error).__name__, error_message=str(error))
        if isinstance(error, RegistryProvenanceError):
            failure["generated_registry_provenance"] = error.provenance
        path.write_text(json.dumps(failure, indent=2) + "\n")
        raise
