"""Run the optional proof language suite against a fresh complete HOL core."""
from pathlib import Path
import re
import subprocess
from lisp_host import command, full_core_timeout

ROOT = Path(__file__).resolve().parents[2]


def main():
    log = ROOT / "_build/user-dsl.log"
    log.parent.mkdir(exist_ok=True)
    with log.open("w") as stream:
        result = subprocess.run(
            command(ROOT / "holai/tests/user-dsl-runner.lisp", core=True),
            cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
            timeout=full_core_timeout())
    output = log.read_text()
    counters = re.findall(r"(?m)^User DSL checks passed: (\d+)$", output)
    definitions = re.findall(r"(?m)^User definition DSL checks passed: (\d+)$", output)
    if (result.returncode or len(counters) != 1 or int(counters[0]) <= 0
            or len(definitions) != 1 or int(definitions[0]) <= 0):
        raise RuntimeError(f"User DSL suite failed; see {log}\n{output[-8000:]}")
    print(f"User DSL checks passed: {counters[0]}; definition checks: {definitions[0]} "
          f"(fresh full core; log: {log})")


if __name__ == "__main__":
    main()
