import os
from kinetic_kebab_api import KebabCli

FILE_PATH = os.path.dirname(__file__)

model = KebabCli(os.path.join(FILE_PATH, 'motion1dof.json'))
model.run(10.0)