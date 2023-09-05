# ------------------------------------------------------------------------------ 
# Rocket Propulsion Elements # 9 Equations 
# PDF Link: 
# https://ftp.idu.ac.id/wp-content/uploads/ebook/tdg/DESIGN%20SISTEM%20DAYA%20GERAK/Rocket%20Propulsion%20Elements.pdf
# ------------------------------------------------------------------------------ 
# ------------------------------------------------------------------------------ 
# Chapter 3 
# ------------------------------------------------------------------------------ 
import numpy as np
from sys import exit

from KineticKebab.common import *  


def massflow_3_24_kgps(
    At_m2,
    p1_Pa,
    kappa,
    R_specific_JpkgK,
    T1_K,
    verbose_reporting=None
):
    root_1 = np.sqrt(
        (2/(kappa + 1)) ** ((kappa + 1) / (kappa - 1))
    )
    root_2 = np.sqrt(kappa * R_specific_JpkgK * T1_K)

    massflow_kgps = At_m2 * p1_Pa * kappa * (root_1 / root_2)

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('massflow_3_24_SI') + 
            pretty_str_key_val(
                ('At_m2',At_m2),
                ('p1_Pa',p1_Pa),
                ('kappa',kappa),
                ('R_specific_JpkgK',R_specific_JpkgK),
                ('T1_K',T1_K),
                ('massflow_kgps',massflow_kgps)
            )
        )
        return massflow_kgps, report
    return massflow_kgps


def massflow_3_24_lbmps(
    At_in2,
    p1_psia,
    kappa,
    R_specific_ftlbfplbmR,
    T1_F,
    verbose_reporting=None
):
    (
        At_m2,
        p1_Pa,
        R_specific_JpkgK,
        T1_K,
    ) =  convert_many(
        (At_in2,'in^2','m^2'),
        (p1_psia,'psia','Pa'),
        (R_specific_ftlbfplbmR,'(ft*lbf)/(lbm*degR)','J/(kg*degK)'),
        (T1_F,'degF','degK')
    )

    massflow_kgps = massflow_3_24_kgps(
        At_m2,
        p1_Pa,
        kappa,
        R_specific_JpkgK,
        T1_K,
    )

    massflow_lbmps = convert(massflow_kgps,'kg/s','lbm/s')

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('massflow_3_24_lbmps') +
            pretty_str_key_val_to_convert_val(
                ('At_in2',At_in2,'At_m2',At_m2),
                ('p1_psia',p1_psia,'p1_Pa',p1_Pa),
                ('R_specific_ftlbfplbmR',R_specific_ftlbfplbmR,'R_specific_JpkgK',R_specific_JpkgK),
                ('T1_F',T1_F,'T1_K',T1_K)
            ) +
            pretty_str_key_val(
                ('kappa',kappa)
            ) + 
            pretty_str_key_val_from_convert_val(
                ('massflow_lbmps',massflow_lbmps,'massflow_kgps',massflow_kgps)
            )
        )
        return massflow_lbmps, report
    return massflow_lbmps


def force_3_29_N(
    At_m2,
    p1_Pa,
    kappa,
    p2_Pa,
    A2_m2,
    p3_Pa,
    verbose_reporting=None
):
    root_pt_a = 2 * kappa**2 / (kappa -1) 
    root_pt_b = (2 / (kappa + 1)) ** ((kappa + 1)/(kappa -1))
    root_pt_c = 1 - ((p2_Pa / p1_Pa)**((kappa - 1) / kappa))

    force_N =  At_m2 * p1_Pa * (
        np.sqrt(root_pt_a * root_pt_b * root_pt_c)
    ) +  (A2_m2 * (p2_Pa - p3_Pa))

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('force_3_29_SI') +
            pretty_str_key_val(
                ('At_m2',At_m2),
                ('p1_Pa',p1_Pa),
                ('kappa',kappa),
                ('p2_Pa',p2_Pa),
                ('A2_m2',A2_m2),
                ('p3_Pa',p3_Pa),
                ('force_N',force_N)
            )
        )
        return force_N, report
    return force_N
    

def force_3_29_lbf(
    At_in2,
    p1_psia,
    kappa,
    p2_psia,
    A2_in2,
    p3_psia,
    verbose_reporting=None
):
    
    (
        At_m2,
        p1_Pa,
        p2_Pa,
        A2_m2,
        p3_Pa,
    ) = convert_many(
        (At_in2,'in^2','m^2'),
        (p1_psia,'psia','Pa'),
        (p2_psia,'psia','Pa'),
        (A2_in2,'in^2','m^2'),
        (p3_psia,'psia','Pa')
    )

    force_N = force_3_29_N(
        At_m2,
        p1_Pa,
        kappa,
        p2_Pa,
        A2_m2,
        p3_Pa
    )

    force_lbf = convert(force_N, 'N', 'lbf')

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('force_3_29_IM') +
            pretty_str_key_val_to_convert_val(
                ('At_in2',At_in2,'At_m2',At_m2),
                ('p1_psia',p1_psia,'p1_Pa',p1_Pa),
                ('p2_psia',p2_psia,'p2_Pa',p2_Pa),
                ('At_in2',At_in2,'A2_m2',A2_m2),
                ('p3_psia',p3_psia,'p3_Pa',p3_Pa),
            ) +
            pretty_str_key_val(
                ('kappa',kappa)
            ) +
            pretty_str_key_val_from_convert_val(
                ('force_lbf',force_lbf,'force_N',force_N),
            ) 
        )
        return force_lbf, report
    return force_lbf


def thrust_coef_3_31_SI(
    F_N,
    At_m2,
    p1_Pa,
    verbose_reporting=None
):

    thrust_coef = F_N / (At_m2 * p1_Pa)

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('thrust_coef_3_31_SI') +
            pretty_str_key_val(
                ('F_N',F_N),
                ('At_m2',At_m2),
                ('p1_Pa',p1_Pa),
                ('thrust_coef',thrust_coef)
            )
        )
        return thrust_coef, report
    return thrust_coef 


def thrust_coef_3_31_IM(
    F_lbf,
    At_in2,
    p1_psia,
    verbose_reporting=None
):
    (
        F_N,
        At_m2,
        p1_Pa,
    ) = convert_many(
        (F_lbf,'lbf','N'),
        (At_in2,'in^2','m^2'),
        (p1_psia,'psia','Pa'),
    )

    thrust_coef = thrust_coef_3_31_SI(
        F_N,
        At_m2,
        p1_Pa
    ) 

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('thrust_coef_3_31_IM') +
            pretty_str_key_val_to_convert_val(
                ('F_lbf',F_lbf,'F_N',F_N),
                ('At_in2',At_in2,'At_m2',At_m2),
                ('p1_psia',p1_psia,'p1_Pa',p1_Pa)
            ) + 
            pretty_str_key_val(
                ('thrust_coef',thrust_coef)
            ) 
        )
        return thrust_coef,report
    return thrust_coef 


def small_diameter_throat_press_correction(At,A2,verbose_reporting=None):
    curr_area_ratio = At / A2
    if  curr_area_ratio > 3.5:
        print("   ERROR| Data does no include area_ratios > 3.5")
        exit(1)

    area_ratio = [3.5,2.0,1.0]
    throat_press_percent = [99,96,81.]
    throat_press_correction_percent = np.interp(curr_area_ratio,area_ratio,throat_press_percent)/100

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('small_diameter_throat_press_correction') +
            pretty_str_key_val(
                ('area_ratio',curr_area_ratio),
                ('throat_press_correction_percent',throat_press_correction_percent),
            )
        )
        return throat_press_correction_percent, report
    return throat_press_correction_percent


def small_diameter_thrust_correction(At,A2,verbose_reporting=None):
    curr_area_ratio = At / A2
    if  curr_area_ratio > 3.5:
        print("   ERROR| Data does no include area_ratios > 3.5")
        exit(1)

    area_ratio = [3.5,2.0,1.0]
    thrust_reduction_percent = [1.5,5,19.5]
    throat_press_correction_percent = 1 - ( 
        np.interp(curr_area_ratio,area_ratio,thrust_reduction_percent) / 100 
    )

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('small_diameter_thrust_correction') +
            pretty_str_key_val(
                ('area_ratio',curr_area_ratio),
                ('thrust_correction_percent',throat_press_correction_percent),
            )
        )
        return throat_press_correction_percent, report 
    return throat_press_correction_percent


def small_diameter_isp_correction(At,A2,verbose_reporting=None):
    curr_area_ratio = At / A2
    if  curr_area_ratio > 3.5:
        print("   ERROR| Data does no include area_ratios > 3.5")
        exit(1)

    area_ratio = [3.5,2.0,1.0]
    isp_reduction = [0.31,0.55,1.34]
    isp_correction_percent = 1 - (
        np.interp(curr_area_ratio,area_ratio,isp_reduction) / 100
    )

    if verbose_reporting is not None:
        report = (
            pretty_fcn_name('small_diameter_isp_correction') +
            pretty_str_key_val(
                ('area_ratio',curr_area_ratio),
                ('isp_correction_percent',isp_correction_percent),
            )
        )
        return isp_correction_percent, report
    return isp_correction_percent