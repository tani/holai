"""Audit all production compilation diagnostics from a fresh ASDF cache."""
from pathlib import Path
import hashlib, json, os, re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[2]
report = ROOT / 'misc/reports'
with tempfile.TemporaryDirectory(prefix='percent-diagnostics-', dir=ROOT/'_build') as work:
    work = Path(work)
    driver = work/'audit.lisp'
    driver.write_text('''(require :asdf)
(defparameter cl-user::*audit-stream* *error-output*)
(defmethod asdf:perform :around ((op asdf:compile-op) (component asdf:cl-source-file))
  (prog1 (call-next-method)
    (format cl-user::*audit-stream* "~&COMPILED_UNIT ~a~%" (asdf:component-name component))))
(load "holai/tests/bootstrap.lisp")
(format cl-user::*audit-stream* "~&DIAGNOSTICS_AUDIT_COMPLETE~%")
''')
    env = dict(os.environ, XDG_CACHE_HOME=str(work/'cache'))
    proc = subprocess.run(['sbcl','--dynamic-space-size','2048','--control-stack-size','256',
                           '--noinform','--non-interactive','--load',str(driver)],cwd=ROOT,
                          env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=600)
(report/'compile-diagnostics.txt').write_text(proc.stdout)
text = (report/'compile-diagnostics.txt').read_text()
units = re.findall(r'(?m)^COMPILED_UNIT (.+)$', text)
result = dict(fresh_asdf_cache=True, compiled_units=units, compiled_unit_count=len(units),
              caught_errors=len(re.findall(r'(?m)^; caught ERROR:',text)),
              caught_warnings=len(re.findall(r'(?m)^; caught WARNING:',text)),
              caught_style_warnings=len(re.findall(r'(?m)^; caught STYLE-WARNING:',text)),
              warning_notices=len(re.findall(r'(?m)^(?:WARNING:|STYLE-WARNING:)',text)),
              code_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in [ROOT/'holai-runtime.asd', *(ROOT/'ml2cl').glob('*.ml'),
                                     *(ROOT/'holai/runtime').glob('*.lisp'), *(ROOT/'holai/generated').glob('*.lisp')]},
              audit_complete='DIAGNOSTICS_AUDIT_COMPLETE' in text, exit_code=proc.returncode, scope='5 runtime files and all 46 production core files; pinned upstream unchanged')
(report/'compile-diagnostics.json').write_text(json.dumps(result,indent=2)+'\n')
assert proc.returncode == 0 and 'DIAGNOSTICS_AUDIT_COMPLETE' in text, text[-4000:]
assert len(units)==51, units
assert not any(result[k] for k in ['caught_errors','caught_warnings','caught_style_warnings','warning_notices']), result
print('Cold diagnostics: 51 production files; zero errors, warnings and style warnings.')
