#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
OUT_DIR="$ROOT_DIR/out"
mkdir -p "$OUT_DIR"

# Try to infer LLVM prefix from CMakeCache
LLVM_PREFIX=""
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
	LLVM_DIR_LINE=$(grep -E '^LLVM_DIR:' "$BUILD_DIR/CMakeCache.txt" || true)
	if [[ -n "$LLVM_DIR_LINE" ]]; then
		LLVM_DIR=${LLVM_DIR_LINE#*=}
		LLVM_PREFIX=$(cd "$LLVM_DIR/../.." && pwd)
	fi
fi

CLANG_TIDY="clang-tidy"
if [[ -n "${LLVM_PREFIX:-}" && -x "$LLVM_PREFIX/bin/clang-tidy" ]]; then
	CLANG_TIDY="$LLVM_PREFIX/bin/clang-tidy"
elif command -v clang-tidy >/dev/null 2>&1; then
	CLANG_TIDY="$(command -v clang-tidy)"
elif [[ -x "/opt/homebrew/opt/llvm/bin/clang-tidy" ]]; then
	CLANG_TIDY="/opt/homebrew/opt/llvm/bin/clang-tidy"
elif [[ -x "/Users/$(whoami)/brew/opt/llvm/bin/clang-tidy" ]]; then
	CLANG_TIDY="/Users/$(whoami)/brew/opt/llvm/bin/clang-tidy"
fi

echo "Using clang-tidy: $CLANG_TIDY"

# Detect plugin path with either .so or .dylib
PLUGIN_PATH=""
if [[ -f "$BUILD_DIR/tidy-plugin/TidyLeakCheck.so" ]]; then
	PLUGIN_PATH="$BUILD_DIR/tidy-plugin/TidyLeakCheck.so"
elif [[ -f "$BUILD_DIR/tidy-plugin/TidyLeakCheck.dylib" ]]; then
	PLUGIN_PATH="$BUILD_DIR/tidy-plugin/TidyLeakCheck.dylib"
fi

if [[ -z "$PLUGIN_PATH" ]]; then
	echo "Plugin not found in $BUILD_DIR/tidy-plugin (expected .so or .dylib). Did you run scripts/build.sh?" >&2
	exit 1
fi

if [[ ! -f "$BUILD_DIR/compile_commands.json" ]]; then
	echo "compile_commands.json not found in $BUILD_DIR. Try rebuilding." >&2
	exit 1
fi

# Extra args for macOS SDK/libc++ detection by upstream clang-tidy
EXTRA_ARGS=()
if [[ "$(uname -s)" == "Darwin" ]]; then
	SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || true)"
	CLT_ROOT="$(xcrun --print-path 2>/dev/null || true)"
	if [[ -n "$SDK_PATH" ]]; then
		EXTRA_ARGS+=("--extra-arg=-isysroot$SDK_PATH")
	fi
	if [[ -n "$CLT_ROOT" && -d "$CLT_ROOT/usr/include/c++/v1" ]]; then
		EXTRA_ARGS+=("--extra-arg=-I$CLT_ROOT/usr/include/c++/v1")
	fi
	EXTRA_ARGS+=("--extra-arg=-stdlib=libc++")
	EXTRA_ARGS+=("--extra-arg=-std=c++17")
fi

TIDY_TXT="$OUT_DIR/tidy.txt"
"$CLANG_TIDY" -p "$BUILD_DIR" -load "$PLUGIN_PATH" "${EXTRA_ARGS[@]}" "$ROOT_DIR/src/main.cpp" 2>&1 | tee "$TIDY_TXT"

python3 "$ROOT_DIR/scripts/tidy_to_sarif.py" "$TIDY_TXT" "$OUT_DIR/tidy.sarif"
echo "SARIF written to $OUT_DIR/tidy.sarif" 