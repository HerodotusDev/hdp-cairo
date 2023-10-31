.PHONY: build test coverage
cairo_files = $(shell find ./tests/cairo_programs -name "*.cairo")

build:
	$(MAKE) clean
	./tools/make/build.sh

setup:
	./tools/make/setup.sh

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

run-pie:
	@echo "A script to select, compile & run one Cairo file"
	@echo "Outputs a cairo PIE object"
	@echo "Total number of steps will be shown at the end of the run." 
	./tools/make/launch_cairo_files.py -pie
db-update:
	@echo "Update/create the block headers database"
	./tools/make/db.py
batch-cairo-pie:
	@echo "Run processor with all inputs in src/single_chunk_processor/data/ and write pie objects"
	./tools/make/sharp_submit.py -pie

batch-pie-multicore:
	@echo "Run processor with all inputs in src/single_chunk_processor/data/ and write pie objects"
	./tools/make/sharp_submit.py -pie-multicore
	
batch-sharp-submit:
	@echo "Submits all pie objects in src/single_chunk_processor/data/ to SHARP"
	./tools/make/sharp_submit.py -sharp

batch-run-and-submit:
	@echo "Run processor with all inputs in src/single_chunk_processor/data/ and submit to SHARP"
	./tools/make/sharp_submit.py -pie -sharp

prepare-processor-input:
	@echo "Prepare chunk_processor_input.json data with the parameters in tools/make/processor_input.json"
	./tools/make/prepare_inputs_api.py

get-program-hash:
	@echo "Get chunk_processor.cairo program's hash."
	cairo-compile ./src/single_chunk_processor/chunk_processor.cairo --output build/compiled_cairo_files/chunk_processor.json
	cairo-hash-program --program build/compiled_cairo_files/chunk_processor.json
clean:
	rm -rf build/compiled_cairo_files
	mkdir -p build
	mkdir build/compiled_cairo_files