"""Prepare an independent old-entry tree and compile its FASLs before timing."""
from pathlib import Path
import argparse,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);args=p.parse_args()
root=Path(__file__).resolve().parents[1];dest=args.output.resolve()
if (root/'runtime/pattern.lisp').exists():raise SystemExit('Historical OPTIONAL experiment: run from commit 1730c0299f7d677ba25be29d2dfbff0538fea354 (Trivia backend), not the structural-match release')
if dest==root or dest.is_relative_to(root) or root.is_relative_to(dest):raise SystemExit('Choose a separate baseline directory')
if dest.exists():raise SystemExit('Output directory already exists; choose an empty new destination')
shutil.copytree(root,dest,ignore=shutil.ignore_patterns('_build','bin','dist','__pycache__','.git','*.fasl','*.cmo','*.cmi'))
shutil.copyfile(root/'tests/optional-baseline-core.lisp',dest/'runtime/core.lisp')
with (dest/'baseline-compilation.txt').open('w') as log:
 subprocess.run(['sbcl','--dynamic-space-size','2048','--control-stack-size','256','--noinform','--non-interactive','--load','tests/bootstrap.lisp'],cwd=dest,stdout=log,stderr=subprocess.STDOUT,timeout=600,check=True)
print('Baseline FASLs prepared:',dest)
