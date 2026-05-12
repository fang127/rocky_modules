import sys
from pathlib import Path
from rocky20.addins.addin_models import data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity
from yapsy.IPlugin import IPlugin

NAME = 'VG_GDB_Law'

@data_model(icon=None, caption=NAME)
class ParametricGidaspowModel:
    # param_power_coeff = Quantity(value=1.65, unit='-', caption='parameter 1')
    # param_viscous_coeff = Quantity(value=200, unit='-', caption='parameter 2')
    # param_kinetic_coeff = Quantity(value=2.333, unit='-', caption='parameter 3')
    n = Quantity(value=3, unit='-', caption='n')
    vg_alpha = Quantity(value=0.5, unit='-', caption='vg alpha')
    residual_water_content = Quantity(value=0.0, unit='-', caption='residual water content')
    relax_alpha = Quantity(value=1.0, unit='-', caption='relaxation alpha')
    K_sat = Quantity(value=1e-8, unit='-', caption='saturated hydraulic conductivity')

@data_model(icon=None, caption=NAME)
class DragModel:
    pass

class Specs(RockyAddinSpecs):
    name = NAME
    model = ParametricGidaspowModel
    # cfd_drag_law_model = DragModel


    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'VG_GDB_Law')

class Plugin(IPlugin):
    def get_addin_specs(self):
        return Specs