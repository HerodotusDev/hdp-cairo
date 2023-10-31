# Utility Scripts


## `setup.sh`
### Usage : `make setup`

This script sets up a virtual environment within the `venv/` directory and installs all the necessary Python packages for this repository.  
All scripts should be run after activating the environment using `source venv/bin/activate`.

 Additionally, it updates the environment variable PYTHONPATH to ensure Python scripts within the tools/ directory can be executed from any location.
It also [patches](poseidon_utils.patch) the poseidon implementation of cairo-lang to make it 7x faster. 

## `build.sh`

### Usage : `make build`

This script compiles all Cairo files located in:
- `src/`
- `tests/cairo_programs/`

The compiled outputs are stored in `build/compiled_cairo_files/`.

## `launch_cairo_files.py`

### Usage : `make run`, `make run-profile` or `make test`

- `make run` :  
This script provides an option to choose a Cairo file for execution from:
    - `src/single_chunk_processor/chunk_processor.cairo`  
    - All the Cairo files within  `tests/cairo_programs/`  

    After selection, the script compiles the chosen file and runs it, using input from a corresponding file located in the same directory. The input file should have the same name as the Cairo file but with the `_input.json` extension in place of `.cairo.`

    For the `chunk_processor.cairo` file, an additional prompt allows selection from input files ending in `_input.json` within the `src/single_chunk_processor/data` directory. See `prepare_inputs_api.py` section. 


- `make run-profile`:  
 Has the same logic as `make run` except that the Cairo file is executed with profiling enabled. The resultant profile graph is saved to `build/profiling/`.

- `make test`:  
Simply runs all the files inside `tests/cairo_programs/`.

## `db.py`

### Usage : `make db-update`

A script that creates or updates a local sqlite database containing the block numbers and their corresponding block headers. The database is stored at the root of the repository under the name `blocks.db`.

You will need to store the RPC urls for Mainnet and/or Goerli by creating a `.env` file in the root directory of the repository and adding the following lines to it:

```plaintext
RPC_URL_MAINNET=<RPC_URL_MAINNET>
RPC_URL_GOERLI=<RPC_URL_GOERLI>
```

It will update the database up until the block `HIGH_BLOCK_NUMBER` specified at the top of the script. Other parameters at the top the script can be modified if needed.

## `prepare_inputs_api.py`

### Usage : `make prepare-processor-input`

This Python script prepares inputs for the chunk processor and precomputes the expected outputs. It is using the data from a local sqlite database containing the block numbers and their corresponding block headers.

To specify which inputs to prepare, modify the main function at the end of the file.

The `prepare_full_chain_inputs` function parameters include:

 - `from_block_number_high` (int) : Highest block number to include in the input.
 - `to_block_number_low` (int) : Lowest block number to include in the input.
 - `batch_size` (int) : Fixed number of blocks to include in each batch.
 - `dynamic` (bool) : If set to `True`, bypasses the number set in `batch_size` and precomputes a dynamic batch size so that the execution resources are exactly under the limits set in [MAX_RESOURCES_PER_JOB](sharp_submit_params.py)
 - (Optional) `initial_params` (dict) : A dictionary containing an initial MMR state, having the following structure :
```JSON
{

    "mmr_peaks": {
        "poseidon":[peak0 (int), peak1 (int), ..., peakn (int)],
        "keccak": [peak0 (int), peak1 (int), ..., peakn (int)]
    },
    "mmr_size": last_mmr_size (int),
    "mmr_roots": {
        "poseidon": poseidon_root (int),
        "keccak": keccak_root (int)
    }},
    
}
```  
If `initial_params` is not provided, the initial MMR state is set to the following:
```JSON
{

    "mmr_peaks": {
        "poseidon":[968420142673072399148736368629862114747721166432438466378474074601992041181],
        "keccak": [93435818137180840214006077901347441834554899062844693462640230920378475721064]
    },

    "mmr_size": 1,
    "mmr_roots": {
        "poseidon": 2921600461849179232597610084551483949436449163481908169507355734771418934190,
        "keccak": 42314464114191397424730009642010999497079411585549645511398238200244040012667
    }
}
    
```

The initial peak values correspond to the Poseidon and Keccak hashes of the string `b'brave new world'`.
The roots are computed accordingly to the [get_root() function.](../py/mmr.py).



The inputs and expected outputs are written to `src/single_chunk_processor/data/`. Those can be used later by the chunk processor and the script `sharp_submit.py` or with `make run`.
The function returns the MMR state after the last chunk, ready to be used as `initial_params` for the next iteration.






## `sharp_submit.py`

### Usages :
1) `make batch-cairo-pie`:  
    Runs the chunk processor on all the inputs files under `src/single_chunk_processor/data/` and create PIE objects for each of them in the same directory.
    It also checks that the output of each run matches the precomputed output in the same directory.
2) `make batch-pie-multicore`:
    Same as 1) but uses multiple cores to create the PIE objects in parallel.
3) `make batch-sharp-submit`:  
    Submits all the PIE objects under `src/single_chunk_processor/data/` to SHARP. Results, including job keys and facts, are saved to  `src/single_chunk_processor/data/sharp_submit_results.json`.
4) `make batch-run-and-submit`:  
    Combines the processes of 1) and 3) into a single command.


Note : This is configured to be sent with the goerli public SHARP. It will work with small chunks of ~10 blocks at most. 


