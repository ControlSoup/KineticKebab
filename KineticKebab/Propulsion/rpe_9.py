# ------------------------------------------------------------------------------ 
# Rocket Propulsion Elements # 9 Equations 
# PDF Link: 
# https://ftp.idu.ac.id/wp-content/uploads/ebook/tdg/DESIGN%20SISTEM%20DAYA%20GERAK/Rocket%20Propulsion%20Elements.pdf
# ------------------------------------------------------------------------------ 
import numpy as np


def force_3_29_SI(
    At_m,
    p1_Pa,
    kappa,
    p2_Pa,
    A2_m,
    p3_Pa,
    verbose_printing=None
):
    root_pt_a = 2 * kappa**2 / (kappa -1) 
    root_pt_b = (2 / (kappa + 1)) ** ((kappa + 1)/(kappa -1))
    root_pt_c = 1 - ((p2_Pa / p1_Pa)**(kappa - 1 / kappa))

    force_N =  At_m * p1_Pa * np.sqrt(root_pt_a * root_pt_b * root_pt_c) * (p2_Pa - p3_Pa)

    if verbose_printing:
        pass
