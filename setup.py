from setuptools import setup, find_packages

# Read the requirements from the requirements.txt file
with open('tools/make/requirements.txt') as f:
    requirements = f.read().splitlines()

setup(
    name="hdp-cairo",
    version="0.0.1",
    packages=["hdp_bootloader", "tools", "hdp_cairo_programs"],
    install_requires=requirements,
    package_dir={
        "tools": "tools",
        "hdp_cairo_programs": "build/compiled_cairo_files",
        "hdp_bootloader": "packages/hdp_bootloader",
    },
    zip_safe=False,
    package_data={
        "tools": ["*/*.py"],
        "hdp_cairo_programs": ["hdp.json", "simple_linear_regression.sierra.json"],
        "hdp_bootloader": ["*.cairo", "*/*.cairo", "*/*.py"],
    },
)