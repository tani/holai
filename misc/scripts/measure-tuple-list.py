"""Fresh FASL-only list-tuple startup: time, allocation and per-child peak RSS."""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
if not sys.platform.startswith('linux'):
    raise SystemExit('Linux wait4.ru_maxrss (KiB) is required')
build = ROOT / '_build'
build.mkdir(exist_ok=True)
log_path = ROOT / 'misc/reports/tuple-list-startup.txt'
env = os.environ.copy()
env.pop('HOL2CL_DEVELOPMENT_IMAGE', None);env.pop('HOLAI_DEVELOPMENT_IMAGE',None)
start = time.perf_counter()
with log_path.open('w') as log:
    child = subprocess.Popen(['sbcl', '--control-stack-size', '256', '--noinform',
                              '--disable-debugger', '--script', 'holai/tests/measure-startup.lisp'],
                             cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    while True:
        pid, status, usage = os.wait4(child.pid, os.WNOHANG)
        if pid:
            child.returncode = os.waitstatus_to_exitcode(status)
            break
        if time.perf_counter()-start > 600:
            child.kill()
            os.wait4(child.pid, 0)
            child.returncode = -9
            raise TimeoutError('tuple-list startup')
        time.sleep(0.25)
elapsed = time.perf_counter()-start
text = log_path.read_text()
if child.returncode:
    raise RuntimeError(text[-3000:])
assert 'CORE_INITIALIZATION_COMPLETE' in text and 'INITIAL_COUNTS 22 303 263 3' in text
rows = [line.split() for line in text.splitlines() if line.startswith('LOAD_METRIC ')]
assert len(rows) == 46
result = dict(variant='defunc-list-tuples', fresh_process=True, restored_heap=False,
              compiled_source_files=0, loaded_core_files=46,
              wall_seconds_start_to_exit=round(elapsed,3),
              user_seconds=round(usage.ru_utime,3), system_seconds=round(usage.ru_stime,3),
              peak_rss_kib=usage.ru_maxrss, peak_rss_mib=round(usage.ru_maxrss/1024,3),
              peak_metric='Linux wait4.ru_maxrss, KiB, per child',
              load_wall_seconds_sum=round(sum(float(r[2]) for r in rows),3),
              load_cpu_seconds_sum=round(sum(float(r[3]) for r in rows),3),
              load_gc_seconds_sum=round(sum(float(r[4]) for r in rows),3),
              load_allocated_bytes_sum=sum(int(r[5]) for r in rows),
              initial_counts=dict(types=22,constants=303,definitions=263,axioms=3),
              source_files=[dict(file=r[1]+'.ml', wall_seconds=float(r[2]),cpu_seconds=float(r[3]),
                                 gc_seconds=float(r[4]),allocated_bytes=int(r[5])) for r in rows])
(ROOT/'misc/reports/tuple-list-startup.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='source_files'}),flush=True)
