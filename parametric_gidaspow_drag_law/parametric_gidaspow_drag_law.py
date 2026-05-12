import sys
from pathlib import Path
from rocky20.addins.addin_models import data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity
from yapsy.IPlugin import IPlugin

NAME = 'Parametric Gidaspow, Bezburuah & Ding'

@data_model(icon=None, caption=NAME)
class ParametricGidaspowModel:
    param_power_coeff = Quantity(value=1.65, unit='-', caption='parameter 1')
    param_viscous_coeff = Quantity(value=200, unit='-', caption='parameter 2')
    param_kinetic_coeff = Quantity(value=2.333, unit='-', caption='parameter 3')


@data_model(icon=None, caption=NAME)
class DragModel:
    pass

class Specs(RockyAddinSpecs):
    name = NAME
    model = ParametricGidaspowModel
    cfd_drag_law_model = DragModel

    _ansys_help_anchor = "Rocky:DEM_Module_Parametric_GBD"


    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'parametric_gidaspow_drag_law')

class Plugin(IPlugin):
    def get_addin_specs(self):
        return Specs