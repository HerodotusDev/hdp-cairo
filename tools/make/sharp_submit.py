#!venv/bin/python3
import os, time, signal, re
import shutil
import subprocess
import argparse
import json, zipfile
import multiprocessing
from tools.make.sharp_submit_params import (
    STARK_PRIME,
    CAIROUT_OUTPUT_KEYS,
    MAX_RESOURCES_PER_JOB,
    INPUT_PATH,
    FILENAME_DOT_CAIRO,
    FILENAME,
    FILENAME_DOT_CAIRO_PATH,
    COMPILED_CAIRO_FILE_PATH,
)
from tools.py.utils import write_to_json, clear_directory

N_CORES = os.cpu_count()


# Create an ArgumentParser object
parser = argparse.ArgumentParser(
    description="A tool for submitting pie objects to SHARP."
)

# Define command-line arguments
parser.add_argument("-pie", action="store_true", help="create pie objects")
parser.add_argument("-sharp", action="store_true", help="sends pie objects to SHARP")
parser.add_argument(
    "-pie-multicore",
    action="store_true",
    help="create pie objects using all available cores",
)
# Parse the command-line arguments
args = parser.parse_args()


print(f"Compiling {FILENAME_DOT_CAIRO} ... ")

return_code = os.system(
    f"cairo-compile {FILENAME_DOT_CAIRO_PATH} --output build/compiled_cairo_files/{FILENAME}.json"
)
if return_code == 0:
    print(f"### Compilation successful.")
else:
    print(f"### Compilation failed. Please fix the errors and try again.")
    exit(1)


PROGRAM_HASH = int(
    subprocess.check_output(
        [
            "cairo-hash-program",
            "--program",
            f"build/compiled_cairo_files/{FILENAME}.json",
        ]
    ).decode(),
    16,
)


input_files = [f for f in os.listdir(INPUT_PATH) if f.endswith("_input.json")]
input_files_paths = [INPUT_PATH + f for f in input_files]


# Extract the main number from the filename to use for sorting
def get_sort_key(filename):
    match = re.search(r"blocks_(\d+)_", filename)
    if match:
        return int(match.group(1))
    return 0


def split_inputs_evenly():
    """Distribute the input files evenly among the available cores."""

    # List all _input.json files and sort them based on the main number
    all_input_files = sorted(
        [f for f in os.listdir(INPUT_PATH) if f.endswith("_input.json")],
        key=get_sort_key,
        reverse=True,  # Descending order
    )

    # If no files in the main INPUT_PATH, print a warning and return
    if not all_input_files:
        print("Warning: No input files found in main directory.")
        return

    if len(all_input_files) <= N_CORES:
        # If fewer or equal input files than cores, distribute one file per core
        for core_num, input_file in enumerate(all_input_files):
            core_input_path = f"{INPUT_PATH}{core_num}/"
            if os.path.exists(core_input_path):
                clear_directory(core_input_path)
            else:
                os.makedirs(core_input_path)
            shutil.copy2(f"{INPUT_PATH}{input_file}", f"{core_input_path}{input_file}")
            output_file = input_file.replace("_input.json", "_output.json")
            shutil.copy2(
                f"{INPUT_PATH}{output_file}", f"{core_input_path}{output_file}"
            )
    else:
        # Split files into chunks of size N_CORES for staggered distribution
        chunks = [all_input_files[i::N_CORES] for i in range(N_CORES)]

        # Distribute chunks to cores
        for core_num in range(N_CORES):
            core_input_path = f"{INPUT_PATH}{core_num}/"
            if os.path.exists(core_input_path):
                clear_directory(core_input_path)
            else:
                os.makedirs(core_input_path)

            # Get files for this core from the chunks
            files_for_this_core = chunks[core_num]

            for input_file in files_for_this_core:
                shutil.copy2(
                    f"{INPUT_PATH}{input_file}", f"{core_input_path}{input_file}"
                )
                output_file = input_file.replace("_input.json", "_output.json")
                shutil.copy2(
                    f"{INPUT_PATH}{output_file}", f"{core_input_path}{output_file}"
                )


def run_cairo_program(input_file_path) -> dict:
    """
    Run the cairo program on the given input file and return the program's output
    as a dictionary.
    Write the pie object to a file named <input_filename>_pie.zip to the same directory as the input file.
    """
    pie_output_path = input_file_path.replace("_input.json", "_pie.zip")
    cmd = f"cairo-run --program={COMPILED_CAIRO_FILE_PATH} --program_input={input_file_path} --layout=starknet_with_keccak --print_output"
    cmd += f" --cairo_pie_output {pie_output_path}"
    stream = os.popen(cmd)
    output = stream.read()

    return parse_cairo_output(output)


def parse_cairo_output(output: str) -> dict:
    """
    Parse the output of the cairo program from stdout and return it as a dictionary.
    """
    lines = output.split("\n")
    program_output_index = lines.index("Program output:")
    # Extract field elements from the lines after 'Program output:'
    felts = []
    for line in lines[program_output_index + 1 :]:
        line = line.strip()
        try:
            num = int(line)
            felts.append(num % STARK_PRIME)
        except ValueError:
            # If a line cannot be converted to an integer, skip it.
            continue
    assert len(felts) == len(
        CAIROUT_OUTPUT_KEYS
    ), f"Expected {len(CAIROUT_OUTPUT_KEYS)} numbers in output, got {len(felts)}"
    return dict(zip(CAIROUT_OUTPUT_KEYS, felts))


def assert_execution_resources_under_limits(pie_object_filepath):
    with zipfile.ZipFile(pie_object_filepath, "r") as zipf:
        assert (
            "execution_resources.json" in zipf.namelist()
        ), f"Missing execution_resources.json in {pie_object_filepath}"
        with zipf.open(
            "execution_resources.json",
        ) as json_file:
            data = json.load(json_file)
            n_steps = data["n_steps"]
            assert (
                n_steps <= MAX_RESOURCES_PER_JOB["n_steps"]
            ), f"n_steps exceeds the limit of {MAX_RESOURCES_PER_JOB['n_steps']}"
            for resource in MAX_RESOURCES_PER_JOB["builtin_instance_counter"]:
                assert (
                    data["builtin_instance_counter"][resource]
                    <= MAX_RESOURCES_PER_JOB["builtin_instance_counter"][resource]
                ), f"{resource} exceeds the limit of {MAX_RESOURCES_PER_JOB[resource]}"


def submit_pie_to_sharp(filename):
    """Submit a pie object to SHARP and return the job key and fact"""
    result = subprocess.run(
        [
            "cairo-sharp",
            "submit",
            "--cairo_pie",
            f"{INPUT_PATH}{filename.removesuffix('_input.json')}_pie.zip",
        ],
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        raise Exception(f"Failed to submit pie to SHARP: {result.stderr}")

    # Extract Job Key and Fact from stdout
    job_key, fact = None, None
    for line in result.stdout.splitlines():
        if "Job key:" in line:
            job_key = line.split(":")[-1].strip()
        if "Fact:" in line:
            fact = line.split(":")[-1].strip()

    if job_key is None or fact is None:
        raise Exception(
            f"Failed to parse job key and fact from SHARP output: {result.stdout}"
        )

    return job_key, fact


if __name__ == "__main__":
    if args.pie_multicore:
        split_inputs_evenly()
        pie_objects_path = os.path.join(INPUT_PATH, "pie_objects/")
        SHUTDOWN_REQUESTED = False
        CHILD_PROCESSES = []
        if not os.path.exists(pie_objects_path):
            os.makedirs(pie_objects_path)

        def signal_handler(signal, frame):
            """Handle SIGINT signals (generated by CTRL+C)."""
            global SHUTDOWN_REQUESTED
            print("\nCTRL+C detected. Requesting all child processes to shut down...")
            SHUTDOWN_REQUESTED = True

        signal.signal(signal.SIGINT, signal_handler)

        def run_for_core(core_num):
            core_input_path = f"{INPUT_PATH}{core_num}/"
            core_input_files = sorted(
                [f for f in os.listdir(core_input_path) if f.endswith("_input.json")],
                key=get_sort_key,
                reverse=True,
            )
            core_input_files_paths = sorted(
                [core_input_path + f for f in core_input_files],
                key=get_sort_key,
                reverse=True,
            )
            results = {}
            for input_filename, input_filepath in zip(
                core_input_files, core_input_files_paths
            ):
                print(
                    f"[Core {core_num}] Running chunk processor for {input_filename} ..."
                )
                t0 = time.time()
                output = run_cairo_program(input_filepath)
                t1 = time.time()
                print(
                    f"[Core {core_num}] ==> Run successful. Time taken: {t1-t0} seconds."
                )

                # Check the output right inside this core
                expected_output = json.load(
                    open(input_filepath.replace("_input", "_output"))
                )
                pie_path = input_filepath.replace("_input.json", "_pie.zip")
                assert (
                    output == expected_output
                ), f"[Core {core_num}] Output mismatch for {input_filename}.Expected: \n {expected_output}\n got: \n{output}"
                print(
                    f"[Core {core_num}] ==> Run is correct. Output matches precomputed output."
                )
                assert_execution_resources_under_limits(pie_path)

                shutil.copy2(f"{pie_path}", pie_objects_path)
                results[input_filename] = output
            return results

        with multiprocessing.Pool(processes=N_CORES) as pool:
            corewise_results = pool.map(run_for_core, range(N_CORES))
            if SHUTDOWN_REQUESTED:
                print("Shutting down child processes...")
                pool.terminate()

    else:
        sharp_results = {}
        for input_filename, input_filepath in zip(input_files, input_files_paths):
            if args.pie:
                print(f"Running chunk processor for {input_filename} ...")
                t0 = time.time()
                output = run_cairo_program(input_filepath)
                t1 = time.time()
                print(f"\t ==> Run successful. Time taken: {t1-t0} seconds.")
                expected_output = json.load(
                    open(input_filepath.replace("_input", "_output"))
                )
                assert (
                    output == expected_output
                ), f"Output mismatch for {input_filename}.Expected: \n {expected_output}\n got: \n{output}"
                assert_execution_resources_under_limits(
                    input_filepath.replace("_input.json", "_pie.zip")
                )
                print(f"\t ==> Run is correct. Output matches precomputed output.")
                print(
                    f"\t ==> PIE Object written to {INPUT_PATH}{input_filename.removesuffix('_input.json')}_pie.zip \n"
                )

            if args.sharp:
                print(f"Submitting job for {input_filename} to SHARP ...")

                job_key, fact = submit_pie_to_sharp(input_filename)
                print(f"\t ==> Job submitted successfully to SHARP.")
                print(f"\t ==> Job key: {job_key}, Fact: {fact} \n")

                sharp_results[input_filename] = {"job_key": job_key, "fact": fact}

                write_to_json(f"{INPUT_PATH}sharp_submit_results.json", sharp_results)

        if args.pie:
            print(f"All runs successful. PIE objects written to {INPUT_PATH}")
        if args.sharp:
            print(
                f"All jobs submitted successfully. Results written to {INPUT_PATH}sharp_submit_results.json"
            )
