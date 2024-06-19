from typing import List
import marshmallow_dataclass
from dataclasses import field
import marshmallow.fields as mfields
from contract_bootloader.contract_class.contract_class import CompiledClass
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from starkware.starkware_utils.marshmallow_dataclass_fields import (
    IntAsHex,
    additional_metadata,
)


@marshmallow_dataclass.dataclass(frozen=True)
class Module(ValidatedMarshmallowDataclass):
    inputs: List[int] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(IntAsHex(), required=True)
        )
    )
    module_class: CompiledClass
