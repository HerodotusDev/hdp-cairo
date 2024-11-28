from setuptools import setup
from setuptools.command.install import install
from pathlib import Path

# Read version from version.py
version = {}
with open("version.py") as fp:
    exec(fp.read(), version)

this_directory = Path(__file__).parent
long_description = (this_directory / "package.md").read_text()


class PostInstallCommand(install):
    """Custom post-installation for installation mode."""

    def run(self):
        install.run(self)


# Read the requirements from the requirements.txt file
with open("tools/make/requirements.txt") as requirements_file:
    requirements = requirements_file.read().splitlines()

setup(
    name="hdp-cairo-dev",
    long_description=long_description,
    long_description_content_type="text/markdown",
    version=version["__version__"],
    packages=[
        "tools.py",
        "tools.py.providers",
        "tools.py.types",
        "tools.py.types.evm",
        "tools.py.types.starknet",
        "tools.py.providers.evm",
        "tools.py.providers.starknet",
        "contract_bootloader",
        "contract_bootloader.contract_class",
        "contract_bootloader.dryrun_syscall_memorizer_handler",
        "contract_bootloader.dryrun_syscall_memorizer_handler.evm",
        "contract_bootloader.dryrun_syscall_memorizer_handler.starknet",
        "contract_bootloader.memorizer",
        "contract_bootloader.memorizer.evm",
        "contract_bootloader.memorizer.starknet",
        "contract_bootloader.syscall_memorizer_handler",
        "contract_bootloader.syscall_memorizer_handler.evm",
        "contract_bootloader.syscall_memorizer_handler.starknet",
    ],
    install_requires=requirements,
    package_dir={
        "tools.py": "tools/py",
        "contract_bootloader": "src/contract_bootloader",
    },
    zip_safe=False,
    package_data={
        "tools.py": ["**/*.py"],
        "contract_bootloader": [
            "*.cairo",
            "*/*.cairo",
            "*/*.py",
            "**/*.py",
            "**/*.cairo",
        ],
    },
    cmdclass={"install": PostInstallCommand},
    develop=True,
    options={
        "develop": {
            "build_dir": "build",
        }
    },
)
