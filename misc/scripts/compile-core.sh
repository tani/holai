#!/usr/bin/env bash
set -euo pipefail
holai_root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
cd -- "$holai_root"
exec sbcl --dynamic-space-size 2048 --control-stack-size 256 --noinform --non-interactive --load holai/tests/bootstrap.lisp
