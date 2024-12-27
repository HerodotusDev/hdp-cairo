from enum import Enum
from typing import List
from marshmallow import ValidationError
import marshmallow_dataclass
from dataclasses import field
import marshmallow.fields as mfields
from contract_bootloader.contract_class.contract_class import CompiledClass
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from starkware.starkware_utils.marshmallow_dataclass_fields import (
    IntAsHex,
    Enum,
    additional_metadata,
)


@marshmallow_dataclass.dataclass(frozen=True)
class MPTProof:
    block_number: int
    proof_bytes_len: int
    proof: List[str] = field(
        metadata=additional_metadata(marshmallow_field=mfields.List(IntAsHex()))
    )


@marshmallow_dataclass.dataclass(frozen=True)
class MMRMeta:
    id: int
    size: int
    root: str
    chain_id: int
    peaks: List[str] = field(
        metadata=additional_metadata(marshmallow_field=mfields.List(IntAsHex()))
    )


@marshmallow_dataclass.dataclass(frozen=True)
class HeaderProof:
    leaf_idx: int
    mmr_path: List[str]


@marshmallow_dataclass.dataclass(frozen=True)
class Header:
    rlp: str
    proof: HeaderProof


@marshmallow_dataclass.dataclass(frozen=True)
class Account:
    address: str
    account_key: str
    proofs: List[MPTProof] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(MPTProof.Schema))
        )
    )


@marshmallow_dataclass.dataclass(frozen=True)
class Storage:
    address: str
    slot: str
    storage_key: str
    proofs: List[MPTProof] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(MPTProof.Schema))
        )
    )


@marshmallow_dataclass.dataclass(frozen=True)
class Transaction:
    key: str
    proofs: MPTProof


@marshmallow_dataclass.dataclass(frozen=True)
class Receipt:
    key: str
    proofs: MPTProof


@marshmallow_dataclass.dataclass(frozen=True)
class Proof(ValidatedMarshmallowDataclass):
    mmr_meta: MMRMeta
    headers: List[Header]
    accounts: List[Account]
    storages: List[Storage]
    transactions: List[Transaction]
    receipts: List[Receipt]


class Visibility(Enum):
    PUBLIC = "public"
    PRIVATE = "private"


class VisibilityField(mfields.Field):
    def _deserialize(self, value, attr, data, **kwargs):
        if not isinstance(value, str):
            raise ValidationError("Invalid type. Expected a string.")
        value = value.lower()
        try:
            return Visibility(value)
        except ValueError:
            raise ValidationError(f"Invalid value for Visibility enum: {value}")


@marshmallow_dataclass.dataclass(frozen=True)
class Param:
    visibility: Visibility = field(
        metadata={"marshmallow_field": VisibilityField(required=True)}
    )
    value: int = field(metadata={"marshmallow_field": IntAsHex(required=True)})


@marshmallow_dataclass.dataclass(frozen=True)
class HDPInput(ValidatedMarshmallowDataclass):
    proofs: List[Proof] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(Proof.Schema))
        )
    )
    params: List[Param] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(Param.Schema))
        )
    )
    module_class: CompiledClass


@marshmallow_dataclass.dataclass(frozen=True)
class HDPDryRunInput(ValidatedMarshmallowDataclass):
    params: List[Param] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(mfields.Nested(Param.Schema))
        )
    )
    module_class: CompiledClass
