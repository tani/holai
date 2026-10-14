"""Audit all production compilation diagnostics from a fresh ASDF cache."""
from pathlib import Path
import hashlib, json, os, re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[2]
report = ROOT / 'misc/reports'
core = [Path(name).stem for name in json.loads((ROOT/'vendor/CORE_FILES.json').read_text())]
runtime = [f'holai/runtime/{name}.lisp' for name in ['package', 'pattern', 'core', 'format', 'stdlib']]
expected_units = runtime + [f'holai/generated/{name}.lisp' for name in core] + ['holai/all.lisp']
with tempfile.TemporaryDirectory(prefix='percent-diagnostics-', dir=ROOT/'_build') as work:
    work = Path(work)
    driver = work/'audit.lisp'
    driver.write_text('''(require :asdf)
(defparameter cl-user::*audit-stream* *error-output*)
(defun audit-source-path (component)
  (enough-namestring (asdf:component-pathname component) (truename ".")))
(defmethod asdf:perform :around ((op asdf:compile-op) (component asdf:cl-source-file))
  (prog1 (call-next-method)
    (format cl-user::*audit-stream* "~&COMPILED_UNIT ~a~%" (audit-source-path component))
    (when (typep (asdf:component-parent component) 'asdf:package-inferred-system)
      (format cl-user::*audit-stream* "~&INFERRED_UNIT ~a~%" (audit-source-path component)))))
(defmethod asdf:perform :around ((op asdf:load-op) (component asdf:cl-source-file))
  (prog1 (call-next-method)
    (format cl-user::*audit-stream* "~&LOADED_UNIT ~a~%" (audit-source-path component))))
(load "holai/tests/bootstrap.lisp")
(assert (typep (asdf:find-system "holai") 'asdf:package-inferred-system))
(format cl-user::*audit-stream* "~&DIAGNOSTICS_AUDIT_COMPLETE~%")
''')
    env = dict(os.environ, XDG_CACHE_HOME=str(work/'cache'))
    proc = subprocess.run(['sbcl','--dynamic-space-size','2048','--control-stack-size','256',
                           '--noinform','--non-interactive','--load',str(driver)],cwd=ROOT,
                          env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=600)
(report/'compile-diagnostics.txt').write_text(proc.stdout)
text = (report/'compile-diagnostics.txt').read_text()
units = re.findall(r'(?m)^COMPILED_UNIT (.+)$', text)
loaded_units = re.findall(r'(?m)^LOADED_UNIT (.+)$', text)
inferred_units = re.findall(r'(?m)^INFERRED_UNIT (.+)$', text)
result = dict(fresh_asdf_cache=True, compiled_units=units, compiled_unit_count=len(units),
              loaded_units=loaded_units, inferred_units=inferred_units,
              inferred_load_order_matches_manifest=loaded_units == expected_units,
              caught_errors=len(re.findall(r'(?m)^; caught ERROR:',text)),
              caught_warnings=len(re.findall(r'(?m)^; caught WARNING:',text)),
              caught_style_warnings=len(re.findall(r'(?m)^; caught STYLE-WARNING:',text)),
              warning_notices=len(re.findall(r'(?m)^(?:WARNING:|STYLE-WARNING:)',text)),
              code_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in [ROOT/'holai.asd', ROOT/'holai/all.lisp',
                                     ROOT/'holai/generated/package-systems.sexp',
                                     *(ROOT/'ml2cl').glob('*.ml'),
                                     *(ROOT/name for name in expected_units if name != 'holai/all.lisp')]},
              audit_complete='DIAGNOSTICS_AUDIT_COMPLETE' in text, exit_code=proc.returncode,
              scope='5 runtime files, all 46 inferred production core files, and inferred holai/all entry; pinned upstream unchanged')
(report/'compile-diagnostics.json').write_text(json.dumps(result,indent=2)+'\n')
assert proc.returncode == 0 and 'DIAGNOSTICS_AUDIT_COMPLETE' in text, text[-4000:]
assert units == expected_units and len(set(units)) == 52, units
assert loaded_units == expected_units, loaded_units
assert inferred_units == expected_units[5:], inferred_units
assert not any(result[k] for k in ['caught_errors','caught_warnings','caught_style_warnings','warning_notices']), result
print('Cold diagnostics: 52 unique production files in manifest order; genuine inferred core/entry; zero errors, warnings and style warnings.')
