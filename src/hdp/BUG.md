## Description:

I am facing an issue in the MPT verification of a storage slot. 


I am doing `_balanceOf` proofs of this ERC20 token: https://sepolia.etherscan.io/address/0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc

and for these addresses:

- `0xe2Aafbf1889087C1383E43625AF7433D4fad9824` -> slot: `0xe034d5bf282edc41d85f4f6f7c3fa6366d65546fd9c5c73ccfa943e88e6ea9a6`
- `0x345696b3A0DB63784EE59Bae1dA95758ff615bc5` -> slot: `0x8b6320060189e975d5109fc49da096d04d476f43cc21351b6eae9d24bf2aa304`

I generate these proofs for block 5434826 on sepolia.

## Error:
For address `e2A` I am able to confirm the storage proof in cairo, for the other address not. Both proofs however work outside of cairo, and I am able to decode the values. I have created a python script that generates and verifies the proofs. In python both of them work. In cairo one doesnt.

## Steps to reproduce:

### Valid Proof:
- `hpd_input.json` contains the working storage proof for `e2A`. It also contains the required header and and account proofs.
- To run: `make run` -> `hdp.cairo`

These inputs should pass the verification in cairo and print the result.

### Invalid Proof:
- The header and account proofs are the same, so we can reuse the `hdp_input.json` file.
- generate the storage proof with `python src/hdp/tools/slot_proof.py`
- this script will generate the proof and print the result + json encoded cairo input.
- replace the `storages` from `hdp_input.json` array element with the printed output from the script.
- rerun to reproduce error. 

The valid proof can also be generated in the python script. 

The inputs can also be generated via hpd-rs:
- valid: `cargo run -- encode -a -c valid.json "avg" -b 5434826 5434826 "storage.0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc.0xe034d5bf282edc41d85f4f6f7c3fa6366d65546fd9c5c73ccfa943e88e6ea9a6"`
- inval: `cargo run -- encode -a -c inval.json "avg" -b 5434826 5434826 "storage.0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc.0x8b6320060189e975d5109fc49da096d04d476f43cc21351b6eae9d24bf2aa304"`


These files can be found in `tests/hdp/fixtures/bug_1/`. The python scripts where only added to confirm the proofs are valid.