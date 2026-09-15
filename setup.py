from setuptools import find_namespace_packages, setup

setup(
    name="soulboy-ascend-boost",
    version="0.1.0",
    package_dir={"": "python"},
    packages=find_namespace_packages(where="python"),
    python_requires=">=3.10",
    install_requires=["torch"],
)
