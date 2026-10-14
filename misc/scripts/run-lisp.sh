#!/usr/bin/env bash
set -euo pipefail
holai_root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
cd -- "$holai_root"
exec python3 misc/scripts/lisp_host.py "$@"
