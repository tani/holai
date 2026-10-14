"""Package the complete project, with mandatory design and translator sources."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
version = "1.0.0-percent-names"
core = [Path(name).stem for name in json.loads((root / "vendor/CORE_FILES.json").read_text())]
required = ["DESIGN.md", "AGENTS.md", "README.md", "RELEASE-NOTES.md", "Makefile", "hol2cl-runtime.asd",
            "src/sexp.ml", "src/scope.ml", "src/compiler.ml", "src/frontend.ml", "src/cli.ml",
            "runtime/package.lisp", "runtime/core.lisp", "runtime/format.lisp", "runtime/stdlib.lisp",
            "tests/run.py", "tests/lisp-tests.lisp", "tests/bootstrap.lisp", "tests/profile-core.lisp", "tests/system-interrupt.lisp",
            "tests/fixtures/semantics.ml", "tests/fixtures/differential.ml", "tests/fixtures/extended.ml", "tests/fixtures/logic.ml",
            "tests/fixtures/tactical.ml", "tests/fixtures/foundation.ml",
            "tests/fixtures/language.ml", "tests/fixtures/provers.ml",
            "tests/fixtures/execution.ml", "tests/fixtures/ambiguous_contents.ml", "tests/fixtures/hidden_constructor_history.ml",
            "tests/fixtures/arithmetic.ml", "tests/fixtures/recursive_dependency.ml",
            "tests/fixtures/standard.ml",
            "tests/fixtures/recursive_cycle.ml", "tests/fixtures/recursive_module_dependency.ml",
            "tests/fixtures/optional_argument.ml", "tests/fixtures/dynamic_label.ml",
            "tests/fixtures/quotation.ml", "tests/fixtures/unsupported.ml",
            "tests/fixtures/private_constructor.ml", "tests/fixtures/opaque_constructor.ml",
            "scripts/scan_core.py", "scripts/release.py", "scripts/check-clean-build.py", "scripts/run-sbcl.sh", "vendor/SOURCES.json", "vendor/CORE_FILES.json",
            "reports/core-inventory.json", "reports/COVERAGE.md", "reports/verification.json",
            "reports/core-profile.json",
            "reports/clean-build.json",
            "tests/defunc-protocol.lisp", "tests/measure-startup.lisp", "scripts/measure-startup.py",
            "reports/history/defunc-experiment.json", "reports/history/defunc-baseline.json", "reports/history/DEFUNC-EXPERIMENT.md",
            "reports/history/defunc-protocol.txt", "reports/history/defunc-fasl-startup.txt",
            "scripts/measure-peak-memory.py", "reports/history/peak-memory-comparison.json",
            "reports/history/peak-memory-baseline.txt", "reports/history/peak-memory-defunc.txt",
            "reports/ocaml-observations.txt", "reports/sbcl-observations.txt",
            "reports/ocaml-initialization.txt", "reports/sbcl-initialization.txt",
            "generated/inventory.json", "generated/hol2cl-generated.asd",
            "LICENSE", "THIRD-PARTY-NOTICES.md"]
required += ["scripts/measure-tuple-list.py", "tests/tuple-list.lisp", "reports/history/TUPLE-LIST.md", "reports/history/tuple-list-startup.json", "reports/history/tuple-list-startup.txt", "reports/history/tuple-list-checks.txt", "tests/profile-performance.lisp", "tests/profile-sets.lisp", "tests/probe-tuple.lisp",
             "reports/history/NEXT-BOTTLENECKS.md", "reports/history/next-bottlenecks.json",
             "reports/history/defunc-cpu-self.txt", "reports/history/defunc-cpu-inclusive.txt", "reports/history/defunc-cpu-startup.txt",
             "reports/history/defunc-sets-graph.txt", "reports/history/defunc-sets-startup.txt", "reports/history/tuple-probe.txt"]
required += [f"generated/{name}{suffix}" for name in core for suffix in [".lisp", ".map.json"]]
required += ["scripts/measure-ocamlopt.py", "reports/OCAMLOPT-STARTUP.md", "reports/ocamlopt-startup.json", "reports/ocamlopt-build.txt"]
required += [f"reports/ocamlopt-startup-run{i}.txt" for i in [1,2,3]]
required += ["docs/STATIC-CALL-PLAN.md"]
required += ["scripts/compile-core.sh", "scripts/prepare-optional-baseline.py", "scripts/measure-optional.py", "tests/optional-baseline-core.lisp", "tests/optional-entry.lisp", "tests/optional-inspect.lisp", "tests/optional-benchmark.lisp", "reports/OPTIONAL-ENTRY.md", "reports/optional-entry.json", "reports/optional-before.asm", "reports/optional-after.asm", "reports/optional-baseline-micro.txt", "reports/optional-optional-micro.txt", "reports/optional-checks.txt"]
required += [f"reports/optional-{mode}-startup-run{i}.{suffix}" for mode in ["baseline", "optional"] for i in [1,2] for suffix in ["json", "txt"]]
required += ["scripts/check-compile-diagnostics.py", "reports/compile-diagnostics.json", "reports/compile-diagnostics.txt", "reports/PERCENT-NAMES.md"]
required += ["runtime/pattern.lisp", "tests/pattern.lisp", "tests/pattern-inspect.lisp",
             "scripts/measure-pattern.py", "reports/PATTERN-MATCH.md", "reports/pattern-performance.json",
             "reports/pattern-expansion-and-assembly.txt", "reports/pattern-checks.txt"]
required += ["tests/star-allocator.ml", "tests/fixtures/star_names.ml", "tests/star-names.py", "tests/star-names.lisp", "reports/star-names.json", "reports/STAR-NAMES.md"]
pins = json.loads((root / "vendor/SOURCES.json").read_text())["input_sha256"]
required += list(pins)
for name in required:
    assert (root / name).is_file(), f"Required release file missing: {name}"
for name, digest in pins.items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Pinned source changed: {name}"
diagnostics = json.loads((root / "reports/compile-diagnostics.json").read_text())
assert diagnostics["audit_complete"] and diagnostics["exit_code"] == 0 and diagnostics["compiled_unit_count"] == 51
assert all(diagnostics[k] == 0 for k in ["caught_errors", "caught_warnings", "caught_style_warnings", "warning_notices"])
for name, digest in diagnostics["code_sha256"].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, f"Stale diagnostic report: {name}"
verification = json.loads((root / "reports/verification.json").read_text())
assert verification["pattern_backend"] == "standard-common-lisp"
assert verification["structural_pattern_checks"] >= 46
assert verification["compiled_loaded_inputs"] == [f"vendor/hol-light/{name}.ml" for name in core]
assert verification["identical_regeneration"] and verification["pinned_inputs_unchanged"]
clean_build = json.loads((root / "reports/clean-build.json").read_text())
assert clean_build["build_from_sources"] and clean_build["identical_output"] and clean_build["source_pins_unchanged"]
assert clean_build["compared_generated_files"] == 2 * len(core) + 2
observed = (root / "reports/ocaml-observations.txt").read_bytes()
assert observed == (root / "reports/sbcl-observations.txt").read_bytes()
assert hashlib.sha256(observed).hexdigest() == verification["observations_sha256"]
original_init = (root / "reports/ocaml-initialization.txt").read_bytes()
lisp_init = (root / "reports/sbcl-initialization.txt").read_bytes()
assert verification["initialization_difference_matches_profile"]
assert (original_init == lisp_init) == verification["initialization_transcript_equal"]
import sys
sys.path.insert(0, str(root / "tests"))
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
