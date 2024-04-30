import setuptools

setuptools.setup(
    name="hdp-cairo",
    version="0.1",
    packages=setuptools.find_packages(),
    zip_safe=False,
    package_data={
        "packages.hdp_bootloader.bootloader": ["*.cairo", "*/*.cairo"],
        "packages.hdp_bootloader.builtin_selection": ["*.cairo", "*/*.cairo"],
    },
)
