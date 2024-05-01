import setuptools

setuptools.setup(
    name="hdp-cairo",
    version="0.1",
    packages=["hdp_bootloader", "tools", "tests"],
    package_dir={
        "tools": "tools",
        "tests": "tests",
        "hdp_bootloader": "packages/hdp_bootloader",
    },
    zip_safe=False,
    package_data={
        "tools": ["*/*.py"],
        "tests": ["*/*.py"],
        "hdp_bootloader": ["*.cairo", "*/*.cairo", "*/*.py"],
    },
)
