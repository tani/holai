#!/usr/bin/env bash
set -euo pipefail
hol2cl_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd -- "$hol2cl_root"
exec sbcl --dynamic-space-size 2048 --control-stack-size 256 --noinform --non-interactive --load tests/bootstrap.lisp
