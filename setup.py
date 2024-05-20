import os
import shutil
import sysconfig
from setuptools import setup
from setuptools.command.install import install


class PostInstallCommand(install):
    """Custom post-installation for installation mode."""

    def run(self):
        # Run the standard install process first
        install.run(self)
        # Perform additional post-installation steps
        self.copy_binary()

    def copy_binary(self):
        # Path to the binary in the package
        package_binary_path = os.path.join(
            os.path.dirname(__file__), "build", "cairo1-run"
        )
        # Path to the virtualenv bin directory
        install_binary_path = os.path.join(sysconfig.get_path("scripts"), "cairo1-run")

        # Copy the binary
        shutil.copyfile(package_binary_path, install_binary_path)
        # Make the binary executable
        os.chmod(install_binary_path, 0o755)


# Read the requirements from the requirements.txt file
with open("tools/make/requirements.txt") as requirements_file:
    requirements = requirements_file.read().splitlines()

setup(
    name="hdp-cairo-dev",
    version="0.0.1",
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
