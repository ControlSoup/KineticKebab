from setuptools import setup, find_packages
import os

FILE_PATH = os.path.dirname(__file__)
NAME = "kinetic_kebab_api"
res = setup(
    name=NAME,
    version="0.0.1",
    packages=find_packages(where = ".", exclude=("tests")),
    url="",
    author="Some Joe",
    author_email="joe.burge.iii@gmail.com",
    description="Zig Sim API",
    include_package_data=True,
    package_data={
        NAME: ['kinetic_kebab']
    },
)
