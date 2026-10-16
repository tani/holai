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
    advanced = re.findall(r"(?m)^User advanced DSL checks passed: (\d+)$", output)
    if (result.returncode or len(counters) != 1 or int(counters[0]) <= 0
            or len(definitions) != 1 or int(definitions[0]) <= 0
            or len(advanced) != 1 or int(advanced[0]) <= 0):
        raise RuntimeError(f"User DSL suite failed; see {log}\n{output[-8000:]}")
    contract_log = ROOT / "_build/user-contracts.log"
    with contract_log.open("w") as stream:
        contracts = subprocess.run(
            command(ROOT / "holai/tests/user-contracts-runner.lisp", core=True),
            cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
            timeout=full_core_timeout())
    contract_output = contract_log.read_text()
    contract_counts = re.findall(r"(?m)^User isolated contract checks passed: (\d+)$", contract_output)
    if contracts.returncode or len(contract_counts) != 1 or int(contract_counts[0]) <= 0:
        raise RuntimeError(f"Isolated user contracts failed; see {contract_log}\n{contract_output[-8000:]}")
    print(f"User DSL checks passed: {counters[0]}; definition checks: {definitions[0]} "
          f"advanced checks: {advanced[0]}; isolated contracts: {contract_counts[0]} "
          f"(fresh full cores; logs: {log}, {contract_log})")


if __name__ == "__main__":
    main()
