from typing import List, Optional, Union
import marshmallow_dataclass
from dataclasses import dataclass, field
import marshmallow.fields as mfields
from contract_bootloader.objects import Module
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from starkware.starkware_utils.marshmallow_dataclass_fields import (
    IntAsHex,
    additional_metadata,
)


@dataclass(frozen=True)
class ProcessedHeaderProof:
    leaf_idx: int
    mmr_path: List[str]


@dataclass(frozen=True)
class ProcessedMPTProof:
    block_number: int
    proof: List[str]


@dataclass(frozen=True)
class MMRMeta:
    id: int
    root: str
    size: int
    peaks: List[str] = field(
        metadata=additional_metadata(marshmallow_field=mfields.List(IntAsHex()))
    )


@dataclass(frozen=True)
class ProcessedHeader:
    rlp: str
    proof: ProcessedHeaderProof


@dataclass(frozen=True)
class ProcessedAccount:
    address: str
    account_key: str
    proofs: List[ProcessedMPTProof]


@dataclass(frozen=True)
class ProcessedStorage:
    address: str
    slot: str
    storage_key: str
    proofs: List[ProcessedMPTProof]


@dataclass(frozen=True)
class ProcessedTransaction:
    key: str
    block_number: int
    proof: List[str]


@dataclass(frozen=True)
class ProcessedReceipt:
    key: str
    block_number: int
    proof: List[str]


@marshmallow_dataclass.dataclass(frozen=True)
class ProcessedBlockProofs(ValidatedMarshmallowDataclass):
    mmr_meta: MMRMeta
    headers: List[ProcessedHeader]
    accounts: List[ProcessedAccount]
    storages: List[ProcessedStorage]
    transactions: List[ProcessedTransaction]
    transaction_receipts: List[ProcessedReceipt]


@dataclass(frozen=True)
class ProcessedDatalakeCompute:
    task_bytes_len: int
    encoded_task: List[int] = field(
        metadata=additional_metadata(marshmallow_field=mfields.List(IntAsHex()))
    )
    datalake_bytes_len: int
    encoded_datalake: List[int] = field(
        metadata=additional_metadata(marshmallow_field=mfields.List(IntAsHex()))
    )
    datalake_type: int
    property_type: int


@dataclass(frozen=True)
class DatalakeTask:
    datalake_compute: ProcessedDatalakeCompute


@dataclass(frozen=True)
class ModuleTask:
    module: Module


@marshmallow_dataclass.dataclass(frozen=True)
class InputTask(ValidatedMarshmallowDataclass):
    task: Union[DatalakeTask, ModuleTask] = field(
        metadata=additional_metadata(marshmallow_field=mfields.Raw())
    )


@marshmallow_dataclass.dataclass(frozen=True)
class RunnerInput(ValidatedMarshmallowDataclass):
    task_root: int = field(metadata=additional_metadata(marshmallow_field=IntAsHex()))
    result_root: Optional[int] = field(
        default=None, metadata=additional_metadata(marshmallow_field=IntAsHex())
    )
    proofs: ProcessedBlockProofs
    tasks: List[InputTask] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(InputTask))
        )
    )
