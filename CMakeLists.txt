cmake_minimum_required(VERSION 3.16)

project(cpp_clang_example LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Generate compile_commands.json for tooling
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(leaky
	src/main.cpp
)

# On macOS with Homebrew LLVM, prefer its toolchain if available
if(APPLE)
	# Let users opt-in by setting LLVM_DIR/Clang_DIR when configuring the plugin
	message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
endif()

add_subdirectory(tidy-plugin) 