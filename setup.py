from setuptools import setup, find_packages
import os

FILE_PATH = os.path.dirname(__file__)

res = setup(
    name="kinetic_kebab_api",
    version="0.0.1",
    packages=find_packages(where = "."),
    url="",
    author="Some Joe",
    author_email="joe.burge.iii@gmail.com",
    description="Zig Sim API",
)
