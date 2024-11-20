import json
import requests
from tools.py.types.starknet.header import StarknetHeader
from contract_bootloader.memorizer.starknet.header import (
    MemorizerKey as HeaderMemorizerKey,
)
from contract_bootloader.memorizer.starknet.storage import (
    MemorizerKey as StorageMemorizerKey,
)


class StarknetProviderBase:
    def __init__(self, rpc_url: str, feeder_url: str):
        self.rpc_url = rpc_url
        self.feeder_url = feeder_url

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
    def __init__(self, rpc_url: str, feeder_url: str):
        super().__init__(rpc_url, feeder_url)

    def get_block_header_by_number(self, block_number: int):
        params = {"block_number": block_number}
        feeder_header = self.send_feeder_request(
            "get_block", {"blockNumber": block_number}
        )
        block_header = StarknetHeader.from_feeder_data(feeder_header)
        assert block_header.hash == int(
            feeder_header["block_hash"], 16
        ), f"Block header hash mismatch: {hex(block_header.hash)} != {feeder_header['block_hash']}"
        return block_header

    def get_storage_rpc(self, address: int, slot: int, block_number: int) -> int:
        params = [hex(address), hex(slot), {"block_number": block_number}]
        storage = self.send_request("starknet_getStorageAt", params)
        return int(storage["result"], 16)


class StarknetKeyProvider(StarknetProvider):
    def __init__(self, rpc_url: str, feeder_url: str):
        super().__init__(rpc_url, feeder_url)

    def get_block_header(self, key: HeaderMemorizerKey) -> StarknetHeader:
        return self.get_block_header_by_number(key.block_number)

    def get_storage(self, key: StorageMemorizerKey) -> int:
        return self.get_storage_rpc(key.address, key.storage_slot, key.block_number)
