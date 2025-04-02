import os
import json
from web3 import Web3

def main():    
    # Retrieve the RPC URL from the environment variable
    rpc_url = os.getenv("RPC_URL_ETHEREUM_SEPOLIA")
    if not rpc_url:
        print("RPC_URL_ETHEREUM_SEPOLIA not found in the env")
        return

    # Connect to the Ethereum node using the provided RPC URL
    w3 = Web3(Web3.HTTPProvider(rpc_url))

    # Check if the connection is successful
    if not w3.is_connected():
        print("Failed to connect to the Ethereum node using RPC_URL_ETHEREUM_SEPOLIA.")
        return

    # Define the starting block and the range (100 blocks inclusive)
    start_block = int("0x752C60", 16)
    end_block = start_block + 100

    # Calculate the number of blocks fetched
    num_blocks = end_block - start_block + 1

    # Start the output list with the number of blocks in hex format
    output = [{"visibility": "public", "value": hex(num_blocks)}]

    # Iterate over each block in the range and fetch block number and transaction count
    for block_number in range(start_block, end_block + 1):
        try:
            block = w3.eth.get_block(block_number)
            block_number_hex = hex(block.number)
            tx_count_hex = hex(len(block.transactions))
            output.append({"visibility": "public", "value": block_number_hex})
            output.append({"visibility": "public", "value": tx_count_hex})
        except Exception as e:
            print(f"Error fetching block {block_number}: {e}")

    # Print the final output as a JSON formatted string
    print(json.dumps(output, indent=4))

if __name__ == "__main__":
    main()
