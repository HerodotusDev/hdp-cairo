import marshmallow_dataclass
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass
from contract_bootloader.contract_class.contract_class import (
    CompiledClass,
)
from starkware.starkware_utils.validated_dataclass import (
    ValidatedMarshmallowDataclass,
)


@marshmallow_dataclass.dataclass(frozen=True)
class ContractBootloaderInput(ValidatedMarshmallowDataclass):
    compiled_class: CompiledClass = CompiledClass
