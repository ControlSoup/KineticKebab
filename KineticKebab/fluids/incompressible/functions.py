import numpy as np


def niazkars_solution(
    relative_roughness,
    reynolds_number
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Darcy_friction_factor_formulae#Colebrook%E2%80%93White_equation
    '''
    A = -2 * np.log(
        (relative_roughness / 3.7) + 
        (4.5547 / (reynolds_number**0.8784))
    )
    B = -2 * np.log(
        (relative_roughness / 3.7) + 
        (2.51 * A / reynolds_number)
    )
    C = -2 * np.log(
        (relative_roughness / 3.7) + 
        (2.51 * B / reynolds_number)
    )
    
    one_over_root_ff = A - ((B-A)**2 / (C - (2 *B) + A))

    ff = (1 / one_over_root_ff)**2
    
    return ff
    
def darcy_weisbach_dp_Pa(
    friction_factor,
    density_kgpm3,
    flow_velocity_mps,
    hydraulic_diamter_m,
    length_m
):
    '''
    Source:
        https://en.wikipedia.org/wiki/Darcy%E2%80%93Weisbach_equation
    '''

    dp_Pa = (
        length_m * friction_factor * 
        density_kgpm3 * flow_velocity_mps**2 / 
        (2 * hydraulic_diamter_m)
    )
    
    return dp_Pa

