import sys
from pathlib import Path
from rocky20.addins.addin_models import data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity, Boolean
from yapsy.IPlugin import IPlugin

NAME = 'VG_Law'

@data_model(icon=None, caption=NAME)
class ParametricGidaspowModel:
    # param_power_coeff = Quantity(value=1.65, unit='-', caption='parameter 1')
    # param_viscous_coeff = Quantity(value=200, unit='-', caption='parameter 2')
    # param_kinetic_coeff = Quantity(value=2.333, unit='-', caption='parameter 3')
    n = Quantity(value=3, unit='-', caption='n')
    vg_alpha = Quantity(value=0.5, unit='1/m', caption='vg alpha')
    residual_water_content = Quantity(value=0.0, unit='-', caption='residual water content')
    relax_alpha = Quantity(value=1.0, unit='-', caption='relaxation alpha')
    K_sat = Quantity(value=1.0, unit='m/s', caption='K_sat saturated hydraulic conductivity')
    scale_factor = Quantity(value=1.0, unit='-', caption='Scale Factor')
    fluent_gravity = Quantity(value=9.81, unit='m/s2', caption='Fluent Gravity')
    water_density = Quantity(value=998.2, unit='kg/m3', caption='Water Density')
    air_density = Quantity(value=1.225, unit='kg/m3', caption='Air Density')
    output_explicit_fluid_momentum_source = Boolean(value=True, caption='Output Explicit Fluid Momentum Source')
    output_implicit_fluid_momentum_source = Boolean(value=True, caption='Output Implicit Fluid Momentum Source')
    output_vg_saturation = Boolean(value=True, caption='Output VG Saturation')
    output_vg_theta = Boolean(value=True, caption='Output VG Theta')
    output_vg_effective_saturation = Boolean(value=True, caption='Output VG Effective Saturation')
    output_vg_suction = Boolean(value=True, caption='Output VG Suction')
    output_vg_k_unsat = Boolean(value=True, caption='Output VG K_unsat')
    output_vg_forchheimer_f = Boolean(value=True, caption='Output VG Forchheimer F')
    output_vg_darcy_d = Boolean(value=True, caption='Output VG Darcy D')
    output_vg_reynolds = Boolean(value=True, caption='Output VG Reynolds')
    output_vg_fluid_speed = Boolean(value=True, caption='Output VG Fluid Speed')
    output_vg_porosity = Boolean(value=True, caption='Output VG Porosity')
    output_vg_kr = Boolean(value=True, caption='Output VG Kr')
    output_fluid_density = Boolean(value=True, caption='Output fluid_density')
    output_fluid_viscosity = Boolean(value=True, caption='Output fluid_viscosity')
    output_density_for_permeability = Boolean(value=True, caption='Output density_for_permeability')
    output_d_times_viscosity = Boolean(value=True, caption='Output D_times_viscosity')
    output_f_times_density_speed = Boolean(value=True, caption='Output F_times_density_speed')

@data_model(icon=None, caption=NAME)
class DragModel:
    pass

class Specs(RockyAddinSpecs):
    name = NAME
    model = ParametricGidaspowModel
    # cfd_drag_law_model = DragModel


    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'VG_Law')

class Plugin(IPlugin):
    def get_addin_specs(self):
        return Specs
