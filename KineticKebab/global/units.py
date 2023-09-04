from pint import UnitRegistry

ureq = UnitRegistry()
ureq.define('psia = psi')


def convert(value: float, in_units: str, out_units: str):
    if in_units == out_units:
        return out_units

    _u = ureq.Quantity(
        value,
        in_units
    )

    return _u.to(out_units)
    