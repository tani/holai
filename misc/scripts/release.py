"""Package the complete project, with mandatory design and translator sources."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[2]
version = "1.0.0-percent-names"
core = [Path(name).stem for name in json.loads((root / "vendor/CORE_FILES.json").read_text())]
required = ["DESIGN.md", "AGENTS.md", "README.md", "docs/RELEASE-NOTES.md", "Makefile", "holai-runtime.asd",
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
            "misc/scripts/scan_core.py", "misc/scripts/release.py", "misc/scripts/check-clean-build.py", "misc/scripts/run-sbcl.sh", "vendor/SOURCES.json", "vendor/CORE_FILES.json",
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
            "holai/generated/inventory.json", "holai/generated/holai-generated.asd",
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
required += ["holai/runtime/pattern.lisp", "holai/tests/pattern.lisp", "holai/tests/pattern-inspect.lisp",
             "misc/scripts/measure-pattern.py", "misc/reports/PATTERN-MATCH.md", "misc/reports/pattern-performance.json",
             "misc/reports/pattern-expansion-and-assembly.txt", "misc/reports/pattern-checks.txt"]
required += ["holai/tests/star-allocator.ml", "holai/tests/fixtures/star_names.ml", "holai/tests/star-names.py", "holai/tests/star-names.lisp", "misc/reports/star-names.json", "misc/reports/STAR-NAMES.md"]
pins = json.loads((root / "vendor/SOURCES.json").read_text())["input_sha256"]
required += list(pins)
for name in required:
    assert (root / name).is_file(), f"Required release file missing: {name}"
for name, digest in pins.items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Pinned source changed: {name}"
diagnostics = json.loads((root / "misc/reports/compile-diagnostics.json").read_text())
assert diagnostics["audit_complete"] and diagnostics["exit_code"] == 0 and diagnostics["compiled_unit_count"] == 51
assert all(diagnostics[k] == 0 for k in ["caught_errors", "caught_warnings", "caught_style_warnings", "warning_notices"])
for name, digest in diagnostics["code_sha256"].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Stale diagnostic report: {name}"
verification = json.loads((root / "misc/reports/verification.json").read_text())
assert verification["pattern_backend"] == "standard-common-lisp"
assert verification["structural_pattern_checks"] >= 46
assert verification["proof_dsl_checks"] > 0
assert verification["compiled_loaded_inputs"] == [f"vendor/hol-light/{name}.ml" for name in core]
assert verification["identical_regeneration"] and verification["pinned_inputs_unchanged"]
clean_build = json.loads((root / "misc/reports/clean-build.json").read_text())
assert clean_build["build_from_sources"] and clean_build["identical_output"] and clean_build["source_pins_unchanged"]
assert clean_build["compared_generated_files"] == 2 * len(core) + 2
observed = (root / "misc/reports/ocaml-observations.txt").read_bytes()
assert observed == (root / "misc/reports/sbcl-observations.txt").read_bytes()
assert hashlib.sha256(observed).hexdigest() == verification["observations_sha256"]
original_init = (root / "misc/reports/ocaml-initialization.txt").read_bytes()
lisp_init = (root / "misc/reports/sbcl-initialization.txt").read_bytes()
assert verification["initialization_difference_matches_profile"]
assert (original_init == lisp_init) == verification["initialization_transcript_equal"]
import sys
sys.path.insert(0, str(root / "holai/tests"))
from run import verify_initialization
assert verify_initialization(original_init.decode(), lisp_init.decode()) == verification["initialization_difference"]
assert hashlib.sha256(original_init).hexdigest() == verification["initialization_ocaml_sha256"]
assert hashlib.sha256(lisp_init).hexdigest() == verification["initialization_sbcl_sha256"]
excluded = {"_build", "bin", "dist", ".git", "__pycache__"}
files = sorted(p for p in root.rglob("*") if p.is_file() and not any(part in excluded for part in p.relative_to(root).parts)
               and p.suffix not in {".cmo", ".cmi", ".cmx", ".o", ".fasl", ".pyc"})
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
