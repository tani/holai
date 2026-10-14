"""Audit production compilation and ASDF order from a fresh per-host cache."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import time
import tempfile
from lisp_host import command, full_core_timeout, metadata, report_directory

ROOT = Path(__file__).resolve().parents[2]
report = report_directory()
host = metadata()
core = [Path(name).stem for name in json.loads((ROOT / 'vendor/CORE_FILES.json').read_text())]
runtime = [f'holai/runtime/{name}.lisp' for name in ['package', 'pattern', 'core', 'format', 'stdlib']]
expected_units = runtime + [f'holai/generated/{name}.lisp' for name in core] + ['holai/all.lisp']
with tempfile.TemporaryDirectory(prefix='host-diagnostics-', dir=ROOT / '_build') as work:
    work = Path(work)
    driver = work / 'audit.lisp'
    driver.write_text('''(require :asdf)
(defparameter cl-user::*audit-stream* *error-output*)
(defparameter cl-user::*audit-phase* "INITIALIZATION")
(defparameter cl-user::*audit-unit* "holai/tests/bootstrap.lisp")
(defun audit-source-path (component)
  (enough-namestring (asdf:component-pathname component) (truename "./")))
(defun audit-flush ()
  (finish-output *standard-output*)
  (finish-output *error-output*)
  (finish-output cl-user::*audit-stream*))
(defmacro with-audit-operation ((phase unit) &body body)
  `(let ((cl-user::*audit-phase* ,phase)
         (cl-user::*audit-unit* ,unit))
     (audit-flush)
     (format cl-user::*audit-stream* "~&AUDIT_BEGIN ~a ~a~%"
             cl-user::*audit-phase* cl-user::*audit-unit*)
     (audit-flush)
     (unwind-protect (progn ,@body)
       (audit-flush)
       (format cl-user::*audit-stream* "~&AUDIT_END ~a ~a~%"
               cl-user::*audit-phase* cl-user::*audit-unit*)
       (audit-flush))))
(defmethod asdf:perform :around ((op asdf:compile-op) (component asdf:cl-source-file))
  (with-audit-operation ("COMPILE" (audit-source-path component))
    (multiple-value-prog1 (call-next-method)
      (format cl-user::*audit-stream* "~&COMPILED_UNIT ~a~%" cl-user::*audit-unit*)
      (when (typep (asdf:component-parent component) 'asdf:package-inferred-system)
        (format cl-user::*audit-stream* "~&INFERRED_UNIT ~a~%" cl-user::*audit-unit*)))))
(defmethod asdf:perform :around ((op asdf:load-op) (component asdf:cl-source-file))
  (with-audit-operation ("LOAD" (audit-source-path component))
    (multiple-value-prog1 (call-next-method)
      (format cl-user::*audit-stream* "~&LOADED_UNIT ~a~%" cl-user::*audit-unit*))))
;; Observe, never muffle: compile-time evaluation belongs to COMPILE, while
;; FASL loading and source HOL initialization have their own evidence scope.
(handler-bind
    ((warning (lambda (condition)
                (format cl-user::*audit-stream* "~&AUDIT_CONDITION ~a ~a ~a ~a~%"
                        cl-user::*audit-phase*
                        (if (typep condition 'style-warning) "STYLE_WARNING" "WARNING")
                        cl-user::*audit-unit* condition)
                (audit-flush)))
     (error (lambda (condition)
              (format cl-user::*audit-stream* "~&AUDIT_CONDITION ~a ERROR ~a ~a~%"
                      cl-user::*audit-phase* cl-user::*audit-unit* condition)
              (audit-flush))))
  (with-audit-operation ("INITIALIZATION" "holai/tests/bootstrap.lisp")
    (load "holai/tests/bootstrap.lisp")))
(assert (typep (asdf:find-system "holai") 'asdf:package-inferred-system))
(format cl-user::*audit-stream* "~&DIAGNOSTICS_AUDIT_COMPLETE~%")
(audit-flush)
''')
    env = dict(os.environ, XDG_CACHE_HOME=str(work / 'cache'))
    args = command(driver, core=True)
    started = time.monotonic()
    timeout_seconds = full_core_timeout()
    timeout_error = None
    try:
        proc = subprocess.run(args, cwd=ROOT, env=env,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, timeout=timeout_seconds)
        text, exit_code = proc.stdout, proc.returncode
    except subprocess.TimeoutExpired as error:
        # TimeoutExpired carries bytes even when subprocess.run uses text=True.
        timeout_error = error
        captured = error.stdout or b''
        text = captured.decode('utf-8', errors='replace') if isinstance(captured, bytes) else captured
        exit_code = None
    elapsed_seconds = time.monotonic() - started
(report / 'compile-diagnostics.txt').write_text(text)
units = re.findall(r'(?m)^COMPILED_UNIT (.+)$', text)
loaded_units = re.findall(r'(?m)^LOADED_UNIT (.+)$', text)
inferred_units = re.findall(r'(?m)^INFERRED_UNIT (.+)$', text)
counts = {f'{scope}_{kind}': 0 for scope in ('compiler', 'load_initialization')
          for kind in ('errors', 'warnings', 'style_warnings', 'warning_notices')}
notice = re.compile(r'^(?:; caught (?:error|warning|style-warning):|(?:style-)?warning:|.*: warning:)', re.I)
operations, active_operations, boundary_errors = [], [], []
for line in text.splitlines():
    boundary = re.fullmatch(r'AUDIT_(BEGIN|END) (COMPILE|LOAD|INITIALIZATION) (.+)', line)
    if boundary:
        action, phase, unit = boundary.groups()
        if action == 'BEGIN':
            operation = dict(phase=phase, unit=unit, ended=False, unit_completed=False)
            operations.append(operation)
            active_operations.append(operation)
        elif active_operations and (active_operations[-1]['phase'], active_operations[-1]['unit']) == (phase, unit):
            active_operations.pop()['ended'] = True
        else:
            boundary_errors.append(line)
        continue
    completion = re.fullmatch(r'(COMPILED|LOADED)_UNIT (.+)', line)
    if completion and active_operations:
        kind, unit = completion.groups()
        operation = active_operations[-1]
        phase = 'COMPILE' if kind == 'COMPILED' else 'LOAD'
        if (operation['phase'], operation['unit']) == (phase, unit):
            operation['unit_completed'] = True
    condition = re.match(r'^AUDIT_CONDITION (COMPILE|LOAD|INITIALIZATION) (ERROR|WARNING|STYLE_WARNING) ', line)
    if condition:
        phase, kind = condition.groups()
        scope = 'compiler' if phase == 'COMPILE' else 'load_initialization'
        counts[f'{scope}_{dict(ERROR="errors", WARNING="warnings", STYLE_WARNING="style_warnings")[kind]}'] += 1
    if notice.match(line):
        phase = active_operations[-1]['phase'] if active_operations else 'INITIALIZATION'
        scope = 'compiler' if phase == 'COMPILE' else 'load_initialization'
        counts[f'{scope}_warning_notices'] += 1
compile_operations = [op for op in operations if op['phase'] == 'COMPILE']
compiler_scope_complete = (not boundary_errors and not active_operations
                           and [op['unit'] for op in compile_operations] == expected_units
                           and all(op['ended'] and op['unit_completed'] for op in compile_operations))
result = dict(host=host, fresh_asdf_cache=True, compiled_units=units, compiled_unit_count=len(units),
              loaded_units=loaded_units, inferred_units=inferred_units,
              inferred_load_order_matches_manifest=loaded_units == expected_units,
              **counts,
              compiler_scope_complete=compiler_scope_complete,
              operations=operations, active_operations=active_operations,
              last_operation=operations[-1] if operations else None,
              boundary_errors=boundary_errors,
              timed_out=timeout_error is not None, timeout_seconds=timeout_seconds,
              elapsed_seconds=elapsed_seconds, command=args,
              diagnostic_accounting='Unmuffled Common Lisp conditions and raw notices within ASDF COMPILE-OP BEGIN/END boundaries; LOAD and source initialization recorded separately',
              code_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in [ROOT / 'holai.asd', ROOT / 'holai/all.lisp',
                                     ROOT / 'holai/generated/package-systems.sexp',
                                     *(ROOT / 'ml2cl').glob('*.ml'),
                                     *(ROOT / name for name in expected_units if name != 'holai/all.lisp')]},
              audit_complete=bool(re.search(r'(?m)^DIAGNOSTICS_AUDIT_COMPLETE$', text)),
              exit_code=exit_code,
              scope='5 runtime files, all 46 inferred production core files, and inferred holai/all entry; compiler diagnostics scoped to COMPILE-OP including compile-time evaluation; load/initialization diagnostics separate; pinned upstream unchanged')
(report / 'compile-diagnostics.json').write_text(json.dumps(result, indent=2) + '\n')
if timeout_error is not None:
    print(f"{host['implementation']}: diagnostics timed out at {timeout_seconds}s; "
          f"active operations: {active_operations}; partial output: {report / 'compile-diagnostics.txt'}",
          flush=True)
    raise timeout_error
assert exit_code == 0 and result['audit_complete'], text[-4000:]
assert units == expected_units and len(set(units)) == 52, units
assert loaded_units == expected_units, loaded_units
assert inferred_units == expected_units[5:], inferred_units
assert compiler_scope_complete, result
assert not any(result[k] for k in ['compiler_errors', 'compiler_warnings',
                                  'compiler_style_warnings', 'compiler_warning_notices',
                                  'load_initialization_errors']), result
print(f"{host['implementation']}: cold diagnostics: 52 unique production files in manifest order; "
      "47 genuine inferred core/entry; zero compiler errors, warnings and style warnings; "
      f"load/initialization warnings recorded separately: {result['load_initialization_warnings']} warnings, "
      f"{result['load_initialization_style_warnings']} style warnings, "
      f"{result['load_initialization_warning_notices']} raw notices.")
