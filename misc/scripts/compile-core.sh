#!/usr/bin/env bash
set -euo pipefail
holai_root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
cd -- "$holai_root"
exec "$holai_root/misc/scripts/run-lisp.sh" --batch
