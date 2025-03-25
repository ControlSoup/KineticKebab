from rocketcea.cea_obj_w_units import CEA_Obj
import plotly.graph_objects as go
import numpy as np
import os


FILE_PATH = os.path.dirname(__file__)
R_JPDEGK_MOL = 8.31446261815324

def CEA_SI(ox, fuel):
    # Creates a CEA_Objectin SI units you would expect
    if fuel == "IPA":
        fuel = "Isopropanol"

    if fuel == 'ethanol':
        fuel = 'ETHANOL'
    
    if ox == "oxygen":
        ox = "LOX"


    return CEA_Obj(
        oxName=ox,
        fuelName=fuel,
        useFastLookup=0,
        makeOutput=0,
        isp_units="sec",
        cstar_units="m/sec",
        pressure_units="Pa",
        temperature_units="degK",
        sonic_velocity_units="m/sec",
        enthalpy_units="J/kg",
        density_units="kg/m^3",
        specific_heat_units="J/kg degK",
        viscosity_units="millipoise",
        thermal_cond_units="mcal/cm-K-s",
        fac_CR=None,
        make_debug_prints=False,
    )

def python_to_zig_str(array: np.array, type: str):
    _str = f'[{len(array)}]{type}' + '{'
    for i in array:
        _str += i
    
    return _str + '};'

if __name__ == '__main__':
    combos = [
        ('oxygen', 'ethanol', (0.1, 6), (68947.6, 6.8948e+7))
    ]

    pc_count = 100
    mr_count = 100

    for ox, fuel, (mr_start, mr_end), (p_start, p_end) in combos:

        if not os.path.exists(os.path.join(FILE_PATH, f'plots/{ox}_{fuel}/')):
            os.makedirs(os.path.join(FILE_PATH, f'plots/{ox}_{fuel}/'))

        cea = CEA_SI(ox, fuel)

        mr_range = np.linspace(mr_start, mr_end, mr_count)
        pc_range = np.linspace(p_start, p_end, pc_count)

        gamma_map = []
        sp_r_map = []
        temp_map = []


        for pc in pc_range:
            gamma_range = []
            sp_r_range = []
            temp_range = []
            for mr in mr_range:
                mol_weight, gamma = cea.get_Chamber_MolWt_gamma(pc, mr)
                mol_weight = mol_weight / 1000

                gamma_range.append(gamma)
                sp_r_range.append(mol_weight / R_JPDEGK_MOL)
                temp_range.append(cea.get_Temperatures(pc, mr)[0])

            gamma_map.append(gamma_range)
            sp_r_map.append(sp_r_range)
            temp_map.append(temp_range)

        

        # Gamma Range
        fig: go.Figure = go.Figure(data =
            go.Contour(
                y = pc_range,
                x = mr_range,
                z = gamma_map,
                contours=dict(
                    coloring ='heatmap',
                    showlabels = True, 
                    labelfont = dict( 
                        size = 12,
                        color = 'white',
                    )
                ),
                colorbar=dict(
                    title=dict(text='Gamma [-]', side='right')
                )
            )
        )
        fig.update_layout(title = f"Gamma for {ox} and {fuel}")
        fig.update_yaxes(title = 'Pc [Pa]')
        fig.update_xaxes(title = 'MR [-]')
        fig.write_html(os.path.join(FILE_PATH, f"plots/{ox}_{fuel}/{ox}_{fuel}_gamma.html"), full_html = False)

        # Sp_R Range
        fig: go.Figure = go.Figure(data =
            go.Contour(
                y = pc_range,
                x = mr_range,
                z = sp_r_map,
                contours=dict(
                    coloring ='heatmap',
                    showlabels = True, 
                    labelfont = dict( 
                        size = 12,
                        color = 'white',
                    )
                ),
                colorbar=dict(
                    title=dict(text='Specific R [J/kgK]', side='right')
                )
            )
        )
        fig.update_layout(title = f"Specific R for {ox} and {fuel}")
        fig.update_yaxes(title = 'Pc [Pa]')
        fig.update_xaxes(title = 'MR [-]')
        fig.write_html(os.path.join(FILE_PATH, f"plots/{ox}_{fuel}/{ox}_{fuel}_sp_r.html"), full_html = False)

        # Temp Range
        fig: go.Figure = go.Figure(data =
            go.Contour(
                y = pc_range,
                x = mr_range,
                z = temp_map,
                contours=dict(
                    coloring ='heatmap',
                    showlabels = True, 
                    labelfont = dict( 
                        size = 12,
                        color = 'white',
                    )
                ),
                colorbar=dict(
                    title=dict(text='Temp [degK]', side='right')
                )
            )
        )
        fig.update_layout(title = f"Temp for {ox} and {fuel}")
        fig.update_yaxes(title = 'Pc [Pa]')
        fig.update_xaxes(title = 'MR [-]')
        fig.write_html(os.path.join(FILE_PATH, f"plots/{ox}_{fuel}/{ox}_{fuel}_temp.html"), full_html = False)