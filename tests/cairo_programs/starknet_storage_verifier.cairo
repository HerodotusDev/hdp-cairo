%builtins pedersen range_check bitwise poseidon
from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, BitwiseBuiltin
from packages.eth_essentials.lib.utils import pow2alloc251
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_new, dict_update, dict_squash
from starkware.cairo.common.builtin_poseidon.poseidon import (
    poseidon_hash_single,
    poseidon_hash,
    poseidon_hash_many,
)

from packages.eth_essentials.lib.utils import bitwise_divmod
from src.memorizers.starknet.memorizer import StarknetMemorizer
from src.utils.chain_info import fetch_chain_info
from src.types import ChainInfo
from src.verifiers.starknet.storage_verifier import verify_proofs_inner

func main{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc251();
    let (starknet_memorizer, starknet_memorizer_start) = StarknetMemorizer.init();
    let (chain_info) = fetch_chain_info(393402133025997798000961);
    local batch_len: felt;
    %{
        proof_batches = [
            {
            "state_commitment": "0x5aba7fe14ef2712627f2a93fdf36beb854f6d8d88fe27832acf89af35112ecd",
            "block_number": 202304,
            "contract_address": "0x6b8838af5d2a023b24ec8a69720b152d72ae2e4528139c32e05d8a3b9d7d4e7",
            "storage_addresses": [
                "0x308cfbb7d2d38db3a215f9728501ac69445a6afbee328cdeae4e23db54b850a"
            ],
            "proof": {
                "class_commitment": "0x766a2b910f7f59419fad1c562c5701e21e7acc2e05ab6312b4896ba64fdd4ff",
                "contract_proof": [
                    {
                        "binary": {
                        "left": "0xfa76575cbcbb6a47ea3b96cc485eb45ba2de890885213e8ff8532344dd2a31",
                        "right": "0x15ce862bb23918d070f89685c04de48923cddc64833e0c220a9ceb448e3f66f"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x5d6e6eb94edc160e3d2d4ec7d6e958e4599ab6b32334619412d31b31d66ea43",
                        "right": "0x4d7d74bec4b2c79af7387c7839a6daca841bf05b692ba61bff59338e5f68f6b"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x111e45fe5ee6a3a52f5cec62d6cbbf5170762264e6174669a8a9b772b7572b0",
                        "right": "0x1e1907bbc1a53d910abeb4a3790b4e8cad54fd81352e364e071d513eebbcdfc"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x51f37756808a5749949eedc3cf71a2ee3df995555bfec59d120e5ae88e0c2",
                        "right": "0x666862c5694c46f1d53bd12a575cf48fced2cd1ff373edb3c37640b57016802"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x23756de0c01d3107e4647fd29fa913cf890afc035ef6a1fa5fe4a82562e8398",
                        "right": "0x197b19eb34b5b84d82deabf92246c4f0b8a4a3f2a5077b991d81dc622bbc53d"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x408202711bdac733a2d40150f326a9e203685105c5571ed24ec01900d71b27f",
                        "right": "0x759857a6b1745b242512cf3286939a0647c83eebd24eb899ed10ef0d93f9bd2"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x36f986a74a508427eea5f22f701c26a18120470c2cacad70ede1a263522d8bd",
                        "right": "0x92fa5fa9d192d69a832e748344905b252262d37cd6251ce096b3fb378de004"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x7cf9fd64b3f0faa9936705ff4a226984d6bdcf037009a477012719f0d026b16",
                        "right": "0x237299c16476ab3197c16a4f9beba10f4fca9a69639826525039bbc79292719"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x1306c5e3e606e3c07425f86febcb96f6af9b3c8e5cb7943806cc627ac086ceb",
                        "right": "0x69b9aba40b5bc78ee1bc6f83d2045bc35e6cec204b1123c43e9ec4eaa0744d9"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x6e36947a30fa9eab5c4a381c0d45b47e8fc68d3895c522317e98911e0290ad9",
                        "right": "0x1cdc08b1b16a674a3627d9f14f4dc9834607c2fc6d7807d584dba9d988bd5df"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x6e5405ed45b35ffabc97a6c2154f94202fb1d16f3ffec047fea03e140a03918",
                        "right": "0x484ca7403233ccca6c5b075e9694f3413f9a02de1b08929492f16a9c1351d20"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x3f0a681477effdc5d245a648b3275cdd33e599bf0f0f38eb7ca40c37772aad7",
                        "right": "0x1bbe6e17cc591f9f7e1e9c58a65c84ef222df3a72ee1e434b21f5539f01effc"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x1c31ee89441763bb4505f14296bbd1c641d12e910409bd3c52bfda617d3f9dd",
                        "right": "0x168ec1e067d4366889a3d80d8eaf02ec76743439cf791a560397bdbd59d2fe8"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x3b32edbbe4886a442a6fcd5e076f05509b97895a46164fee6682ae99776bd5b",
                        "right": "0x2e0b4b9c18f9e47bcae072d208451ae162cce965da1aa13722445f67b203796"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x4e40603139ede76fc92073acc738af75259c1924c46b763b3261d41467ad397",
                        "right": "0x777dbe5a523d9acf8ebbb375ed46cdef3fd439798915d33dd71db07e3116f8d"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x3f091edabadfc0e492ad64d102a929f568e6d9156db8dbb414e9ebf51faf35b",
                        "right": "0x4ab15c6359db02d4b255cf3000533c81263c13957be159c4c8e9b780f821665"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x6aa00396d5c9ca3eb9aa66010fc5e47a0f5378f1d16de65d208cc945f60957c",
                        "right": "0x32b5288236807bbfd3f275814107596f7b69892764cbc8246c81897b7ee61fb"
                        }
                    },
                    {
                        "binary": {
                        "left": "0x6adf43d1dc44ca8b47d13864ea1d4f43952859049790aa3bafe42c7a5e6821b",
                        "right": "0x73c7642974c367ae55cdf459c36a6f6da0c26cd039bbab67ec0221126465037"
                        }
                    },
                    {
                        "edge": {
                        "child": "0x525676c056e1bb5c3ea00d5eb082497b23229c7bfa53850425d8f14bdfdd793",
                        "path": {
                            "len": 233,
                            "value": "0x18af5d2a023b24ec8a69720b152d72ae2e4528139c32e05d8a3b9d7d4e7"
                        }
                        }
                    }
                ],
                "contract_data": {
                "class_hash": "0x1db2b3692c1fe6e3a50e8e9d19f57d6f2649ac4c4663a1e744976d495f20f6a",
                "nonce": "0x0",
                "root": "0x38c1afc6f0ba338b16cd0224e5d0cd5bcacd9744a5fad9c7cd55164a3f60fc6",
                "contract_state_hash_version": "0x0",
                "storage_proofs": [
                    [
                        {
                            "edge": {
                            "child": "0x5e8e21587583b06417997f8a8c167ac84a59a88ba0361928704e8554b2b9e0a",
                            "path": {
                                "len": 250,
                                "value": "0x18467ddbe969c6d9d10afcb94280d634a22d357df719466f572711edaa5c285"
                            }
                            }
                        },
                        {
                            "binary": {
                            "left": "0xa1b01d4b1c7",
                            "right": "0x20566c4238e"
                            }
                        }
                        ]
                    ]
                }
            }
        }
        ]

        ids.batch_len = len(proof_batches)

        batch = {
            "storages": proof_batches
        }
    %}

    with starknet_memorizer, chain_info, pow2_array {
        run_tests(batch_len, 0);
    }

    return ();
}

func run_tests{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(batch_len: felt, index: felt) {
    alloc_locals;

    if (batch_len == index) {
        return ();
    }

    local state_root: felt;
    local block_number: felt;

    %{
        ids.state_root = int(batch["storages"][ids.index]["state_commitment"], 16)
        ids.block_number = batch["storages"][ids.index]["block_number"]
    %}

    verify_proofs_inner(state_root, block_number, index);
    return run_tests(batch_len, index + 1);
}
