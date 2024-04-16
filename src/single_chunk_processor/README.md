# Chunk Processor

The chunk procesor is used to process block headers from EVM in a continuous way. For clarity, we will define some notations. 

- `n` is the block number of first block header being processed.   

- `r` is the number of block headers being processed in a single chunk.

- `n-r+1` is the block number of last block header being processed.

- `H(k)` is the hash of block header `k`.

- `PH(k)` is the parent hash of block header `k`. Ie: `PH(k) = H(k-1)`


This means one run of chunk processor will process block headers from block number `n` to block number `n-r+1` (both bound included), for a total of `r` block headers.  
We will note `[n-r+1, n]` the range of block headers being processed.


The processor is essentially doing two things:  

I. Proves the cryptographic link from block header `N` to block header `N - R + 1`.  
II. Stores the block headers hashes inside a cryptographic accumulator (a Merkle Mountain Range (MMR)).


The processor takes as (private) input the following data :
1) n
2) n-r+1
1) PH(n+1) : The parent hash of the first block header being processed.
2) The block headers for block numbers `[n-r+1, n]`
3) The size in bytes of each block header. 
3) The previous MMR root hash
4) The previous MMR length
5) The previous MMR peaks that lead to the previous MMR root hash. 

It then outputs the following data:
1) n : from the input
2) n-r+1 : extracted from the block header n-r+1
3) PH(n+1) : from the input
4) PH(n-r+1) : extracted from the block header n-r+1
5) The previous MMR root hash : from the input
6) The previous MMR length : from the input
7) The new MMR root hash
8) The new MMR length

Sample Output : 

```json
{
    "from_block_number_high": 15000,
    "to_block_number_low": 13363,
    "block_n_plus_one_parent_hash_low": 154290822937787733774056680842541373608,
    "block_n_plus_one_parent_hash_high": 156853552136708155686345135791644162539,
    "block_n_minus_r_plus_one_parent_hash_low": 281371821923349311514485903736664824394,
    "block_n_minus_r_plus_one_parent_hash_high": 23750595297014185889703423987183304060,
    "mmr_last_root_poseidon": 2921600461849179232597610084551483949436449163481908169507355734771418934190,
    "mmr_last_root_keccak_low": 255731995079421981708054171413297402747,
    "mmr_last_root_keccak_high": 124351033810760994347164128898134164945,
    "mmr_last_len": 1,
    "new_mmr_root_poseidon": 366537929573550773164043174537178174908470791275974636779493804144457621821,
    "new_mmr_root_keccak_low": 155207974490154382400874803233698222316,
    "new_mmr_root_keccak_high": 18856215989401494535507531263318176723,
    "new_mmr_len": 3271
}
```


## I. Proving the cryptographic link from block header `N` to block header `N - R + 1`.

Assuming `PH(n+1)` provided as input (and returned as output) is correct, we can assert that H(n) = PH(n+1).

Following RLP conventions, one is able to extract the parent hash of a block header deterministically. 

Then it straightforward to continue this recursion, extracting `PH(n)` and assert that `H(n-1) == PH(n)`

This ensures the integrity of the data of the block headers [n-r+1, n-r] provided as input. 

We can therefore store all `[H[n],H[n-1], ..., H[n-r+1]]` into the accumulator. 

The `PH(n-r+1)` is extracted and returned as output to be able to use it as the "new" PH(n+1) for the next chunk. 

The "true" `n-r+1` is extracted from the last block header and returned as output.
It is asserted against the `n-r+1` provided as input, and since the number of blocks processed was `n - (n-r+1) + 1 = r`, we deduce that the `n` provided as input is correct and we can return it as output.

## 2. Storing the block header hashes into the MMR

Using the previous root of the MMR and the previous peaks provided as input, one can assert that the peaks provided indeed match the root of the tree. 

If that's the case, one can only use the previous MMR peaks to append values to it. 

The MMR is not using indexes when appending values or when merging childrens, as we do not care about duplicates nor the order of insertion. 


The reference implementation of the MMR construction can be found in [mmr.py](../../tools/py/mmr.py).
The implementation of the processor lies in [chunk_processor.cairo](chunk_processor.cairo).

## Setup

### Create a virtual environment and install the dependencies (one-time setup)

```bash
make setup
```

After that and every time you get back to the repo, you will need to activate the virtual environment by doing:

```bash
source venv/bin/activate
```

### Run Cairo unit tests

```bash
make test
```

### Get the chunk processor program's hash

```bash
make get-program-hash
```

This command computes the hash of the main chunk processor program and outputs it to stdout. It is used to make sure that STARK proofs of this program are indeed relative to the chunk processor. The hash is hardcoded in the [solidity contract](../../solidity-verifier/src/SharpFactsAggregator.sol) that verifies SHARP facts.

### Prepare inputs for the chunk processor, SHARP submitting & more

The general workflow is as follows:

1. Update the database of block headers
2. Prepare the inputs and expected outputs for the chunk processor
3. Run the chunk processor to create PIE objects
4. Submit those PIE objects to SHARP to prove the execution.

For more details about the other `make` commands and test the repository, see [tools/make/README.md](tools/make/README.md).
