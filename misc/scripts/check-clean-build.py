"""Build from source in an isolated directory and compare all core outputs."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
build = ROOT / "_build"
build.mkdir(exist_ok=True)
start = time.monotonic()
with tempfile.TemporaryDirectory(prefix="clean-build-", dir=build) as temporary:
    target = Path(temporary) / "holai"
    shutil.copytree(ROOT, target, ignore=shutil.ignore_patterns(
        ".git", "_build", "bin", "dist", "generated", "reports", "__pycache__",
        "*.cmo", "*.cmi", "*.cmx", "*.o", "*.fasl", "*.pyc"))
    with (build / "clean-build.log").open("w") as log:
        result = subprocess.run(["make", "regenerate"], cwd=target,
                                stdout=log, stderr=subprocess.STDOUT, timeout=120)
    if result.returncode:
        raise RuntimeError((build / "clean-build.log").read_text()[-3500:])
    files = sorted(p for p in (ROOT / "holai/generated").iterdir()
                   if p.is_file() and p.suffix in {".lisp", ".json"})
    core = json.loads((ROOT / "vendor/CORE_FILES.json").read_text())
    assert len(files) == 2 * len(core) + 1 == 93, len(files)
    regenerated = sorted(p.name for p in (target / "holai/generated").iterdir() if p.is_file())
    assert [p.name for p in files] == regenerated, "Clean output file set differs"
    for file in files:
        assert file.read_bytes() == (target / "holai/generated" / file.name).read_bytes(), file.name
    pins = json.loads((ROOT / "vendor/SOURCES.json").read_text())["input_sha256"]
    for name, digest in pins.items():
        assert hashlib.sha256((target / name).read_bytes()).hexdigest() == digest, name
report = {"build_from_sources": True, "compared_generated_files": len(files),
          "identical_output": True, "wall_seconds": round(time.monotonic()-start, 3),
          "source_pins_unchanged": True}
(ROOT / "misc/reports").mkdir(exist_ok=True)
(ROOT / "misc/reports/clean-build.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Clean build: {len(files)} generated files identical; pinned inputs unchanged.")
