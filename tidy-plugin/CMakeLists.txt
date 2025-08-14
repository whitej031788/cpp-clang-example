cmake_minimum_required(VERSION 3.16)

project(tidy_leak_plugin LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Allow user to point to Homebrew LLVM easily
if(NOT LLVM_DIR AND APPLE)
	# Try Homebrew default prefix
	execute_process(COMMAND /bin/zsh -lc "brew --prefix llvm" OUTPUT_VARIABLE HOMEBREW_LLVM_PREFIX OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
	if(HOMEBREW_LLVM_PREFIX)
		set(LLVM_DIR "${HOMEBREW_LLVM_PREFIX}/lib/cmake/llvm" CACHE PATH "Path to LLVM CMake directory")
		set(Clang_DIR "${HOMEBREW_LLVM_PREFIX}/lib/cmake/clang" CACHE PATH "Path to Clang CMake directory")
	endif()
endif()

find_package(LLVM REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} at: ${LLVM_DIR}")
message(STATUS "Found Clang at: ${Clang_DIR}")

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS} ${CLANG_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_library(TidyLeakCheck MODULE
	CallPairCheck.cpp
	CallPairCheck.h
	PersistentDataCheck.cpp
	PersistentDataCheck.h
	TidyModule.cpp
)

# Avoid 'lib' prefix so -load can find it as built path
set_target_properties(TidyLeakCheck PROPERTIES PREFIX "")

# Required tidy and clang libs; this list is stable across recent LLVM versions
# Adjust if link errors occur on your platform

target_link_libraries(TidyLeakCheck
	PRIVATE
	clangTidy
	clangTidyUtils
	clangAST
	clangASTMatchers
	clangAnalysis
	clangBasic
	clangFrontend
	clangRewrite
	clangSerialization
	clangTooling
) 