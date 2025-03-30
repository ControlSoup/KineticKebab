import numpy as np
import os
from kinetic_kebab import KineticKebab
from create_props import CEA_SI, combos, R_JPDEGK_MOL

# ('oxygen', 'methane', (0.05, 6), (68947.6, 6.8948e+7)),

FILE_PATH = os.path.dirname(__file__)

for ox, fuel, (mr_low, mr_high), (pc_low, pc_high) in combos:
    cea = CEA_SI(ox, fuel)

    mr_range = np.linspace(mr_low + 0.3, mr_high - 0.5, 10)
    pc_mult = np.linspace(1, 50, 50)

    pc_results = []
    cea_gamma_results = []
    cea_temp_results = []
    kebab_gamma_results = []
    kebab_temp_results = []

    for mult in pc_mult:
        for mr in mr_range:
            ox_mdot = mr
            model: KineticKebab = KineticKebab.from_file(os.path.join(FILE_PATH, "configs/combuster.json"))
            model.set_value_by_name("OxMdot.mdot [kg/s]", ox_mdot)
            model.set_value_by_name("FuelMdot.mdot [kg/s]", 1 - ox_mdot)
            model.set_value_by_name("Dump.cda [m^2]", model.get_value_by_name("Dump.cda [m^2]") * mult)
            model.solve_steady()

            pc = model.get_value_by_name("Combusty.press [Pa]")
            mol_weight, gamma = cea.get_Chamber_MolWt_gamma(pc, mr)

            pc_results.append(pc)
            cea_gamma_results.append(gamma)
            cea_temp_results.append(cea.get_Temperatures(pc, mr, frozen=1)[0])

            kebab_gamma_results.append(model.get_value_by_name("Combusty.gamma [-]"))
            kebab_temp_results.append(model.get_value_by_name("Combusty.temp [degK]"))

    print(kebab_temp_results[:3])
    print(cea_temp_results[:3])









