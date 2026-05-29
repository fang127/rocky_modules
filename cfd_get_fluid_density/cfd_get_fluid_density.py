import sys
from pathlib import Path
from rocky20.addins.addin_models import container_model, data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity, ScalarProperties
from yapsy.IPlugin import IPlugin

NAME = 'CFD Get Fluid Density'


@data_model(icon=None, caption=NAME)
class Model:
    air_density = Quantity(value=1.225, unit='kg/m3', caption='Air Density')
    water_density = Quantity(value=998.2, unit='kg/m3', caption='Water Density')

class Specs(RockyAddinSpecs):
    name = NAME
    model = Model

    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'cfd_get_fluid_density')

class Plugin(IPlugin):
    def get_addin_specs(self):
        return Specs
