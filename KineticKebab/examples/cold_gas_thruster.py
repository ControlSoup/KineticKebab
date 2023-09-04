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

    force_lbf, report_force = force_3_29_lbf(
        At_in2,
        p1_psia,
        gamma,
        p2_psia, 
        A2_in2,
        p3_psia,
        verbose_reporting=True
    )
    thrust_reduction_coef, thrust_reduction_report = small_diameter_thrust_correction(
        At=At_in2,
        A2=At_in2,
        verbose_reporting=True
    )
    _,report_throat_pres_coef =  small_diameter_throat_press_correction(
        At=At_in2,
        A2=At_in2,
        verbose_reporting=True
    )
    _, report_specific_impulse = small_diameter_isp_correction(
        At=At_in2,
        A2=At_in2,
        verbose_reporting=True
    )

    cf, report_cf = thrust_coef_3_31_IM(
        force_lbf * (thrust_reduction_coef),
        At_in2,
        p1_psia,
        verbose_reporting=True
    )


    nozzel = Standard15degIM(
        throat_area_in2=At_in2,
        exit_area_in2=A2_in2
    )

    # Print Report
    print(
        report_force +
        thrust_reduction_report +
        report_throat_pres_coef +
        report_specific_impulse +
        report_cf +
        nozzel.get_report_IM(places=6)
    )

if __name__ == '__main__':
    main()
