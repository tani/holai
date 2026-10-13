#!/usr/bin/env bash
set -euo pipefail
hol2cl_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd -- "$hol2cl_root"
exec sbcl --control-stack-size 256 --noinform --load tests/bootstrap.lisp "$@"
