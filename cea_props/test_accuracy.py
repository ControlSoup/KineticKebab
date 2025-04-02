import numpy as np
from plotly_datadict.plot_wrappers import *
import os
from tqdm import tqdm
import plotly.graph_objects as go
from kinetic_kebab import KineticKebab
from create_props import CEA_SI, combos, R_JPDEGK_MOL

# ('oxygen', 'methane', (0.05, 6), (68947.6, 6.8948e+7)),

FILE_PATH = os.path.dirname(__file__)

for ox, fuel, (mr_low, mr_high), (pc_low, pc_high) in combos:
    cea = CEA_SI(ox, fuel)

    mr_range = np.linspace(mr_low, 5.5, 10)

    pc_results = []
    cea_gamma_results = []
    cea_temp_results = []
    kebab_gamma_results = []
    kebab_temp_results = []

    model: KineticKebab = KineticKebab.from_file(os.path.join(FILE_PATH, "configs/combuster.json"))
    for mr in tqdm(mr_range):
        fuel_mdot = 1 / (mr + 1) 
        model.set_value_by_name("OxMdot.cda [m^2]", (1 - fuel_mdot) / 10000.0)
        model.set_value_by_name("FuelMdot.cda [m^2]", fuel_mdot / 10000.0)
        model.debug_steady(500, False)

        pc = model.get_value_by_name("Combusty.press [Pa]")
        mol_weight, gamma = cea.get_Chamber_MolWt_gamma(pc, mr)

        cea_gamma_results.append(gamma)
        cea_temp_results.append(cea.get_Temperatures(pc, mr, frozen=1)[0])

        kebab_gamma_results.append(model.get_value_by_name("Combusty.gamma [-]"))
        kebab_temp_results.append(model.get_value_by_name("Combusty.temp [degK]"))

        pc_results.append(pc)

    # # Gamma Range
    # fig: go.Figure = go.Figure()
    # fig.add_trace(
    #     go.Scatter(
    #         x=pc_results,
    #         y=cea_temp_results,
    #         name = 'Cea'
    #     )
    # )
    # fig.add_trace(
    #     go.Scatter(
    #         x=pc_results,
    #         y=kebab_temp_results,
    #         name = 'Kebab'
    #     )
    # )
    # fig.update_layout(title = f"Temp for {ox} and {fuel}")
    # fig.update_yaxes(title = 'Pc [Pa]')
    # fig.update_xaxes(title = 'MR [-]')
    # fig.write_html(os.path.join(FILE_PATH, f"outputs/{ox}_{fuel}/{ox}_{fuel}_temp_cea_compare.html"), full_html = False)
    graph_datadict(model.datadict, x_key='sim.steady_steps [-]', show_fig=True)
