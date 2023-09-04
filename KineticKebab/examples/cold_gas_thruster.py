import numpy as np
from KineticKebab.fluids import * 
from KineticKebab.common import *
from KineticKebab.propulsion.rpe_9 import * 
from KineticKebab.propulsion.nozzels import * 

def main():


    At_in2 = 0.25
    p1_psia = 114.7
    gamma = get_gamma_IM(
        14.696,
        70,
        'air'
    )
    p2_psia = 14.696 # Assume perfect expansion 
    A2_in2 = 0.5
    p3_psia = 14.696

    force_lbf = force_3_29_IM(
        At_in2,
        p1_psia,
        gamma,
        p2_psia, 
        A2_in2,
        p3_psia,
        verbose_printing=True
    )
    thrust_reduction_coef = small_diameter_thrust_correction(
        At=At_in2,
        A2=At_in2,
        verbose_printing=True
    )
    small_diameter_throat_press_correction(
        At=At_in2,
        A2=At_in2,
        verbose_printing=True
    )
    small_diameter_specific_impulse_correction(
        At=At_in2,
        A2=At_in2,
        verbose_printing=True
    )
    cf = thrust_coef_3_31_IM(
        force_lbf * (thrust_reduction_coef),
        At_in2,
        p1_psia,
        verbose_printing=True
    )


    nozzel = Standard15degIM(
        throat_area_in2=At_in2,
        exit_area_in2=A2_in2
    )
    print(nozzel.get_report_IM(places=6))
    nozzel.export_svg('nozzel_test','')

if __name__ == '__main__':
    main()
