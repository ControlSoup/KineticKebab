from KineticKebab.fluids.general import *
from KineticKebab.common import *
from functions import * 
import numpy as np

class IncompPipe_SI():

    def __init__(
        self,
        id_m,
        length_m,
        roughness_m,
        hydro_diameter_m=None
    ):
        if hydro_diameter_m is None:
            self.hydro_diameter_m = id_m

        self.id_m = id_m
        self.length_m = length_m
        self.roughness_m = roughness_m 
        self.rel_roughness_m = roughness_m / self.hydro_diameter_m

    def get_dp(
        self,
        upstrm_press_Pa,
        upstrm_temp_K,
        flowrate_m3ps,
        fluid,
        length_m=None
    ):
        if length_m is None:
            length_m = self.length_m 

        # Infered Parameters 
        density_kgpm3 = get_density_SI(
            upstrm_press_Pa,
            upstrm_temp_K,
            fluid
        )
        flow_velocity_mps = pipe_flow_velocity_mps(
            id=self.id_m,
            flowrate=flowrate_m3ps
        )

        # Pipe Flow calcs 
        char_length_m = pipe_full_charachteristic_length_m(
            self.id_m,
            length_m
        )
        reynolds_number = get_reynolds_SI(
            upstrm_press_Pa,
            upstrm_temp_K,
            flow_velocity_mps,
            char_length_m,
            fluid 
        )
        friction_factor = niazkars_solution(
           self.rel_roughness_m,
           reynolds_number
        )
        
        # Darcy Weisbach
        dp_Pa = darcy_weisbach_dp_Pa(
            friction_factor,
            density_kgpm3,
            flow_velocity_mps,
            self.hydro_diameter_m,
            length_m
        )

        return dp_Pa


pipe_example = IncompPipe_SI(
    id_m=0.05,
    length_m=1,
    roughness_m=0.3
)
