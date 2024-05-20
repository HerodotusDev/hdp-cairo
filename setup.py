from setuptools import setup
from setuptools.command.install import install

from pathlib import Path
this_directory = Path(__file__).parent
long_description = (this_directory / "package.md").read_text()


class PostInstallCommand(install):
    """Custom post-installation for installation mode."""

    def run(self):
        # Run the standard install process first
        install.run(self)


# Read the requirements from the requirements.txt file
with open("tools/make/requirements.txt") as requirements_file:
    requirements = requirements_file.read().splitlines()

setup(
    name="hdp-cairo-dev",
    long_description=long_description,
    long_description_content_type='text/markdown',
    version="0.0.2",
    packages=["hdp_bootloader", "tools", "compiled_cairo1_modules"],
    install_requires=requirements,
    package_dir={
        "tools": "tools",
        "hdp_bootloader": "packages/hdp_bootloader",
        "compiled_cairo1_modules": "src/cairo1",
    },
    zip_safe=False,
    package_data={
        "tools": ["*/*.py"],
        "hdp_bootloader": ["*.cairo", "*/*.cairo", "*/*.py"],
        "compiled_cairo1_modules": [
            "simple_linear_regression/target/dev/simple_linear_regression.sierra.json"
        ],
    },
    cmdclass={"install": PostInstallCommand},
)
