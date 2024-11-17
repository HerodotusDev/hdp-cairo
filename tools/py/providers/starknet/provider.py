import json
import requests
from tools.py.types.starknet.header import StarknetHeader
from contract_bootloader.memorizer.starknet.header import MemorizerKey as HeaderMemorizerKey
from contract_bootloader.memorizer.starknet.storage import MemorizerKey as StorageMemorizerKey
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
        
        return response.json()

    
class StarknetProvider(StarknetProviderBase):
    def __init__(self, rpc_url: str, feeder_url: str, chain_id: int):
        super().__init__(rpc_url, feeder_url, chain_id)

    def get_block_header_by_number(self, block_number: int):
        params = {"block_number": block_number}
        feeder_header = self.send_feeder_request("get_block", {"blockNumber": block_number})
        return StarknetHeader.from_feeder_data(feeder_header)
    
    def get_storage_rpc(self, address: int, slot: int, block_number: int) -> int:
        params = [
            hex(address),
            hex(slot),
            {"block_number": block_number}
        ]
        storage = self.send_request("starknet_getStorageAt", params)
        return int(storage["result"], 16)
    
class StarknetKeyProvider(StarknetProvider):
    def __init__(self, rpc_url: str, feeder_url: str, chain_id: int):
        super().__init__(rpc_url, feeder_url, chain_id)

    def get_block_header(self, key: HeaderMemorizerKey) -> StarknetHeader:
        return self.get_block_header_by_number(key.block_number)
    
    def get_storage(self, key: StorageMemorizerKey) -> int:
        return self.get_storage_rpc(key.address, key.storage_slot, key.block_number)

# if __name__ == "__main__":
#     provider = StarknetProvider("https://pathfinder.sepolia.iosis.tech/", "https://alpha-sepolia.starknet.io/feeder_gateway/", 1)
#     block = provider.get_storage_rpc("0x6b8838af5d2a023b24ec8a69720b152d72ae2e4528139c32e05d8a3b9d7d4e7", "0x308cfbb7d2d38db3a215f9728501ac69445a6afbee328cdeae4e23db54b850a", 202485)
#     print(f"Block: {block}")

