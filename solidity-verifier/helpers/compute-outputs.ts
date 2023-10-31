const fs = require("fs")
const BN = require("bn.js")

import { utils, BigNumber } from "ethers"

type JobOutputRawJSON = {
    from_block_number_high: BigInt
    to_block_number_low: BigInt
    block_n_plus_one_parent_hash_low: BigInt
    block_n_plus_one_parent_hash_high: BigInt
    block_n_minus_r_plus_one_parent_hash_low: BigInt
    block_n_minus_r_plus_one_parent_hash_high: BigInt
    mmr_last_root_poseidon: BigInt
    mmr_last_root_keccak_low: BigInt
    mmr_last_root_keccak_high: BigInt
    mmr_last_len: BigInt
    new_mmr_root_poseidon: BigInt
    new_mmr_root_keccak_low: BigInt
    new_mmr_root_keccak_high: BigInt
    new_mmr_len: BigInt
}

type JobOutputRawJS = {
    fromBlockNumberHigh: string
    toBlockNumberLow: string
    blockNPlusOneParentHashLow: string
    blockNPlusOneParentHashHigh: string
    blockNMinusRPlusOneParentHashLow: string
    blockNMinusRPlusOneParentHashHigh: string
    mmrLastRootPoseidon: string
    mmrLastRootKeccakLow: string
    mmrLastRootKeccakHigh: string
    mmrLastLen: string
    newMmrRootPoseidon: string
    newMmrRootKeccakLow: string
    newMmrRootKeccakHigh: string
    newMmrLen: string
}

type JobOutputPackedJS = {
    blockNumbersPacked: string
    blockNPlusOneParentHash: string
    blockNMinusRPlusOneParentHash: string
    mmrPreviousRootPoseidon: string
    mmrPreviousRootKeccak: string
    mmrNewRootPoseidon: string
    mmrNewRootKeccak: string
    mmrSizesPacked: string
}

function parseArgs(argv: string[]): { outputsFileName: string } {
    const outputsFileName = argv[2]
    if (!outputsFileName) {
        throw new Error("Missing outputs file name")
    }

    return {
        outputsFileName,
    }
}

function loadJSONFile(filePath: string): JobOutputRawJS[] {
    const jsonString = fs.readFileSync(filePath, "utf-8")
    const jsonData = JSON.parse(jsonString)

    return (jsonData as JobOutputRawJSON[]).map((output) => ({
        fromBlockNumberHigh: output.from_block_number_high.toString(),
        toBlockNumberLow: output.to_block_number_low.toString(),
        blockNPlusOneParentHashLow:
            output.block_n_plus_one_parent_hash_low.toString(),
        blockNPlusOneParentHashHigh:
            output.block_n_plus_one_parent_hash_high.toString(),
        blockNMinusRPlusOneParentHashLow:
            output.block_n_minus_r_plus_one_parent_hash_low.toString(),
        blockNMinusRPlusOneParentHashHigh:
            output.block_n_minus_r_plus_one_parent_hash_high.toString(),
        mmrLastRootPoseidon: output.mmr_last_root_poseidon.toString(),
        mmrLastRootKeccakLow: output.mmr_last_root_keccak_low.toString(),
        mmrLastRootKeccakHigh: output.mmr_last_root_keccak_high.toString(),
        mmrLastLen: output.mmr_last_len.toString(),
        newMmrRootPoseidon: output.new_mmr_root_poseidon.toString(),
        newMmrRootKeccakLow: output.new_mmr_root_keccak_low.toString(),
        newMmrRootKeccakHigh: output.new_mmr_root_keccak_high.toString(),
        newMmrLen: output.new_mmr_len.toString(),
    })) as JobOutputRawJS[]
}

// merges two uint128s (low, high) into one uint256.
// @param lower The lower uint128.
// @param upper The upper uint128.
function merge128(lower: string, upper: string): string {
    // Create BN instances
    const lowerBN = new BN(lower)
    const upperBN = new BN(upper)

    // Shift upper by 128 bits to the left
    const shiftedUpper = upperBN.shln(128)

    // return (upper << 128) | lower
    return BigNumber.from(shiftedUpper.or(lowerBN).toString(10)).toHexString()
}

function bigNumberToHex32(value: BigNumber): string {
    // Convert the BigNumber to a bytes array
    const valueBytes = utils.arrayify(value)

    // Calculate the number of bytes short of 32 we are
    const padding = new Uint8Array(32 - valueBytes.length)

    // Concatenate the padding and valueBytes
    const paddedValueBytes = utils.concat([padding, valueBytes])

    // Convert to a hexadecimal string
    const hex = utils.hexlify(paddedValueBytes)

    return hex
}

async function main() {
    const { outputsFileName } = parseArgs(process.argv)
    const outputs = loadJSONFile(outputsFileName)

    const jobsOutputsPacked: JobOutputPackedJS[] = outputs.map(
        (output: JobOutputRawJS) =>
            ({
                blockNumbersPacked: merge128(
                    output.fromBlockNumberHigh,
                    output.toBlockNumberLow
                ),
                blockNPlusOneParentHash: merge128(
                    output.blockNPlusOneParentHashLow,
                    output.blockNPlusOneParentHashHigh
                ),
                blockNMinusRPlusOneParentHash: merge128(
                    output.blockNMinusRPlusOneParentHashLow,
                    output.blockNMinusRPlusOneParentHashHigh
                ),
                mmrPreviousRootPoseidon: bigNumberToHex32(
                    BigNumber.from(output.mmrLastRootPoseidon)
                ),
                mmrPreviousRootKeccak: merge128(
                    output.mmrLastRootKeccakLow,
                    output.mmrLastRootKeccakHigh
                ),
                mmrNewRootPoseidon: bigNumberToHex32(
                    BigNumber.from(output.newMmrRootPoseidon)
                ),
                mmrNewRootKeccak: merge128(
                    output.newMmrRootKeccakLow,
                    output.newMmrRootKeccakHigh
                ),
                mmrSizesPacked: merge128(output.mmrLastLen, output.newMmrLen),
            }) as JobOutputPackedJS
    )

    const zeroBytes32 = "0x" + "0".repeat(64)
    const jobsOutputs = jobsOutputsPacked
        .map((output) => Object.values(output))
        .map((x: string[]) =>
            x.map((val) => (val === "0x00" ? zeroBytes32 : val))
        )

    const types = [
        "uint256", // toBlockNumberLow | fromBlockNumberHigh
        "bytes32", // blockNPlusOneParentHashLow | blockNPlusOneParentHashHigh
        "bytes32", // blockNMinusRPlusOneParentHashLow | blockNMinusRPlusOneParentHashHigh
        "bytes32", // mmrLastRootPoseidon
        "bytes32", // mmrLastRootKeccakLow | mmrLastRootKeccakHigh
        "bytes32", // newMmrRootPoseidon
        "bytes32", // newMmrRootKeccakLow | newMmrRootKeccakHigh
        "uint256", // mmrLastLen | newMmrLen
    ]

    // Pass back to foundry
    const encoder = new utils.AbiCoder()
    console.log(encoder.encode([`tuple(${types.join()})[]`], [jobsOutputs]))
}

main().catch(console.error)
