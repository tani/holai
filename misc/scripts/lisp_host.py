"""Pinned Common Lisp host invocations shared by launchers and tooling."""
from pathlib import Path
import argparse
import resource
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IMPLEMENTATIONS = ("abcl", "sbcl", "ecl", "ccl", "mkcl", "clisp", "cmucl_binary", "clasp-common-lisp")
EXECUTABLES = {"cmucl_binary": "lisp", "clasp-common-lisp": "clasp"}
HOST_TYPES = {"abcl": "armed bear common lisp", "sbcl": "sbcl", "ecl": "ecl",
              "ccl": "clozure common lisp", "mkcl": "mkcl", "clisp": "clisp",
              "cmucl_binary": "cmu common lisp", "clasp-common-lisp": "clasp"}
NATIVE_NAN_LIMITATIONS = {
    "clisp": {
        "marker": "Pattern native NaN EQL: not applicable (CLISP cannot represent NaN)",
        "reason": "CLISP does not represent IEEE NaN as a native Lisp float",
    },
    "ecl": {
        "marker": "Pattern native NaN EQL: not applicable (ECL native COMPILE cannot externalize a NaN literal)",
        "reason": "ECL native COMPILE cannot externalize a NaN literal into a FASL",
    },
}


def selected_implementations():
    import shutil
    explicit = os.environ.get("HOLAI_LISPS")
    names = tuple(explicit.split(",")) if explicit else tuple(
        name for name in IMPLEMENTATIONS
        if shutil.which(os.environ.get("HOLAI_" + name.upper().replace("-", "_"),
                                      EXECUTABLES.get(name, name))))
    if not names or len(set(names)) != len(names) or any(name not in IMPLEMENTATIONS for name in names):
        raise ValueError("HOLAI_LISPS must select distinct known implementation IDs")
    return names


def implementation():
    name = os.environ.get("HOLAI_LISP", "sbcl").lower()
    if name not in IMPLEMENTATIONS:
        raise ValueError(f"Unsupported HOLAI_LISP: {name}; expected one of {IMPLEMENTATIONS}")
    return name


def full_core_timeout(host=None):
    """Guard for complete native suites and cold production diagnostics."""
    return 3600 if (implementation() if host is None else host) in ("ecl", "abcl", "clisp") else 600


def executable():
    name = implementation()
    return os.environ.get("HOLAI_" + name.upper().replace("-", "_"), EXECUTABLES.get(name, name))


def command(path=None, *, core=False, interactive=False, extra=()):
    name = implementation()
    if name == "sbcl":
        args = [executable(), "--noinform"]
        if not interactive and path is None:
            args += ["--non-interactive"]
        if core:
            args += ["--dynamic-space-size", "2048", "--control-stack-size", "256"]
        if not interactive:
            args += ["--disable-debugger"]
        if path is not None:
            args += ["--load" if interactive else "--script", str(path)]
        return args + list(extra)
    if name != "ecl":
        if name == "clisp" and interactive:
            # -x itself imposes batch mode. Bootstrap requires ASDF before UIOP.
            args = [executable(), "--quiet", "-norc"]
            if path is not None:
                args += ["-i", str(path)]
            return args + ["-x" if arg == "--eval" else arg for arg in extra]
        eval_flag = {"clisp": "-x", "cmucl_binary": "-eval", "mkcl": "-eval"}.get(name, "--eval")
        quiet = {"clisp": "--quiet", "cmucl_binary": "-quiet", "mkcl": "--quiet",
                 "ccl": "--quiet"}.get(name, "--noinform")
        args = [executable(), quiet, eval_flag, '(require "asdf")',
                eval_flag, '(setf asdf:*asdf-verbose* nil *load-verbose* nil *compile-verbose* nil)']
        if name == "abcl":
            args += ["--noinit"]
            if not interactive:
                args += ["--batch"]
        elif name == "clisp":
            args += ["-norc"]
        if not interactive:
            args += [eval_flag, '(setf *debugger-hook* (lambda (condition hook) (declare (ignore hook)) (format *error-output* "~&Unhandled condition: ~a~%" condition) (uiop:quit 1)))']
        if path is not None:
            # LOAD through EVAL avoids implementation-specific script/load switches.
            import json
            args += [eval_flag, "(load " + json.dumps(str(path)) + ")"]
        extras = list(extra)
        args += [eval_flag if arg == "--eval" else arg for arg in extras]
        if not interactive:
            args += [eval_flag, "(uiop:quit 0)"]
        if name == "clisp":
            # CLISP accepts one expression series; keep forms separate so REQUIRE
            # runs before the reader encounters package-qualified UIOP symbols.
            flags, forms = [], []
            index = 1
            while index < len(args):
                if args[index] == eval_flag:
                    # Collect expressions without altering script output.
                    forms.append(args[index + 1])
                    index += 2
                else:
                    flags.append(args[index])
                    index += 1
            # REQUIRE must be read/evaluated before the remaining ASDF/UIOP
            # forms. Batch mode exits inside the second expression, preventing
            # CLISP's value printer from adding a newline after LOAD.
            args = [args[0], *flags, eval_flag, "(progn " + forms[0] + " (values))",
                    eval_flag, "(progn " + "\n".join(forms[1:]) + ")"]
        return args
    args = [executable(), "--norc", "--eval", "(require :asdf)",
            "--eval", "(setf asdf:*asdf-verbose* nil *load-verbose* nil *compile-verbose* nil)"]
    if core:
        args += ["--heap-size", str(2048 * 1024 * 1024),
                 "--c-stack", str(256 * 1024 * 1024)]
    if not interactive:
        # REQUIRE is its own argument: ECL reads each --eval before evaluation.
        args += ["--eval", "(setf *debugger-hook* (lambda (condition hook) (declare (ignore hook)) (format *error-output* \"~&Unhandled condition: ~a~%\" condition) (uiop:quit 1)))"]
    if path is not None:
        args += ["--load", str(path)]
    args += list(extra)
    if not interactive:
        args += ["--eval", "(uiop:quit 0)"]
    return args


def metadata():
    proc = subprocess.run(command(extra=["--eval", '(format t "~&HOLAI_HOST_VERSION ~a~%HOLAI_HOST_TYPE ~a~%" (lisp-implementation-version) (lisp-implementation-type))']),
                          cwd=ROOT, capture_output=True, text=True, timeout=120, check=True)
    version = next(line.removeprefix("HOLAI_HOST_VERSION ") for line in proc.stdout.splitlines()
                   if line.startswith("HOLAI_HOST_VERSION "))
    actual_type = next(line.removeprefix("HOLAI_HOST_TYPE ") for line in proc.stdout.splitlines()
                       if line.startswith("HOLAI_HOST_TYPE "))
    if actual_type.lower() != HOST_TYPES[implementation()]:
        raise ValueError(f"Selected {implementation()}, but executable reports {actual_type}")
    soft_stack, hard_stack = resource.getrlimit(resource.RLIMIT_STACK)
    return {"implementation": implementation(), "implementation_type": actual_type, "version": version,
            "executable": executable(), "os_stack_limit_bytes":
            {"soft": soft_stack, "hard": hard_stack}, "full_core_limits":
            {"dynamic_space_mebibytes": 2048, "control_stack_mebibytes": 256}
            if implementation() == "sbcl" else
            {"heap_bytes": 2048 * 1024 * 1024, "c_stack_bytes": 256 * 1024 * 1024,
             "lisp_and_frame_stack": "ECL native defaults", "os_stack_limit": "inherited"}
            if implementation() == "ecl" else
            {"heap_and_stack": "Implementation defaults", "os_stack_limit": "inherited",
             "java_tool_options": os.environ.get("JAVA_TOOL_OPTIONS"),
             "upstream_interpreter_thread_stack_request_bytes": 4194304,
             "control_stack_cap": "Not configured; JVM and ABCL stack limits remain host defaults"}
            if implementation() == "abcl" else
            {"heap_and_stack": "Implementation defaults", "os_stack_limit": "inherited"}}


def report_directory():
    path = ROOT / "misc/reports/implementations" / implementation()
    path.mkdir(parents=True, exist_ok=True)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", action="store_true", help="load the core and exit")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="native implementation arguments")
    options = parser.parse_args()
    args = options.args
    if args[:1] == ["--"]:
        args = args[1:]
    os.chdir(ROOT)
    os.execvp(executable(), command("holai/tests/bootstrap.lisp", core=True,
                                   interactive=not options.batch, extra=args))


if __name__ == "__main__":
    main()
