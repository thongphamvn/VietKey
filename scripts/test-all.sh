#!/bin/bash
# Chạy toàn bộ test và lưu kết quả vào test-results/:
#   unit.txt        engine + app giả lập            (swift run VietTests)
#   installer.txt   trình cài đặt trong DMG         (scripts/installertest.sh)
#   realtest.txt    gõ phím thật trong app thật     (scripts/realtest.swift)
#   SUMMARY.md      tóm tắt
# Bỏ qua phần cần Accessibility bằng: scripts/test-all.sh --unit-only
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=test-results
mkdir -p "$OUT"

header() {
    echo "# $1"
    echo "# Ngày:    $(date '+%Y-%m-%d %H:%M %Z')"
    echo "# Commit:  $(git rev-parse --short HEAD 2>/dev/null || echo '?')$(git diff --quiet HEAD 2>/dev/null || echo ' (có thay đổi chưa commit)')"
    echo "# macOS:   $(sw_vers -productVersion) ($(uname -m))"
    echo "# Swift:   $(swift --version 2>/dev/null | head -1)"
    echo
}
# run <tên> <file> <lệnh...>: chạy, ghi output (bỏ log build), trả về dòng tổng kết
declare -a ROWS
run() {
    local name=$1 file=$2; shift 2
    echo "▸ $name"
    { header "$name"; "$@" 2>&1 | grep -v -E '^\[[0-9]+/[0-9]+\]|^Building|^Build complete|^Compiling|^Write|ld: warning|replacing existing signature'; } > "$OUT/$file"
    local summary; summary=$(grep -E '^(✔|✘) [0-9]+/[0-9]+|passed, [0-9]+ failed' "$OUT/$file" | tail -1)
    echo "  ${summary:-không có kết quả}"
    ROWS+=("| $name | ${summary:-không có kết quả} | [$file]($file) |")
}

run "Unit test: engine và app giả lập" unit.txt swift run VietTests
if [ "${1:-}" != "--unit-only" ]; then
    [ -n "$(ls dist/VietKey-*.dmg 2>/dev/null)" ] || scripts/package.sh >/dev/null 2>&1
    run "Trình cài đặt trong DMG" installer.txt scripts/installertest.sh
    run "Gõ phím thật trong app" realtest.txt swift scripts/realtest.swift
fi

{
    echo "# Kết quả test VietKey"
    echo
    header "" | sed -n 's/^# \([^:]*\): *\(.*\)$/- **\1:** \2/p'
    echo
    echo "| Bộ test | Kết quả | Chi tiết |"
    echo "|---|---|---|"
    printf '%s\n' "${ROWS[@]}"
} > "$OUT/SUMMARY.md"
echo; cat "$OUT/SUMMARY.md"
