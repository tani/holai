"""Sequential ABBA whole-core and AB microbenchmarks; no compilation in timing."""
from pathlib import Path
import argparse,json,os,statistics,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);args=p.parse_args()
ROOT=Path(__file__).resolve().parents[1];REPORT=ROOT/'reports'
def child(command,cwd,log_path,timeout=600):
 env=os.environ.copy();env.pop('HOL2CL_DEVELOPMENT_IMAGE',None)
 start=time.perf_counter()
 with log_path.open('w') as log:
  proc=subprocess.Popen(command,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT)
  while True:
   pid,status,usage=os.wait4(proc.pid,os.WNOHANG)
   if pid:
    proc.returncode=os.waitstatus_to_exitcode(status);break
   if time.perf_counter()-start>timeout:
    proc.kill();os.wait4(proc.pid,0);raise TimeoutError(str(log_path))
   time.sleep(.01)
 elapsed=time.perf_counter()-start
 if proc.returncode:raise RuntimeError(log_path.read_text()[-3000:])
 return elapsed,usage
results=[];indices={'baseline':0,'optional':0}
for mode in ['optional','baseline','baseline','optional']:
 indices[mode]+=1;index=indices[mode];directory=args.baseline if mode=='baseline' else ROOT
 log=REPORT/f'optional-{mode}-startup-run{index}.txt'
 elapsed,usage=child(['sbcl','--control-stack-size','256','--noinform','--disable-debugger','--script','tests/measure-startup.lisp'],directory,log)
 text=log.read_text();assert 'CORE_INITIALIZATION_COMPLETE' in text and 'INITIAL_COUNTS 22 303 263 3' in text
 rows=[s.split() for s in text.splitlines() if s.startswith('LOAD_METRIC ')];assert len(rows)==46
 row=dict(mode=mode,run=index,wall_seconds_start_to_exit=elapsed,user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,peak_rss_kib=usage.ru_maxrss,peak_rss_mib=usage.ru_maxrss/1024,load_wall_seconds_sum=sum(float(x[2]) for x in rows),load_cpu_seconds_sum=sum(float(x[3]) for x in rows),load_gc_seconds_sum=sum(float(x[4]) for x in rows),load_allocated_bytes_sum=sum(int(x[5]) for x in rows),fresh_process=True,restored_heap=False,compiled_source_files=0,loaded_core_files=46,initial_counts=[22,303,263,3])
 results.append(row);(REPORT/f'optional-{mode}-startup-run{index}.json').write_text(json.dumps(row,indent=2)+'\n');print(json.dumps(row),flush=True)
micro={}
for mode in ['baseline','optional']:
 directory=args.baseline if mode=='baseline' else ROOT;log=REPORT/f'optional-{mode}-micro.txt'
 child(['sbcl','--noinform','--disable-debugger','--script',str(ROOT/'tests/optional-benchmark.lisp')],directory,log,120)
 rows=[s.split() for s in log.read_text().splitlines() if s.startswith('ENTRY_BENCH ')];assert len(rows)==24
 micro[mode]={name:dict(median_cpu_seconds=statistics.median(float(x[4]) for x in rows if x[2]==name),median_allocated_bytes=statistics.median(int(x[5]) for x in rows if x[2]==name),repetitions=int(next(x[3] for x in rows if x[2]==name))) for name in sorted({x[2] for x in rows})}
summary=dict(runs=results,micro=micro,run_order=['optional','baseline','baseline','optional'],medians={mode:{key:statistics.median(x[key] for x in results if x['mode']==mode) for key in ['wall_seconds_start_to_exit','peak_rss_mib','load_cpu_seconds_sum','load_gc_seconds_sum','load_allocated_bytes_sum']} for mode in ['baseline','optional']},peak_metric='Linux per-child wait4.ru_maxrss in KiB',limitation='Two fresh processes each; independent roots/caches; not statistically conclusive.')
(REPORT/'optional-entry.json').write_text(json.dumps(summary,indent=2)+'\n');print('MEDIANS',json.dumps(summary['medians']),flush=True)
