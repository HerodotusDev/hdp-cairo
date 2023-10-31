"""
Simple script to show how to compute the fact for a given program hash and program output.
"""
from web3 import Web3
from typing import List
# Pedersen hash of the compiled program
program_hash = 0x21876b34efae7a9a59580c4fb0bfc7971aecebce6669a475171fe0423c0a784

# output of field elements from the cairo program run
def get_program_output_values_from_output_dict(output:dict) -> List[int]:
  program_output = [output['from_block_number_high'],
                    output['to_block_number_low'],
                    output['block_n_plus_one_parent_hash_low'], 
                    output['block_n_plus_one_parent_hash_high'],
                    output['block_n_minus_r_plus_one_parent_hash_low'],
                    output['block_n_minus_r_plus_one_parent_hash_high'],
                    output['mmr_last_root_poseidon'],
                    output['mmr_last_root_keccak_low'],
                    output['mmr_last_root_keccak_high'],
                    output['mmr_last_len'],
                    output['new_mmr_root_poseidon'],
                    output['new_mmr_root_keccak_low'],
                    output['new_mmr_root_keccak_high'],
                    output['new_mmr_len']]
  return program_output


sample_output = {
    "from_block_number_high": 15,
    "to_block_number_low": 11,
    "block_n_plus_one_parent_hash_low": 131981375444251169070320747941574705465,
    "block_n_plus_one_parent_hash_high": 9190262332975293837473560276400736055,
    "block_n_minus_r_plus_one_parent_hash_low": 340103683093979563137554779304198032351,
    "block_n_minus_r_plus_one_parent_hash_high": 43101652814983461597608113204526399126,
    "mmr_last_root_poseidon": 178927259457516751002312185258349076474482726106541020626711098656392107890,
    "mmr_last_root_keccak_low": 213778379067164795009803250934059230996,
    "mmr_last_root_keccak_high": 311784430861546027319226254416891675182,
    "mmr_last_len": 10,
    "new_mmr_root_poseidon": 252551093926361284205375255497947755050313027176556264268816177711092997281,
    "new_mmr_root_keccak_low": 1282909371342134768584297556671282863,
    "new_mmr_root_keccak_high": 320481516134505083105287001274104545683,
    "new_mmr_len": 19
}


def compute_fact(program_hash:int, program_output:List[int]):
    kecOutput = Web3.solidityKeccak(["uint256[]"], [program_output])
    fact = Web3.solidityKeccak(["uint256", "bytes32"], [program_hash, kecOutput])
    return fact.hex()

if __name__ == '__main__':
  fact = compute_fact(program_hash, get_program_output_values_from_output_dict(sample_output))

  print(fact)




