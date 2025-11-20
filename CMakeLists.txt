cmake_minimum_required(VERSION 3.16)

project(cpp_clang_example LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/third_party/cmake-sbom/cmake")

include(git_version)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Generate compile_commands.json for tooling
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(leaky
	src/main.cpp
)

# Install the executable to make it part of install artifacts
install(TARGETS leaky
	RUNTIME DESTINATION bin
)

# Prepare SBOM generation
include(sbom)
sbom_generate(
	SUPPLIER "Organization: cpp-clang-example"
	SUPPLIER_URL "https://example.invalid"
)

# On macOS with Homebrew LLVM, prefer its toolchain if available
if(APPLE)
	# Let users opt-in by setting LLVM_DIR/Clang_DIR when configuring the plugin
	message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
endif()

add_subdirectory(tidy-plugin) 

# Add targets to SBOM and finalize
sbom_add(TARGET leaky)
sbom_add(TARGET TidyLeakCheck)
sbom_finalize()