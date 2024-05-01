import tempfile
import subprocess
import dataclasses
from abc import abstractmethod
from dataclasses import field
from typing import ClassVar, Dict, Optional, Type
import marshmallow
import marshmallow.fields as mfields
import marshmallow_dataclass
from marshmallow_oneofschema import OneOfSchema
from starkware.cairo.lang.compiler.program import Program, ProgramBase, StrippedProgram
from starkware.cairo.lang.vm.cairo_pie import CairoPie
from starkware.starkware_utils.marshmallow_dataclass_fields import additional_metadata
from starkware.starkware_utils.validated_dataclass import ValidatedMarshmallowDataclass


class TaskSpec(ValidatedMarshmallowDataclass):
    """
    Contains task's specification.
    """

    @abstractmethod
    def load_task(self, memory=None, args_start=None, args_len=None) -> "Task":
        """
        Returns the corresponding task.
        """


class Task:
    @abstractmethod
    def get_program(self) -> ProgramBase:
        """
        Returns the task's Cairo program.
        """


@marshmallow_dataclass.dataclass(frozen=True)
class RunProgramTask(TaskSpec, Task):
    TYPE: ClassVar[str] = "RunProgramTask"
    program: Program
    program_input: dict
    use_poseidon: bool

    def get_program(self) -> Program:
        return self.program

    def load_task(self, memory=None, args_start=None, args_len=None) -> "Task":
        return self


@marshmallow_dataclass.dataclass(frozen=True)
class CairoPiePath(TaskSpec):
    TYPE: ClassVar[str] = "CairoPiePath"
    path: str
    use_poseidon: bool

    def load_task(self, memory=None, args_start=None, args_len=None) -> "CairoPieTask":
        """
        Loads the PIE to memory.
        """
        return CairoPieTask(
            cairo_pie=CairoPie.from_file(self.path), use_poseidon=self.use_poseidon
        )


@marshmallow_dataclass.dataclass(frozen=True)
class Cairo1ProgramPath(TaskSpec):
    TYPE: ClassVar[str] = "Cairo1ProgramPath"
    path: str
    use_poseidon: bool

    def load_task(self, memory=None, args_start=None, args_len=None) -> "CairoPieTask":
        """
        Builds and Loads the PIE to memory.
        """
        with tempfile.NamedTemporaryFile() as cairo_pie_file:
            cairo_pie_file_path = cairo_pie_file.name

            args = [memory[args_start + i] for i in range(args_len)]
            formatted_args = f'[{" ".join(map(str, args))}]'

            subprocess.run(
                [
                    "cairo1-run",
                    self.path,
                    "--layout",
                    "all_cairo",
                    "--args",
                    formatted_args,
                    "--cairo_pie_output",
                    cairo_pie_file_path,
                    "--append_return_values",
                ],
                check=True,
            )

            return CairoPieTask(
                cairo_pie=CairoPie.from_file(cairo_pie_file_path),
                use_poseidon=self.use_poseidon,
            )


@marshmallow_dataclass.dataclass(frozen=True)
class CairoSierra(TaskSpec):
    TYPE: ClassVar[str] = "CairoSierra"
    path: str
    use_poseidon: bool

    def load_task(self, memory=None, args_start=None, args_len=None) -> "CairoPieTask":
        """
        Builds and Loads the PIE to memory.
        """
        with tempfile.NamedTemporaryFile() as cairo_pie_file:
            cairo_pie_file_path = cairo_pie_file.name

            args = [memory[args_start + i] for i in range(args_len)]
            formatted_args = f'[{" ".join(map(str, args))}]'

            subprocess.run(
                [
                    "cairo1-run",
                    self.path,
                    "--layout",
                    "all_cairo",
                    "--args",
                    formatted_args,
                    "--cairo_pie_output",
                    cairo_pie_file_path,
                    "--append_return_values",
                ],
                check=True,
            )

            return CairoPieTask(
                cairo_pie=CairoPie.from_file(cairo_pie_file_path),
                use_poseidon=self.use_poseidon,
            )


class TaskSchema(OneOfSchema):
    """
    Schema for Task/CairoPiePath/Cairo1ProgramPath/CairoSierra
    OneOfSchema adds a "type" field.
    """

    type_schemas: Dict[str, Type[marshmallow.Schema]] = {
        RunProgramTask.TYPE: RunProgramTask.Schema,
        CairoPiePath.TYPE: CairoPiePath.Schema,
        Cairo1ProgramPath.TYPE: Cairo1ProgramPath.Schema,
        CairoSierra.TYPE: CairoSierra.Schema,
    }

    def get_obj_type(self, obj):
        return obj.TYPE


@dataclasses.dataclass(frozen=True)
class CairoPieTask(Task):
    cairo_pie: CairoPie
    use_poseidon: bool

    def get_program(self) -> StrippedProgram:
        return self.cairo_pie.program


@marshmallow_dataclass.dataclass(frozen=True)
class SimpleBootloaderInput(ValidatedMarshmallowDataclass):
    task: TaskSpec = field(
        metadata=additional_metadata(
            marshmallow_field=mfields.Nested(TaskSchema)
        )
    )
    fact_topologies_path: Optional[str]

    # If true, the bootloader will put all the outputs in a single page, ignoring the
    # tasks' fact topologies.
    single_page: bool
