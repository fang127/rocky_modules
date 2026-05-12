import sys
from pathlib import Path
from rocky20.addins.addin_models import container_model, data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity
from yapsy.IPlugin import IPlugin

NAME = 'Darcy Resistance Source'


@data_model(icon=None, caption=NAME)
class Model:
    pass

@container_model()
class ParticleGroupProperties:
    permeability_coefficient_x = Quantity(value = 1e-5,unit='m/s',caption = 'Permeability Coefficient X')
    permeability_coefficient_y = Quantity(value = 1e-5,unit='m/s',caption = 'Permeability Coefficient Y')
    permeability_coefficient_z = Quantity(value = 1e-5,unit='m/s',caption = 'Permeability Coefficient Z')

class ModuleSpecifications(RockyAddinSpecs):
    name = NAME
    model = Model
    particle_group_properties = ParticleGroupProperties

    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'darcy_resistance_source')

class DarcyResistanceSourceModule(IPlugin):
    def get_addin_specs(self):
        return ModuleSpecifications