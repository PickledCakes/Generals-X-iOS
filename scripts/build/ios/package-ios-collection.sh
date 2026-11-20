#!/bin/bash
# GeneralsX @build Codex 20/11/2026 Public entry point stages directly from user-supplied installations.
set -euo pipefail
GX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${GX_SCRIPT_DIR}/build_collection.py" "$@"
