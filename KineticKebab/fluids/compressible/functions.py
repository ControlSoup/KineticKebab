# ------------------------------------------------------------------------------ 
# Functions to help with Compressible gas analysis 
# ------------------------------------------------------------------------------ 

import numpy as np
from KineticKebab.common import *
from KineticKebab.fluids.general import *

def comp_critical_pressure(
    upstrm_stag_press,
    gamma
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Choked_flow
    '''
    gamma_component = (2 / (gamma + 1)) ** (gamma / (gamma - 1)) 
    ciritcal_press = upstrm_stag_press * gamma_component

    return ciritcal_press 

def comp_is_choked(
    upstrm_press,
    downstrm_press,
    gamma
):
    '''
    Returns if the compressible fluid conditions are choked
    Source: 
        https://en.wikipedia.org/wiki/Choked_flow
    '''

    critical_press = comp_critical_pressure(
        upstrm_press,
        gamma
    )

    return True if downstrm_press < critical_press else False

def comp_orifice_mdot_kgps(
    Cd,
    orifice_area_m2,
    upstrm_press_Pa,
    upstrm_temp_K,
    downstrm_press_Pa,
    fluid: str,
    verbose_reporting = None
):
    '''
    Source: 
        https://en.wikipedia.org/wiki/Orifice_plate
    '''

    Cda_m2 = Cd * orifice_area_m2
    gamma = get_gamma_SI(
        upstrm_press_Pa,
        upstrm_temp_K,
        fluid
    ) 
    upstrm_density_kgpm3 = get_density_SI(
        upstrm_press_Pa,
        upstrm_temp_K,
        fluid
    )
    is_choked = comp_is_choked(
        upstrm_press_Pa,
        downstrm_press_Pa,
        gamma
    )

    if is_choked:
        # Choked flow equation
        gamma_choked_comp = (2 / (gamma + 1))**((gamma + 1) / (gamma - 1))
        mdot_kgps = Cda_m2 * np.sqrt(
            gamma * upstrm_density_kgpm3 * upstrm_press_Pa * gamma_choked_comp 
        )
    else:
        # UnChoked flow equation
        gamma_UNchoked_comp = (gamma / (gamma - 1))
        pressure_comp_1 = (downstrm_press_Pa / upstrm_press_Pa)**(2 / gamma)
        pressure_comp_2 = (downstrm_press_Pa / upstrm_press_Pa)**((gamma + 1) / gamma)
        mdot_kgps = Cda_m2 * np.sqrt(
            2 * upstrm_density_kgpm3 * upstrm_press_Pa * gamma_UNchoked_comp * 
            (pressure_comp_1 - pressure_comp_2)
        )
    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('comp_orifice_mdot_kgps') +
            pretty_str_key_val(
                ('fluid',fluid),
                ('Cd',Cd),
                ('orifice_area_m2',orifice_area_m2),
                ('upstrm_press_Pa',upstrm_press_Pa),
                ('upstrm_temp_K',upstrm_temp_K),
                ('downstrm_press_Pa',downstrm_press_Pa),
                ('mdot_kgps',mdot_kgps)
            )
        )
        return mdot_kgps, report
    return mdot_kgps 


def comp_orifice_mdot_lbmps(
    Cd,
    orifice_area_in2,
    upstrm_press_psia,
    upstrm_temp_F,
    downstrm_press_psi,
    fluid: str,
    verbose_reporting = None
):

    (
        orifice_area_m2,
        upstrm_press_Pa,
        upstrm_temp_K,
        downstrm_press_Pa
    ) = convert_many(
        (orifice_area_in2,'in^2','m^2'),
        (upstrm_press_psia,'psia','Pa'),
        (upstrm_temp_F,'degF','degK'),
        (downstrm_press_psi,'psia','Pa')
    )
    mdot_kgps = comp_orifice_mdot_kgps(
        Cd,
        orifice_area_m2,
        upstrm_press_Pa,
        upstrm_temp_K,
        downstrm_press_Pa,
        fluid
    )

    mdot_lbmps = convert(mdot_kgps,'kg/s','lbm/s') 

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('comp_orifice_mdot_lbmps') +
            pretty_str_key_val(
                ('fluid',fluid),
                ('Cd',Cd)
            ) +
            pretty_str_key_val_to_convert_val(
                ('orifice_area_in2',orifice_area_in2,'orifice_area_m2',orifice_area_m2),
                ('upstrm_press_psia',upstrm_press_psia,'upstrm_press_Pa',upstrm_press_Pa),
                ('upstrm_temp_F',upstrm_temp_F,'upstrm_temp_K',upstrm_temp_K),
                ('downstrm_press_psi',downstrm_press_psi,'downstrm_press_Pa',downstrm_press_Pa)
            ) +
            pretty_str_key_val_from_convert_val(
                ('mdot_lbmps',mdot_lbmps,'mdot_kgps',mdot_kgps)
            )
        )
        return mdot_lbmps, report
    return mdot_lbmps 
