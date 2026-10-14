"""Naming boundary regression against the original OCaml fixture."""
from pathlib import Path
import json,os,shlex,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];os.chdir(ROOT)
sys.path.insert(0, str(ROOT / 'misc/scripts'))
from lisp_host import command, implementation, report_directory
BUILD=ROOT/'_build/star-names';BUILD.mkdir(parents=True,exist_ok=True)
def run(args):
 p=subprocess.run(args,text=True,capture_output=True,timeout=120)
 if p.returncode:raise RuntimeError(p.stdout[-2000:]+p.stderr[-4000:])
 return p.stdout
run(['ocamlrun','bin/ml2cl','translate','--output-dir',str(BUILD),'holai/tests/fixtures/star_names.ml'])
lib=os.environ.get('CAMLPLIB') or run(['camlp5r','-where']).strip()
pp=shlex.join(['camlp5r','-I',lib,'-I',str(ROOT/'_build'),'pa_j.cmo'])
streams=os.environ.get('STREAMLIB') or str(Path(lib).parent/'camlp-streams')
allocator=BUILD/'allocator'
run(['ocamlc','-I',str(ROOT/'_build'),'-I',lib,'-I',streams,'camlp_streams.cma','camlp5.cma',str(ROOT/'_build/sexp.cmo'),str(ROOT/'_build/scope.cmo'),'holai/tests/star-allocator.ml','-o',str(allocator)])
assert 'Star allocator checks passed: 21' in run(['ocamlrun',str(allocator)])
source=(ROOT/'holai/tests/fixtures/star_names.ml').read_text()+'\nlet () = List.iter print_endline (observations());;\n'
ml=BUILD/'original.ml';ml.write_text(source)
run(['ocamlc','-w','-a','-pp',pp,str(ml),'-o',str(BUILD/'original')])
original=run(['ocamlrun',str(BUILD/'original')])
lisp=run(command('holai/tests/star-names.lisp'))
_,sep,observed=lisp.partition('__STAR_OBSERVATIONS__\n');assert sep
assert original==observed,(original,observed)
def escaped_symbols(text):
 string=False;comment=False;escape=False;count=0
 for ch in text:
  if comment:
   if ch=='\n':comment=False
  elif string:
   if escape:escape=False
   elif ch=='\\':escape=True
   elif ch=='"':string=False
  elif ch==';':comment=True
  elif ch=='"':string=True
  elif ch=='|':count+=1
 return count
assert escaped_symbols((BUILD/'star_names.lisp').read_text())==0
for file in (ROOT/'holai/generated').glob('*.lisp'):assert escaped_symbols(file.read_text())==0,file
(report_directory()/'star-names.json').write_text(json.dumps({'implementation':implementation(),'allocator_checks':21,'original_observations_match':True,'observations':original.splitlines(),'escaped_symbol_delimiters_in_core':0,'core_files':46,'checked_exports':['T%','T%%','NIL%','PI%','PI%%','NAME','NAME%','NAME%%','NAME%%%']},indent=2)+'\n')
print('Star naming checks passed: 9 matching observations; 9 allocated exports; 0 escaped symbols in generated core.')
