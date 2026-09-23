#!/usr/bin/env bash
# Run the WolfyPhone smoke test. Requires luajit (GMod's Lua 5.1 runtime).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v luajit >/dev/null 2>&1; then
    echo "luajit not found. Install it with: sudo apt-get install luajit" >&2
    exit 1
fi

luajit tests/smoke.lua
