import unittest
from KineticKebab.propulsion.rpe_9 import *

class REP_TEST(unittest.TestCase):

    def test_3_29(self):

        # SI TEST 
        At_m2 = 0.05
        p1_Pa = 200000
        kappa = 1.2
        p2_Pa = 110000
        A2_m2 = 0.15
        p3_Pa = 100000

        force_N = force_3_29_SI(
            At_m2,
            p1_Pa,
            kappa,
            p2_Pa,
            A2_m2,
            p3_Pa,
            verbose_printing=True
        ) 
        self.assertAlmostEqual(
            force_N,
            8418.450625,
            delta=1e-4
        )

        # IM TEST
        (
            At_in2,
            p1_psia,
            p2_psia,
            A2_in2,
            p3_psia,
        ) = convert_many(
            (At_m2,'m^2','in^2'),
            (p1_Pa,'Pa','psia'),
            (p2_Pa,'Pa','psia'),
            (A2_m2,'m^2','in^2'),
            (p3_Pa,'Pa','psia'),
        )

        force_lbf = force_3_29_IM(
            At_in2,
            p1_psia,
            kappa,
            p2_psia,
            A2_in2,
            p3_psia,
            verbose_printing=True
        )
        self.assertAlmostEqual(
            force_lbf,
            1892.5429940361, # Google conversion
            delta=1e-4
        )
    
    def test_thrust_coef(self):
        
        F_N = 10000
        At_m2 = 0.05
        p_1_Pa = 300000 

        thrust_coef = thrust_coef_3_31_SI(
            F_N,
            At_m2,
            p_1_Pa,
            verbose_printing=True
        )

        self.assertAlmostEqual(
            thrust_coef,
            0.666666666666,
            delta=1e-4
        )
        (
            F_lbf,
            At_in2,
            p_1_psia,
        ) = convert_many(
            (F_N,'N','lbf'),
            (At_m2,'m^2','in^2'),
            (p_1_Pa,'Pa','psia')
        )

        thrust_coef_IM = thrust_coef_3_31_IM(
            F_lbf,
            At_in2,
            p_1_psia,
            verbose_printing=True
        )
        self.assertAlmostEqual(
            thrust_coef_IM,
            thrust_coef,
            delta=1e-6
        )



if __name__ == '__main__':
    unittest.main()