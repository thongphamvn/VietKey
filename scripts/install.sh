#!/bin/bash
# Build từ mã nguồn rồi cài VietKey vào ~/Library/Input Methods
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh   # luôn build lại để cài đúng code mới nhất
packaging/install.command build
