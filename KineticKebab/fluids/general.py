
from CoolProp.CoolProp import PropsSI
from KineticKebab.common import convert_many

def get_gamma_SI(
    press_Pa,
    temp_K,
    fluid
):
    Cp = PropsSI('cp',press_Pa,temp_K,fluid)
    Cv = PropsSI('cv',press_Pa,temp_K,fluid)
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
