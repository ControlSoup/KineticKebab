import unittest
from KineticKebab.fluids.compressible import *
from KineticKebab.fluids.general import *

class FluidsCompressibleTest(unittest.TestCase):

    def test_orifice_choked_mdot(self):
        print(f'\n==================== {FluidsCompressibleTest.__name__} ===================\n')
        Cd = 0.5
        orifice_area_m2 = 0.05
        upstrm_press_Pa = 300000
        upstrm_temp_K = 320
        downstrm_press_Pa = 101000
        fluid = 'nitrogen'

        gamma = get_gamma_SI(
            upstrm_press_Pa,
            upstrm_temp_K,
            fluid
        )

        # Ensure inputs are choked
        self.assertTrue(
            comp_is_choked(
                upstrm_press_Pa,
                downstrm_press_Pa,
                gamma
            )
        )

        mdot_kgps = comp_orifice_mdot_kgps(
            Cd,
            orifice_area_m2,
            upstrm_press_Pa,
            upstrm_temp_K,
            downstrm_press_Pa,
            fluid
        )
        
        (
            orifice_area_in2,
            upstrm_press_psia,
            upstrm_temp_F,
            downstrm_press_psia,
        ) = convert_many(
            (orifice_area_m2,'m^2','in^2'),
            (upstrm_press_Pa,'Pa','psia'),
            (upstrm_temp_K,'degK','degF'),
            (downstrm_press_Pa,'Pa','psia')
        )
        mdot_lbmps = comp_orifice_mdot_lbmps(
            Cd,
            orifice_area_in2,
            upstrm_press_psia,
            upstrm_temp_F,
            downstrm_press_psia,
            fluid,
        )


        self.assertAlmostEqual(
            mdot_kgps,
            16.67958477,
            delta=1e-4
        )

        self.assertAlmostEqual(
            mdot_lbmps,
            36.772189906986, # Google conversion
            delta=1e-4
        )


if __name__ == '__main__':
    unittest.main()