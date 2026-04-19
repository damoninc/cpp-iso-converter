#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT_DIR/build" --config Release

EXE="$ROOT_DIR/build/ciso2iso"
if [[ ! -x "$EXE" ]]; then
  echo "Executable not produced at $EXE" >&2
  exit 1
fi

set +e
USAGE_OUTPUT="$($EXE 2>&1)"
USAGE_EXIT=$?
set -e

if [[ $USAGE_EXIT -eq 0 ]]; then
  echo "Expected usage invocation to fail" >&2
  exit 1
fi

if [[ "$USAGE_OUTPUT" != *"Usage: ciso2iso <input.ciso> <output.iso>"* ]]; then
  echo "Usage output did not match expected text" >&2
  echo "$USAGE_OUTPUT" >&2
  exit 1
fi

BAD_INPUT="$ROOT_DIR/tests/invalid_magic.cso"
BAD_OUTPUT="$ROOT_DIR/tests/invalid_magic.iso"
rm -f "$BAD_OUTPUT"

set +e
INVALID_OUTPUT="$($EXE "$BAD_INPUT" "$BAD_OUTPUT" 2>&1)"
INVALID_EXIT=$?
set -e

if [[ $INVALID_EXIT -eq 0 ]]; then
  echo "Expected invalid fixture to fail" >&2
  exit 1
fi

if [[ "$INVALID_OUTPUT" != *"invalid CISO header magic"* ]]; then
  echo "Invalid fixture did not report the expected header error" >&2
  echo "$INVALID_OUTPUT" >&2
  exit 1
fi

echo "Smoke test passed"
