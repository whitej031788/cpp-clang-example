#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
OUT_DIR="$ROOT_DIR/out"
mkdir -p "$OUT_DIR"

# Try to infer LLVM prefix and clang version from CMakeCache
LLVM_PREFIX=""
CLANG_VER=""
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
	LLVM_DIR_LINE=$(grep -E '^LLVM_DIR:' "$BUILD_DIR/CMakeCache.txt" || true)
	if [[ -n "$LLVM_DIR_LINE" ]]; then
		LLVM_DIR=${LLVM_DIR_LINE#*=}
		LLVM_PREFIX=$(cd "$LLVM_DIR/../.." && pwd)
	fi
	CLANG_DIR_LINE=$(grep -E '^Clang_DIR:' "$BUILD_DIR/CMakeCache.txt" || true)
	if [[ -n "$CLANG_DIR_LINE" ]]; then
		CLANG_DIR=${CLANG_DIR_LINE#*=}
		CLANG_BASENAME=$(basename "$CLANG_DIR" || true)
		CLANG_VER=${CLANG_BASENAME#clang-}
	fi
fi

# Select clang-tidy to match the toolchain version first
CLANG_TIDY=""
if [[ -n "${CLANG_VER:-}" ]] && command -v clang-tidy-${CLANG_VER} >/dev/null 2>&1; then
	CLANG_TIDY=$(command -v clang-tidy-${CLANG_VER})
elif [[ -n "${LLVM_PREFIX:-}" && -x "$LLVM_PREFIX/bin/clang-tidy" ]]; then
	CLANG_TIDY="$LLVM_PREFIX/bin/clang-tidy"
elif command -v clang-tidy >/dev/null 2>&1; then
	CLANG_TIDY="$(command -v clang-tidy)"
else
	for ver in 20 19 18 17; do
		if command -v clang-tidy-$ver >/dev/null 2>&1; then CLANG_TIDY=$(command -v clang-tidy-$ver); break; fi
	 done
fi

if [[ -z "$CLANG_TIDY" ]]; then
	echo "clang-tidy not found" >&2; exit 1
fi

echo "Using clang-tidy: $CLANG_TIDY"
$CLANG_TIDY --version || true

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