from typing import List
import marshmallow_dataclass
from dataclasses import field
import marshmallow.fields as mfields
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from starkware.starkware_utils.validated_dataclass import (
    ValidatedMarshmallowDataclass,
)
from starkware.starkware_utils.marshmallow_dataclass_fields import (
    IntAsHex,
    additional_metadata,
)


@marshmallow_dataclass.dataclass(frozen=True)
class Module(ValidatedMarshmallowDataclass):
    class_hash: int = field(
        metadata=additional_metadata(marshmallow_field=IntAsHex(required=True))
    )
    inputs: List[int] = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.List(IntAsHex(), required=True)
        )
    )
