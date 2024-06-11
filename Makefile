.PHONY: build setup run-profile run test run-hdp format-cairo run-pie get-program-hash clean ci-local test-full fuzz-tx fuzz-header

# Variables
VENV_PATH ?= venv
BUILD_DIR := build/compiled_cairo_files
CAIRO_FILES := $(shell find ./tests/cairo_programs -name "*.cairo")

# Build Targets
build: clean
	@echo "Building project..."
	./tools/make/build.sh
	./tools/make/build_cairo1.sh
	@echo "Build complete."

# Setup environment
setup:
	@echo "Setting up the environment..."
	./tools/make/install_cairo1_run.sh
	./tools/make/build_cairo1.sh
	./tools/make/setup.sh $(VENV_PATH)
	@echo "Setup complete."

# Run and Test Targets
run-profile:
	@echo "Selecting, compiling, running, and profiling a Cairo file..."
	./tools/make/launch_cairo_files.py -profile
	@echo "Profile run complete."

run:
	@echo "Selecting, compiling, and running a Cairo file..."
	@echo "Total number of steps will be shown at the end of the run."
	./tools/make/launch_cairo_files.py
	@echo "Run complete."

test:
	@echo "Running all tests in tests/cairo_programs..."
	./tools/make/launch_cairo_files.py -test
	@echo "All tests completed."

run-hdp:
	@echo "Compiling and running HDP..."
	@echo "Total number of steps will be shown at the end of the run."
	./tools/make/launch_cairo_files.py -run_hdp
	@echo "HDP run complete."

format-cairo:
	@echo "Formatting all .cairo files..."
	./tools/make/format_cairo_files.sh
	@echo "Formatting complete."

run-pie:
	@echo "Selecting, compiling, and running a Cairo file..."
	@echo "Outputting a Cairo PIE object."
	@echo "Total number of steps will be shown at the end of the run."
	./tools/make/launch_cairo_files.py -pie
	@echo "Run PIE complete."

get-program-hash:
	@echo "Getting hdp.cairo program's hash..."
	cairo-compile ./src/hdp.cairo --output $(BUILD_DIR)/hdp.json
	cairo-hash-program --program $(BUILD_DIR)/hdp.json
	@echo "Program hash retrieved."

# Cleanup Target
clean:
	@echo "Cleaning up build artifacts..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	@echo "Cleanup complete."

# CI and Testing Targets
ci-local:
	@echo "Running CI locally..."
	./tools/make/ci_local.sh
	@echo "CI local run complete."

test-full:
	@echo "Running full tests..."
	./tools/make/cairo_tests.sh
	@echo "Full tests complete."

# Fuzzing Targets
fuzz-tx:
	@echo "Fuzz testing tx_decode.cairo..."
	./tools/make/fuzzer.sh tests/fuzzing/tx_decode.cairo
	@echo "Fuzz testing tx_decode.cairo complete."

fuzz-header:
	@echo "Fuzz testing header_decode.cairo..."
	./tools/make/fuzzer.sh tests/fuzzing/header_decode.cairo
	@echo "Fuzz testing header_decode.cairo complete."

fuzz-receipt:
	@echo "Fuzz testing receipt_decode.cairo..."
	./tools/make/fuzzer.sh tests/fuzzing/receipt_decode.cairo
	@echo "Fuzz testing receipt_decode.cairo complete."