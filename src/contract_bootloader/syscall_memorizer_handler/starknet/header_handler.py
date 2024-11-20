from typing import List
from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from contract_bootloader.memorizer.starknet.header import (
    AbstractStarknetHeaderBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.types.starknet.header import StarknetHeader


class StarknetHeaderHandler(AbstractStarknetHeaderBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: StarknetMemorizer):
        super().__init__(memorizer=memorizer)
        self.segments = segments

    def extract_fields(self, key: MemorizerKey) -> List[int]:
        memorizer_value_ptr = self.memorizer.read(key=key.derive())
        fields_len = self.segments.memory[memorizer_value_ptr]

        fields = self._get_felt_range(
            start_addr=memorizer_value_ptr,
            end_addr=memorizer_value_ptr + fields_len + 1,
        )
        return fields

    def get_block_number(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).block_number

    def get_state_root(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).state_root

    def get_sequencer_address(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).sequencer_address

    def get_block_timestamp(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).block_timestamp

    def get_transaction_count(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).transaction_count

    def get_transaction_commitment(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).transaction_commitment

    def get_event_count(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).event_count

    def get_event_commitment(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).event_commitment

    def get_parent_block_hash(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).parent_block_hash

    def get_state_diff_commitment(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).state_diff_commitment

    def get_state_diff_length(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).state_diff_length

    def get_l1_gas_price_in_wei(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).l1_gas_price_wei

    def get_l1_gas_price_in_fri(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).l1_gas_price_fri

    def get_l1_data_gas_price_in_wei(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).l1_data_gas_price_wei

    def get_l1_data_gas_price_in_fri(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).l1_data_gas_price_fri

    def get_receipts_commitment(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).receipt_commitment

    def get_l1_data_mode(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).l1_da_mode

    def get_protocol_version(self, key: MemorizerKey) -> int:
        fields = self.extract_fields(key)
        return StarknetHeader.from_memorizer_fields(fields).protocol_version
