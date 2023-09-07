import unittest
from KineticKebab.propulsion.rpe_9 import *
from KineticKebab.fluids.general import *

class RPE_TEST(unittest.TestCase):

    def test_3_24(self):
        print(f'\n==================== {RPE_TEST.__name__} ===================\n')
        At_m2 = 0.05
        p1_Pa = 200000
        kappa = 1.2
        R_specific_JpkgK = 300 
        T1_K = 320

        mdot,report_mdot = massflow_3_24_kgps(
            At_m2,
            p1_Pa,
            kappa,
            R_specific_JpkgK,
            T1_K,
            verbose_reporting=True
        ) 
        (
            At_in2,
            p1_psia,
            T1_F,
        ) = convert_many(
            (At_m2,'m^2','in^2'),
            (p1_Pa,'Pa','psia'),
            (T1_K,'degK','degF')
        )


        R_specific_ftlbfplbmR = 55.758760552 # Online conversion 

        mdot_IM, report_mdot_IM = massflow_3_24_lbmps(
            At_in2,
            p1_psia,
            kappa,
            R_specific_ftlbfplbmR,
            T1_F,
            verbose_reporting=True
        ) 

        print(
            report_mdot +
            report_mdot_IM 
        )

        # SI Test
        self.assertAlmostEqual(
            mdot,
            20.93125353, # From Desmos
            delta=1e-3
        )
        # IM Test
        self.assertAlmostEqual(
            convert(mdot_IM,'lbm/s','kg/s'),
            mdot,
            delta=1e-3
        )


    def test_3_29(self):
        print(f'\n==================== {RPE_TEST.__name__} ===================\n')
        # SI TEST 
        At_m2 = 0.05
        p1_Pa = 200000
        kappa = 1.2
        p2_Pa = 110000
        A2_m2 = 0.15
        p3_Pa = 100000

        force_N, report_force_N = force_3_29_N(
            At_m2,
            p1_Pa,
            kappa,
            p2_Pa,
            A2_m2,
            p3_Pa,
            verbose_reporting=True
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

        force_lbf, report_force_lbf = force_3_29_lbf(
            At_in2,
            p1_psia,
            kappa,
            p2_psia,
            A2_in2,
            p3_psia,
            verbose_reporting=True
        )

        print(
            report_force_N +
            report_force_lbf
        )
        self.assertAlmostEqual(
            force_N,
            8418.450625,
            delta=1e-4
        )
        self.assertAlmostEqual(
            force_lbf,
            1892.5429940361, # Google conversion
            delta=1e-4
        )

    def test_thrust_coef(self):
        print(f'\n==================== {RPE_TEST.__name__} ===================\n')
        F_N = 10000
        At_m2 = 0.05
        p_1_Pa = 300000 

        thrust_coef, report_thrust_coef = thrust_coef_3_31_SI(
            F_N,
            At_m2,
            p_1_Pa,
            verbose_reporting=True
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

        thrust_coef_IM, report_thrust_coef_IM = thrust_coef_3_31_IM(
            F_lbf,
            At_in2,
            p_1_psia,
            verbose_reporting=True
        )
        self.assertAlmostEqual(
            thrust_coef_IM,
            thrust_coef,
            delta=1e-6
        )

        print(
            report_thrust_coef +
            report_thrust_coef_IM
        )


if __name__ == '__main__':
    unittest.main()