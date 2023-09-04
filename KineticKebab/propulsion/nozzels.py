import numpy as np
import sys

from KineticKebab.common import *

class Standard15degSI():
    def __init__(
        self,
        throat_area_m2,
        exit_area_m2,
        half_angle_deg=15
    ):
        self.throat_area_m2 = throat_area_m2 
        self.exit_area_m2 = exit_area_m2 
        self.half_angle_deg=half_angle_deg
        self.throat_radius_m = circle_radius_from_area(
            throat_area_m2
        )
        self.exit_radius_m = circle_radius_from_area(
            exit_area_m2
        )

        # Profile Cals 
        self._hidden_profile_length_m = law_of_sins_side(
            alpha=np.deg2rad(75),
            beta=np.deg2rad(self.half_angle_deg),
            b=self.throat_area_m2
        )
        self.nozzel_length_m = (
            law_of_sins_side(
                alpha=np.deg2rad(75),
                beta=np.deg2rad(self.half_angle_deg),
                b=self.exit_radius_m
            ) - self._hidden_profile_length_m
        )
        self.nozzel_volume_m3 = (
            cone_volume(
                radius=self.exit_radius_m,
                height=self.nozzel_length_m + self._hidden_profile_length_m
            )
        )

        # Conversions
        (
            self.throat_area_in2,
            self.exit_area_in2,
            self.throat_radius_in,
            self.exit_radius_in,
            self.nozzel_length_in,
            self.nozzel_volume_in3,
        ) = convert_many(
            (self.throat_area_m2,'m^2','in^2'),
            (self.exit_area_m2,'m^2','in^2'),
            (self.throat_radius_m,'m','in'),
            (self.exit_radius_m,'m','in'),
            (self.nozzel_length_m,'m','in'),
            (self.nozzel_volume_m3,'m^3','in^3')
        )

    def get_report_SI(self,places=3):
        return (
            pretty_class_name('Standard15degSI') +
            pretty_str_key_val(
                ('throat_radius_m',self.throat_radius_m),
                ('exit_radius_m',self.exit_radius_m),
                ('nozzel_length_m',self.nozzel_length_m),
                ('nozzel_volume_m3',self.nozzel_volume_m3),
                places=places
            )
        )

    def get_report_IM(self,places=3):
        return (
            pretty_class_name('Standard15degIM') +
            pretty_str_key_val_to_convert_val(
                ('throat_area_in2',self.throat_area_in2,'throat_area_m2',self.throat_area_m2),
                ('exit_area_in2',self.exit_area_in2,'exit_area_m2',self.exit_area_m2),
                places=places
            )+
            pretty_str_key_val_from_convert_val(
                ('throat_radius_in',self.throat_radius_in,'throat_radius_m',self.throat_radius_m),
                ('exit_radius_in',self.exit_radius_in,'exit_radius_m',self.exit_radius_m),
                ('nozzel_length_in',self.nozzel_length_in,'nozzel_length_m',self.nozzel_length_m),
                ('nozzel_volume_in3',self.nozzel_volume_in3,'nozzel_volume_m3',self.nozzel_volume_m3),
                places=places
            )
        )
    
    def export_svg(file_name,file_path):
        path = sys.path.join(file_path,file_name)


class Standard15degIM(Standard15degSI):
    def __init__(
        self,
        throat_area_in2,
        exit_area_in2,
        half_angle_deg=15
    ):

        (
            throat_area_m2,
            exit_area_m2 
        ) = convert_many(
            (throat_area_in2,'in^2','m^2'),
            (exit_area_in2,'in^2','m^2')
        )

        super().__init__(
            throat_area_m2,
            exit_area_m2,
            half_angle_deg=15
        )
