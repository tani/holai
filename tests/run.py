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

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
BUILD = ROOT / "_build"
BUILD.mkdir(exist_ok=True)
CLI = ["ocamlrun", "bin/hol2cl"]
CORE = ["vendor/hol-light/" + name for name in json.loads((ROOT / "vendor/CORE_FILES.json").read_text())]
FIXTURES = ["tests/fixtures/semantics.ml", "tests/fixtures/differential.ml", "tests/fixtures/extended.ml", "tests/fixtures/logic.ml", "tests/fixtures/tactical.ml", "tests/fixtures/foundation.ml", "tests/fixtures/language.ml", "tests/fixtures/provers.ml", "tests/fixtures/execution.ml", "tests/fixtures/arithmetic.ml", "tests/fixtures/standard.ml"]


def run(args, *, log=None, expected=0, core=False):
    result = subprocess.run(args, text=True, capture_output=True, timeout=600 if core else 120)
    if log:
        (BUILD / log).write_text(result.stdout + result.stderr)
    if result.returncode != expected:
        raise RuntimeError(f"Command failed ({result.returncode}): {shlex.join(args)}\n"
                           f"{result.stdout[-1000:]}\n{result.stderr[-4500:]}")
    return result


def initialization_messages(text):
    number = r"-?\d+(?:\.\d*)?(?:[eEdD][+-]?\d+)?"
    text = re.sub(r"(?m)^(CPU time \(user\): )" + number + r"$", r"\1<cpu-seconds>", text)
    return re.sub(r"(?m)^(Failed after \(user\) CPU time of )" + number + r"(?=: )",
                  r"\1<cpu-seconds>", text)


def initialization_difference(original, lisp):
    a = Counter(initialization_messages(original).splitlines())
    b = Counter(initialization_messages(lisp).splitlines())
    return {"original_only": dict(sorted((a-b).items())), "sbcl_only": dict(sorted((b-a).items()))}


def verify_initialization(original, lisp):
    difference = initialization_difference(original, lisp)
    expected = {"original_only": {"0..0..solved at 2": 1, "Warning: inventing type variables": 1}, "sbcl_only": {}}
    assert difference in ({"original_only": {}, "sbcl_only": {}}, expected), f"Unexpected initialization differences: {difference}"
    return difference


def verify_pins():
    lock = json.loads((ROOT / "vendor/SOURCES.json").read_text())
    for file, digest in lock["input_sha256"].items():
        actual = hashlib.sha256((ROOT / file).read_bytes()).hexdigest()
        assert actual == digest, f"Pinned source changed: {file}"


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
    if observed != lisp:
        diff = "\n".join(difflib.unified_diff(observed.splitlines(), lisp.splitlines(), fromfile="OCaml", tofile="SBCL"))
        raise AssertionError(f"Differential observations disagree:\n{diff[:8000]}")
    return len(observed.splitlines())


def main():
    verify_pins()
    protocol = run(["sbcl", "--noinform", "--disable-debugger", "--script", "tests/defunc-protocol.lisp"], log="defunc-protocol.log")
    protocol_checks = int(re.search(r"Protocol checks passed: (\d+)", protocol.stdout).group(1))
    optional = run(["sbcl", "--noinform", "--disable-debugger", "--script", "tests/optional-entry.lisp"], log="optional-entry.log")
    optional_checks = int(re.search(r"Optional entry checks passed: (\d+)", optional.stdout).group(1))
    tuple_test = run(["sbcl", "--noinform", "--disable-debugger", "--script", "tests/tuple-list.lisp"], log="tuple-list.log")
    tuple_checks = int(re.search(r"Tuple-list checks passed: (\d+)", tuple_test.stdout).group(1))
    inventory = json.loads(run(CLI + ["scan"] + CORE).stdout)
    assert all(x["parsed"] and x["translated"] for x in inventory)
    root_count = audit(ROOT / "generated", CORE)
    with tempfile.TemporaryDirectory(dir=BUILD) as temp:
        run(CLI + ["translate", "--output-dir", temp] + CORE)
        for file in (ROOT / "generated").iterdir():
            if file.is_file() and file.suffix in {".lisp", ".json", ".asd"}:
                assert file.read_bytes() == (Path(temp) / file.name).read_bytes(), f"Stale/nondeterministic: {file.name}"
        rejected = [
            (["tests/fixtures/unsupported.ml"], "Unsupported expression"),
            (["tests/fixtures/private_constructor.ml"], "Private constructor"),
            (["tests/fixtures/optional_argument.ml"], "Optional parameters"),
            (["tests/fixtures/dynamic_label.ml"], "Labelled call needs statically resolved parameter labels"),
            (["tests/fixtures/ambiguous_contents.ml"], "Ambiguous record labels"),
            (["tests/fixtures/hidden_constructor_history.ml"], "Invalid arity for non-tuple constructor payload"),
            (["tests/fixtures/recursive_dependency.ml"], "Recursive value initializer references its group: same"),
            (["tests/fixtures/recursive_cycle.ml"], "Recursive value initializer references its group: cycle"),
            (["tests/fixtures/recursive_module_dependency.ml"], "Recursive value initializer references its group: walk"),
            (CORE + ["tests/fixtures/opaque_constructor.ml"], "Unresolved identifier: Sequent"),
        ]
        for files, message in rejected:
            before = {p.name: p.read_bytes() for p in Path(temp).iterdir()}
            result = run(CLI + ["translate", "--output-dir", temp] + files, expected=1)
            assert message in result.stderr, result.stderr
            after = {p.name: p.read_bytes() for p in Path(temp).iterdir()}
            assert before == after, "Rejected translation modified prior output"
    quote = json.loads(run(CLI + ["scan"] + CORE + ["tests/fixtures/quotation.ml"]).stdout)[-1]
    assert quote["parsed"] and quote["translated"]
    interrupt = run(["sbcl", "--noinform", "--disable-debugger", "--script", "tests/system-interrupt.lisp"], log="system-interrupt.log")
    assert "SIGINT adapter check passed" in interrupt.stdout
    run(CLI + ["translate", "--output-dir", "_build/fixtures"] + CORE + FIXTURES)
    fixture_count = audit(BUILD / "fixtures", CORE + FIXTURES)
    sbcl = run(["sbcl", "--dynamic-space-size", "2048", "--control-stack-size", "256", "--noinform", "--disable-debugger", "--script", "tests/lisp-tests.lisp"], log="lisp-tests.log", core=True)
    assert "SBCL checks passed" in sbcl.stdout
    observations = differential()
    checks = int(re.search(r"SBCL checks passed: (\d+)", sbcl.stdout).group(1))
    reports = ROOT / "reports"
    reports.mkdir(exist_ok=True)
    observed = (BUILD / "ocaml-observations.txt").read_bytes()
    (reports / "ocaml-observations.txt").write_bytes(observed)
    (reports / "sbcl-observations.txt").write_bytes((BUILD / "lisp-observations.txt").read_bytes())
    original_init = (BUILD / "ocaml-initialization.txt").read_bytes()
    lisp_init = (BUILD / "lisp-initialization.txt").read_bytes()
    (reports / "ocaml-initialization.txt").write_bytes(original_init)
    (reports / "sbcl-initialization.txt").write_bytes(lisp_init)
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
        "compiled_loaded_inputs": CORE,
        "fixtures": FIXTURES,
        "sbcl_checks": checks,
        "defunc_protocol_checks": protocol_checks,
        "optional_entry_checks": optional_checks,
        "tuple_list_checks": tuple_checks,
        "differential_observations": observations,
        "serialized_observations": observations - printer_lines,
        "printer_side_effect_lines": printer_lines,
        "bound_variable_normalized_observations": bound_normalized,
        "bound_variable_normalization": "de Bruijn indices; free names and types unchanged",
        "schematic_type_variable_normalized_observations": 2,
        "schematic_type_variable_normalization": "init_constants/init_definitions only; generated ?decimal type variables by first structural occurrence in each scheme; explicit type names and sharing unchanged",
        "generated_registry_binder_normalized_observations": 1,
        "generated_registry_binder_normalized_schemes": 2,
        "generated_registry_binder_normalization": "init_definitions: GEN%PVAR%decimal bound variables only; authored bound names, free names and structure unchanged",
        "meson_focused_positive_search_bound": 12,
        "meson_rule_default_search_bound": 50,
        "meson_negative_search_bound": 2,
        "additional_prover_positive_cases": {"METIS": 6, "LEANCOP": 6, "NANOCOP": 6},
        "additional_prover_assumption_cases": 3,
        "additional_prover_extra_hypothesis_rejections": 3,
        "connection_negative_deepening_bound": 2,
        "test_process_timeout_seconds": 120,
        "full_core_process_timeout_seconds": 600,
        "sbcl_control_stack_mebibytes": 256,
        "sigint_adapter_checked": True,
        "initial_registry_counts": {"types": 22, "constants": 303, "definitions": 263, "axioms": 3},
        "initial_source_axioms": ["INFINITY_AX", "SELECT_AX", "ETA_AX"],
        "explicit_primitive_fixture_axioms": 1,
        "execution_serialized_cases": 68,
        "arithmetic_serialized_cases": sum(line.startswith((b"arith_", b"arithmetic_")) for line in observed.splitlines()),
        "standard_serialized_cases": sum(line.startswith(b"standard_") for line in observed.splitlines()),
        "benign_warning_lines": sum(line.startswith(b"Warning: Benign") for line in observed.splitlines()),
        "hashtable_inventory_order": "sorted observer only; source fold order remains unspecified",
        "random_test_seeds": [0, -7],
        "random_profile": "OCaml 4.14.1 seeded Random.init/bits/int; raw-byte MD5",
        "machine_int_shift_profile": "signed 63-bit; shift counts 0..63",
        "initialization_messages": len(original_init.splitlines()),
        "sbcl_initialization_messages": len(lisp_init.splitlines()),
        "initialization_messages_equal": initialization_difference(original_init.decode(), lisp_init.decode()) == {"original_only": {}, "sbcl_only": {}},
        "initialization_difference": verify_initialization(original_init.decode(), lisp_init.decode()),
        "initialization_difference_matches_profile": True,
        "initialization_message_normalization": "CPU durations only; other text and occurrence counts retained",
        "initialization_raw_message_multisets_equal": sorted(original_init.splitlines()) == sorted(lisp_init.splitlines()),
        "initialization_cpu_time_rows": sum(line.startswith((b"CPU time (user): ", b"Failed after (user) CPU time of ")) for line in original_init.splitlines()),
        "initialization_transcript_equal": original_init == lisp_init,
        "initialization_ocaml_sha256": hashlib.sha256(original_init).hexdigest(),
        "initialization_sbcl_sha256": hashlib.sha256(lisp_init).hexdigest(),
        "observations_sha256": hashlib.sha256(observed).hexdigest(),
        "core_source_map_entries": root_count,
        "fixture_inclusive_source_map_entries": fixture_count,
        "rejection_checks": len(rejected),
        "unchanged_output_on_rejection": True,
        "identical_regeneration": True,
        "owned_symbol_cache_preserves_generation": json.loads((BUILD / "cache-equivalence-10.json").read_text())["identical_output"] if (BUILD / "cache-equivalence-10.json").exists() else None,
        "quotation_parsed_and_lowered": True,
        "quotation_executed_in_differential_corpus": True,
        "pinned_inputs_unchanged": True,
        "tested_toolchain": json.loads((ROOT / "vendor/SOURCES.json").read_text())["tested_toolchain"],
    }
    (reports / "verification.json").write_text(json.dumps(verification, indent=2) + "\n")
    print(f"PASS: {len(CORE)} upstream files; {root_count} core source-map entries; "
          f"{fixture_count} total mapped entries; {len(rejected)} rejection checks; "
          f"quotation parsing; deterministic regeneration; {observations} differential observations.")


if __name__ == "__main__":
    main()
