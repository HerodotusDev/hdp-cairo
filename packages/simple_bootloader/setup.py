import setuptools

setuptools.setup(
    name="hdp_bootloader",
    version="0.1",
    packages=setuptools.find_packages(),
    zip_safe=False,
    package_data={
        "builtin_selection": ["*.cairo", "*/*.cairo"],
        "common": ["*.cairo", "*/*.cairo"],
        "common.builtin_poseidon": ["*.cairo", "*/*.cairo"],
        "lang.compiler": ["cairo.ebnf", "lib/*.cairo"],
        "bootloader": ["*.cairo", "*/*.cairo"],
    }
)