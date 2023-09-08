from CoolProp.CoolProp import PropsSI
from KineticKebab.common import (
    convert_many,
    circle_area_from_diameter,
    tube_inner_surface_area
)

def get_density_SI(
    pressure_Pa,
    temp_K,
    fluid     
):
    return PropsSI('D','P',pressure_Pa,'T',temp_K,fluid)


def get_density_IM(
    pressure_psia,
    temp_F,
    fluid     
):
    (
        pressure_Pa,
        temp_K
    ) = convert_many(
        (pressure_psia, 'psia', 'Pa')
        (temp_F, 'degF', 'degK')
    )
    return PropsSI('D','P',pressure_psia,'T',temp_K,fluid)
        
def get_gamma_SI(
    press_Pa,
    temp_K,
    fluid
):
    Cp = PropsSI('CPMASS','P',press_Pa,'T',temp_K,fluid)
    Cv = PropsSI('CVMASS','P',press_Pa,'T',temp_K,fluid)
    return Cp/Cv


def get_gamma_IM(
    press_psia,
    temp_F,
    fluid
):
    (
        press_Pa,
        temp_K
    ) = convert_many(
        (press_psia,'psia','Pa'),
        (temp_F,'degF','degK'),
    )
    Cp = PropsSI('CPMASS','P',press_Pa,'T',temp_K,fluid)
    Cv = PropsSI('CVMASS','P',press_Pa,'T',temp_K,fluid)
    return Cp/Cv


def get_R_specific_JpkgK(
    press_Pa,
    temp_K,
    fluid
):
    Cp = PropsSI('CPMASS','P',press_Pa,'T',temp_K,fluid)
    Cv = PropsSI('CVMASS','P',press_Pa,'T',temp_K,fluid)
    return Cp - Cv 


def get_R_sepcific_ftlbplbmR(
    press_psia,
    temp_F,
    fluid
):
    (
        press_Pa,
        temp_K
    ) = convert_many(
        (press_psia,'psia','Pa'),
        (temp_F,'degF','degK'),
    )

    return get_gamma_SI(
        press_Pa,
        temp_K,
        fluid
    )


def get_reynolds_SI(
    prssure_Pa,
    temp_K,
    flow_velocity_mps,
    charachteristic_length_m,
    fluid
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Reynolds_number
    '''

    kinematic_viscosity = PropsSI('V','P',prssure_Pa,'T',temp_K,fluid)
    return flow_velocity_mps * charachteristic_length_m / kinematic_viscosity


def pipe_flow_velocity_mps(
    id,
    flowrate,
):
    '''
    NOTE: Diameter and flowrate must have the same length units
    '''
    area_m2 = circle_area_from_diameter(id)
    return flowrate / area_m2


def pipe_full_charachteristic_length_m(
    inner_diameter_m2,
    length_m
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Characteristic_length
    '''
    volume_m3 = circle_area_from_diameter(inner_diameter_m2) * length_m
    area_m2 = tube_inner_surface_area(inner_diameter_m2 /2 , length_m) 
    return volume_m3 / area_m2     


def pipe_full_charachteristic_length_in(
    inner_diameter_in2,
    length_in
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Characteristic_length
    '''
    volume_m3 = circle_area_from_diameter(inner_diameter_in2) * length_in
    area_m2 = tube_inner_surface_area(inner_diameter_in2 /2 , length_in) 
    return volume_m3 / area_m2     

