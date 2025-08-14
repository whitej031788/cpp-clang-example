#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

LLVM_ARGS=()

choose_prefix() {
	local pfx="$1"
	if [[ -n "$pfx" && -d "$pfx" && -d "$pfx/lib/cmake/llvm" && -x "$pfx/bin/clang-tidy" ]]; then
		echo "$pfx"
	fi
}

BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
	BREW_PREFIX="$(brew --prefix llvm 2>/dev/null || true)"
fi

CANDIDATES=(
	"$BREW_PREFIX"
	"/opt/homebrew/opt/llvm"
	"/usr/local/opt/llvm"
	"$HOME/brew/opt/llvm"
	"/usr/local/llvm"
)

for c in "${CANDIDATES[@]}"; do
	pfx="$(choose_prefix "$c")" || true
	if [[ -n "${pfx:-}" ]]; then
		LLVM_ARGS+=("-DLLVM_DIR=$pfx/lib/cmake/llvm")
		LLVM_ARGS+=("-DClang_DIR=$pfx/lib/cmake/clang")
		echo "Using LLVM at $pfx"
		# Prefer this clang/clang++ when compiling
		export CC="$pfx/bin/clang"
		export CXX="$pfx/bin/clang++"
		break
	fi
done

if (( ${#LLVM_ARGS[@]:-0} > 0 )); then
	cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo "${LLVM_ARGS[@]}" ..
else
	echo "Warning: LLVM not auto-detected. If configuration fails, pass LLVM_DIR and Clang_DIR manually." >&2
	cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
fi
cmake --build . -- -j$(sysctl -n hw.ncpu 2>/dev/null || nproc || echo 4) 