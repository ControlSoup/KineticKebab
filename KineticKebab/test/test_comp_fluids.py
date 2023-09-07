import unittest
from KineticKebab.fluids.compressible import *
from KineticKebab.fluids.general import *

class FluidsCompressibleTest(unittest.TestCase):

    def test_orifice_choked_mdot(self):
        print(f'\n==================== {FluidsCompressibleTest.__name__} ===================\n')
        report = ''
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
        density_kgpm3 = get_density_SI(
            upstrm_press_Pa,
            upstrm_temp_K,
            fluid
        )

        report += pretty_str_key_val(
            ('gamma',gamma),
            ('density_kgpm3',density_kgpm3),
        )

        print(report)
    
        # Ensure inputs are choked
        self.assertTrue(
            comp_is_choked(
                upstrm_press_Pa,
                downstrm_press_Pa,
                gamma
            )
        )

        mdot_kgps, SI_repot = comp_orifice_mdot_kgps(
            Cd,
            orifice_area_m2,
            upstrm_press_Pa,
            upstrm_temp_K,
            downstrm_press_Pa,
            fluid,
            verbose_reporting=True
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
        mdot_lbmps, IM_report = comp_orifice_mdot_lbmps(
            Cd,
            orifice_area_in2,
            upstrm_press_psia,
            upstrm_temp_F,
            downstrm_press_psia,
            fluid,
            verbose_reporting=True
        )

        print(
            SI_repot,
            IM_report
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