from setuptools import setup, find_packages

# Auto generate install reqs

with open('requirements.txt','r') as f:
    REQ_LINES = list(f.readlines()) 

for i in REQ_LINES:
    i += ','

setup(
    name='KineticKebab',
    version='0.0.1',
    url='',
    author='Joe Wilson',
    author_email='joe.burge.iii@gmail.com',
    description='Engineering analysis repository for personal projects',
    packages=find_packages(exclude='KineticKebab.test'),    
    install_requires=REQ_LINES,
)