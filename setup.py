from setuptools import setup, find_packages

setup(
    name='KineticKebab',
    version='0.0.1',
    url='https://github.com/mypackage.git',
    author='Joe Wilson',
    author_email='joe.burge.iii@gmail.com',
    description='Engineering analysis repository for personal projects',
    packages=find_packages(),    
    install_requires=[
        'numpy >= 1.11.1',
        'matplotlib >= 1.5.1'
    ],
)