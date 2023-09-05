from pint import UnitRegistry
# ------------------------------------------------------------------------------ 
# Unit Conversion wrapper 
# ------------------------------------------------------------------------------ 

STANDARD_GRAVITY_MPS2 = 9.80665
STANDARD_GRAVITY_FTPS2 = 32.1740

ureg = UnitRegistry()
ureg.define('psia = psi')
ureg.define('lbm = lb')

def convert(value: float, in_units: str, out_units: str):
    '''
    Converts a unit from in_units to out_units
    Compatible Strings: https://github.com/hgrecco/pint/blob/master/pint/default_en.txt
    '''
    if in_units == out_units:
        return out_units

    _u = ureg.Quantity(
        value,
        in_units
    )

    return _u.to(out_units).magnitude


def convert_many(*convert_tuple):
    '''
    Converts many units in the convert() function form
    '''
    out_list = []
    for tuple in convert_tuple:
        out_list.append(
            convert(tuple[0],tuple[1],tuple[2])
        ) 

    return out_list if len(out_list) > 0 else out_list[0]

