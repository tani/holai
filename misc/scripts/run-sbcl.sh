#!/usr/bin/env bash
set -euo pipefail
holai_root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
cd -- "$holai_root"
exec sbcl --control-stack-size 256 --noinform --load holai/tests/bootstrap.lisp "$@"
