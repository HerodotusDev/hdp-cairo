import json
import requests
from tools.py.types.starknet.header import StarknetHeader
from contract_bootloader.memorizer.starknet.header import MemorizerKey

class StarknetProviderBase:
    def __init__(self, rpc_url: str, feeder_url: str, chain_id: int):
        self.rpc_url = rpc_url
        self.feeder_url = feeder_url
        self.chain_id = chain_id

    def rpc_request(self, rpc_request):
        headers = {"Content-Type": "application/json"}
        response = requests.post(
            url=self.rpc_url, headers=headers, data=json.dumps(rpc_request)
        )
        return response.json()
    
    def send_request(self, method: str, params=None):
        """Send a JSON-RPC request to the server."""
        headers = {"Content-Type": "application/json"}
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params or [],
            "id": 0,
        }
        response = requests.post(self.rpc_url, json=payload, headers=headers)
        return response.json()
    
    def send_feeder_request(self, method: str, params=None):
        """Send a JSON-RPC request to the feeder server."""
        headers = {}
        response = requests.get(
            self.feeder_url + method, params=params, headers=headers
        )

        print(response)

        return response.json()

    
class StarknetProvider(StarknetProviderBase):
    def __init__(self, rpc_url: str, feeder_url: str, chain_id: int):
        super().__init__(rpc_url, feeder_url, chain_id)

    def get_block_header_by_number(self, block_number: int):
        params = {"block_number": block_number}
        feeder_header = self.send_feeder_request("get_block", {"blockNumber": block_number})
        return StarknetHeader.from_feeder_data(feeder_header)
    
class StarknetKeyProvider(StarknetProvider):
    def __init__(self, rpc_url: str, feeder_url: str, chain_id: int):
        super().__init__(rpc_url, feeder_url, chain_id)

    def get_block_header(self, key: MemorizerKey) -> StarknetHeader:
        return self.get_block_header_by_number(key.block_number)

# if __name__ == "__main__":
#     provider = StarknetProvider("https://pathfinder.sepolia.iosis.tech/", "https://alpha-sepolia.starknet.io/feeder_gateway/", 1)
#     block = provider.get_block_header_by_number(55555)
#     print(f"Block: {block}")
#     print(hex(block.hash))

