#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

LLVM_ARGS=()

choose_prefix() {
	local pfx="$1"
	if [[ -n "$pfx" && -d "$pfx" && -d "$pfx/lib/cmake/llvm" ]]; then
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

# Linux system LLVM locations (Ubuntu/Debian)
if [[ -d /usr/lib ]]; then
	mapfile -t SYS_LLVM_CM_DIRS < <(ls -d /usr/lib/llvm-*/lib/cmake/llvm 2>/dev/null | sort -V)
	if (( ${#SYS_LLVM_CM_DIRS[@]} > 0 )); then
		LAST="${SYS_LLVM_CM_DIRS[-1]}"
		SYS_PFX="$(cd "$LAST/../.." && pwd)"
		CANDIDATES+=("$SYS_PFX")
	fi
fi

for c in "${CANDIDATES[@]}"; do
	pfx="$(choose_prefix "$c")" || true
	if [[ -n "${pfx:-}" ]]; then
		LLVM_ARGS+=("-DLLVM_DIR=$pfx/lib/cmake/llvm")
		# Clang cmake dir can be either under llvm or system cmake path
		if [[ -d "$pfx/lib/cmake/clang" ]]; then
			LLVM_ARGS+=("-DClang_DIR=$pfx/lib/cmake/clang")
		elif [[ -d "/usr/lib/cmake/clang-17" ]]; then
			LLVM_ARGS+=("-DClang_DIR=/usr/lib/cmake/clang-17")
		fi
		echo "Using LLVM at $pfx"
		# Prefer versioned clang if available on Linux, else unversioned
		if command -v clang-17 >/dev/null 2>&1; then export CC=clang-17 CXX=clang++-17; 
		elif command -v clang >/dev/null 2>&1; then export CC=clang CXX=clang++;
		fi
		break
	fi
done

if [[ ${#LLVM_ARGS[@]} -gt 0 ]]; then
	cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo "${LLVM_ARGS[@]}" ..
else
	echo "Warning: LLVM not auto-detected. If configuration fails, pass LLVM_DIR and Clang_DIR manually." >&2
	cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
fi
cmake --build . -- -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 