#!/bin/bash
# GeneralsX @build Codex 20/11/2026 Interactive entry point; no AI or commercial assets required in source.
set -euo pipefail
GX_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${GX_PROJECT_DIR}/scripts/build/ios/build_collection.py" "$@"
