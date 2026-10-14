"""Cold compile/load and fresh FASL startup comparison against a supplied checkout.

Baseline must be the star-names/Trivia revision, not a patched runtime overlay.
Each backend uses a fresh independent ASDF output cache. Serial one-run evidence.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--candidate-only', action='store_true', help='Keep the prior baseline measurement and remeasure only a refined candidate')
args = parser.parse_args()
baseline = args.baseline.resolve()
if (baseline / 'runtime/pattern.lisp').exists() or 'trivia.trivial' not in (baseline / 'hol2cl-runtime.asd').read_text():
    raise SystemExit('Baseline must use the original Trivia runtime')
report = ROOT / 'reports'
report.mkdir(exist_ok=True)
compile_script = '''(require :asdf)
(defmethod asdf:perform :around ((op asdf:compile-op) (component asdf:cl-source-file))
  (let ((start (get-internal-real-time)) (cpu (get-internal-run-time)))
    (prog1 (call-next-method)
      (format t "~&COMPILE_METRIC ~a ~f ~f~%" (asdf:component-name component)
        (/ (- (get-internal-real-time) start) (float internal-time-units-per-second 1d0))
        (/ (- (get-internal-run-time) cpu) (float internal-time-units-per-second 1d0))))))
(load "tests/bootstrap.lisp")
(format t "~&COLD_COMPLETE~%")
'''

def child(cmd, cwd, env, log):
    start = time.perf_counter()
    with log.open('w') as stream:
        proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        # wait4 supplies peak RSS for this exact child, not cumulative allocation.
        deadline = start + 600
        while True:
            pid, status, usage = os.wait4(proc.pid, os.WNOHANG)
            if pid:
                proc.returncode = os.waitstatus_to_exitcode(status)
                break
            if time.perf_counter() > deadline:
                proc.kill()
                os.wait4(proc.pid, 0)
                raise RuntimeError('Measurement exceeded retained 600-second boundary')
            time.sleep(.1)
    wall = time.perf_counter() - start
    text = log.read_text(errors='replace')
    if proc.returncode:
        raise RuntimeError(text[-5000:])
    return dict(wall_seconds=wall, cpu_seconds=usage.ru_utime + usage.ru_stime,
                peak_rss_mib=usage.ru_maxrss / 1024), text

results = {}
if args.candidate_only:
    results['trivia'] = json.loads((report / 'pattern-performance.json').read_text())['trivia']
for mode, root in ([('structural', ROOT)] if args.candidate_only else [('trivia', baseline), ('structural', ROOT)]):
    cache = ROOT / '_build' / ('pattern-cache-' + mode)
    if cache.exists():
        raise SystemExit(f'Fresh cache required; already exists: {cache}')
    cache.mkdir(parents=True)
    env = dict(os.environ, XDG_CACHE_HOME=str(cache))
    source = ROOT / '_build' / ('pattern-compile-' + mode + '.lisp')
    source.write_text(compile_script)
    cold, text = child(['sbcl', '--dynamic-space-size', '2048', '--control-stack-size', '256',
                        '--noinform', '--non-interactive', '--load', str(source)], root, env,
                       report / ('pattern-' + mode + '-compile.txt'))
    assert 'COLD_COMPLETE' in text
    rows = [line.split() for line in text.splitlines() if line.startswith('COMPILE_METRIC ')]
    cold['compile_operation_wall_seconds_sum'] = sum(float(r[2]) for r in rows)
    cold['compile_operation_cpu_seconds_sum'] = sum(float(r[3]) for r in rows)
    cold['compiled_files'] = len(rows)
    core_names = {Path(p).stem for p in json.loads((root / 'vendor/CORE_FILES.json').read_text())}
    cold['core_compile_operation_wall_seconds_sum'] = sum(float(r[2]) for r in rows if r[1] in core_names)
    cold['core_compiled_files'] = sum(r[1] in core_names for r in rows)
    cold['fasl_bytes'] = sum(p.stat().st_size for p in cache.rglob('*.fasl'))
    cold['core_fasl_bytes'] = sum(p.stat().st_size for p in cache.rglob('*.fasl') if 'generated' in p.parts)
    cold['warnings'] = len(re.findall(r'(?m)^; caught WARNING:', text))
    cold['style_warnings'] = len(re.findall(r'(?m)^; caught STYLE-WARNING:', text))
    cold['rss_scope'] = 'Entire cold ASDF process including compilation and prerequisite/core initialization; not compile-only RSS'
    startup, text = child(['sbcl', '--control-stack-size', '256', '--noinform', '--disable-debugger',
                           '--script', 'tests/measure-startup.lisp'], root, env,
                          report / ('pattern-' + mode + '-startup.txt'))
    assert 'INITIAL_COUNTS 22 303 263 3' in text and 'CORE_INITIALIZATION_COMPLETE' in text
    rows = [line.split() for line in text.splitlines() if line.startswith('LOAD_METRIC ')]
    assert len(rows) == 46
    startup.update(core_wall_seconds=sum(float(r[2]) for r in rows),
                   core_cpu_seconds=sum(float(r[3]) for r in rows),
                   core_gc_seconds=sum(float(r[4]) for r in rows),
                   core_allocated_bytes=sum(int(r[5]) for r in rows),
                   compiled_source_files=0)
    results[mode] = dict(cold_compile_and_load=cold, fasl_startup=startup,
                         runtime_sha256={str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                         for p in (root / 'runtime').glob('*.lisp')})
    print(mode, 'compile ops', round(cold['compile_operation_wall_seconds_sum'], 3),
          'startup', round(startup['wall_seconds'], 3), flush=True)
results['method'] = dict(runs_per_backend=1, order=['trivia', 'structural'],
                         baseline_commit='1730c0299f7d677ba25be29d2dfbff0538fea354',
                         peak_metric='Linux wait4.ru_maxrss per child; KiB converted to MiB',
                         caveat='Single serial comparison, not repeated ABBA; cold peak includes initialization')
(report / 'pattern-performance.json').write_text(json.dumps(results, indent=2) + '\n')
