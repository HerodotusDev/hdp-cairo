.PHONY: build test coverage
cairo_files = $(shell find ./tests/cairo_programs -name "*.cairo")
VENV_PATH ?= venv

build:
	$(MAKE) clean
	./tools/make/build.sh

setup:
	./tools/make/setup.sh ${VENV_PATH}

run-profile:
	@echo "A script to select, compile, run & profile one Cairo file"
	./tools/make/launch_cairo_files.py -profile

run:
	@echo "A script to select, compile & run one Cairo file"
	@echo "Total number of steps will be shown at the end of the run." 
	./tools/make/launch_cairo_files.py
test:
	@echo "Run all tests in tests/cairo_programs" 
	./tools/make/launch_cairo_files.py -test

run-hdp:
	@echo "A script to compile and run HDP"
	@echo "Total number of steps will be shown at the end of the run." 
	./tools/make/launch_cairo_files.py -run_hdp

format-cairo:
	@echo "Format all .cairo files"
	./tools/make/format_cairo_files.sh

run-pie:
	@echo "A script to select, compile & run one Cairo file"
	@echo "Outputs a cairo PIE object"
	@echo "Total number of steps will be shown at the end of the run." 
	./tools/make/launch_cairo_files.py -pie

get-program-hash:
	@echo "Get hdp.cairo program's hash."
	cairo-compile ./src/hdp.cairo --output build/compiled_cairo_files/hdp.json
	cairo-hash-program --program build/compiled_cairo_files/hdp.json

clean:
	rm -rf build/compiled_cairo_files
	mkdir -p build
	mkdir build/compiled_cairo_files

ci-local:
	./tools/make/ci_local.sh
	
test-full:
	./tools/make/cairo_tests.sh

fuzz-tx:
	./tools/make/fuzzer.sh tests/fuzzing/tx_decode.cairo

fuzz-header:
	./tools/make/fuzzer.sh tests/fuzzing/header_decode.cairo