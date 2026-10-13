"""Compile unchanged core with ocamlopt; measure three fresh initializations."""
from pathlib import Path
import hashlib,json,os,re,shlex,statistics,subprocess,time,sys,resource
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'tests'))
from run import initialization_messages
BUILD=ROOT/'_build/native-startup'; BUILD.mkdir(parents=True,exist_ok=True)
REPORT=ROOT/'reports'
pins=json.loads((ROOT/'vendor/SOURCES.json').read_text())['input_sha256']
for n,d in pins.items(): assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==d,n
files=json.loads((ROOT/'vendor/CORE_FILES.json').read_text())
source='let hol2cl_init_wall = Unix.gettimeofday ();;\nlet hol2cl_init_cpu = Sys.time ();;\n'
source+='let needs _ = ();;\nlet float_sqrt = sqrt;;\nunset_jrh_lexer;;\n'
source+=(ROOT/'vendor/hol-light/bignum_num.ml').read_text()+'\nset_jrh_lexer;;\n'
source+='\n'.join((ROOT/'vendor/hol-light'/n).read_text() for n in files)
source+='''
let () =
  Format.pp_print_flush Format.std_formatter ();
  let elapsed_wall = Unix.gettimeofday () -. hol2cl_init_wall in
  let elapsed_cpu = Sys.time () -. hol2cl_init_cpu in
  print_endline "__HOL2CL_INITIALIZATION_COMPLETE__";
  Printf.printf "INIT_METRIC %.9f %.9f\\n" elapsed_wall elapsed_cpu;
  Printf.printf "INITIAL_COUNTS %d %d %d %d\\n"
    (List.length(types())) (List.length(constants()))
    (List.length(definitions())) (List.length(axioms()));
  flush stdout;;
'''
ml=BUILD/'native_startup.ml';ml.write_text(source)
lib=os.environ.get('CAMLPLIB') or subprocess.check_output(['camlp5r','-where'],text=True).strip()
pp=shlex.join(['camlp5r','-I',lib,'-I',str(ROOT/'_build'),'pa_j.cmo'])
exe=BUILD/'native-startup'
cmd=['ocamlopt','-w','-a','-pp',pp,'unix.cmxa','nums.cmxa',str(ml),'-o',str(exe)]
started=time.perf_counter()
def compiler_stack():
 resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
with (REPORT/'ocamlopt-build.txt').open('w') as log:
 subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120,preexec_fn=compiler_stack)
compile_seconds=time.perf_counter()-started
print('Native executable built in',round(compile_seconds,3),'seconds; timing excludes compilation.',flush=True)
runs=[]
expected=initialization_messages((REPORT/'ocaml-initialization.txt').read_text())
for i in range(1,4):
 log_path=REPORT/f'ocamlopt-startup-run{i}.txt'
 start=time.perf_counter()
 with log_path.open('w') as log:
  proc=subprocess.Popen([str(exe)],stdout=log,stderr=subprocess.STDOUT)
  while True:
   pid,status,usage=os.wait4(proc.pid,os.WNOHANG)
   if pid:
    proc.returncode=os.waitstatus_to_exitcode(status);break
   if time.perf_counter()-start>600:
    proc.kill();os.wait4(proc.pid,0);raise TimeoutError('Native core initialization')
   time.sleep(0.01)
 elapsed=time.perf_counter()-start
 assert proc.returncode==0,log_path.read_text()[-3000:]
 text=log_path.read_text();init,sep,metrics=text.partition('__HOL2CL_INITIALIZATION_COMPLETE__\n')
 assert sep and 'INITIAL_COUNTS 22 303 263 3' in metrics
 assert initialization_messages(init)==expected,'Unexpected native initialization message changes'
 match=re.search(r'INIT_METRIC ([\d.]+) ([\d.]+)',metrics);assert match
 row=dict(run=i,initialization_wall_seconds=float(match[1]),initialization_cpu_seconds=float(match[2]),wall_seconds_start_to_exit=elapsed,user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,peak_rss_kib=usage.ru_maxrss,peak_rss_mib=usage.ru_maxrss/1024,initial_counts=[22,303,263,3],normalized_initialization_matches=True)
 runs.append(row);print(json.dumps(row),flush=True)
result=dict(compiler=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),compiler_command=cmd,compiler_flags='default ocamlopt optimization; -w -a suppresses warnings',compiled_source_files_during_timed_run=0,core_files=files,source_pins_unchanged=True,compile_seconds=compile_seconds,compiler_stack_mib=64,source_sha256=hashlib.sha256(source.encode()).hexdigest(),runs=runs,medians={k:statistics.median(x[k] for x in runs) for k in ['initialization_wall_seconds','initialization_cpu_seconds','wall_seconds_start_to_exit','peak_rss_mib']},peak_metric='Linux wait4.ru_maxrss, KiB, per child',sbcl_historical=json.loads((REPORT/'history/tuple-list-startup.json').read_text()),comparison_limit='SBCL is a historical single-run measurement, not a contemporaneous paired experiment.')
(REPORT/'ocamlopt-startup.json').write_text(json.dumps(result,indent=2)+'\n')
print('MEDIANS',json.dumps(result['medians']),flush=True)
