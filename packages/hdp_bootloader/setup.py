import setuptools

setuptools.setup(
    name="hdp_bootloader",
    version="0.2",
    packages=setuptools.find_packages(),
    zip_safe=False,
    package_data={
        "bootloader": ["*.cairo", "*/*.cairo"],
        "builtin_selection": ["*.cairo", "*/*.cairo"],
    },
)
