import sys
from pathlib import Path
from yapsy.IPlugin import IPlugin
from rocky20.addins.addin_models import container_model, data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity

NAME = "Contact With Erosion"

# 全局属性
@data_model(icon=None, caption=NAME)
class Contact_With_Erosion:
    pass

# 自定义模块
@container_model()
class JKR_With_Erosion_Model:
    pass

# 自定义模块
@container_model()
class Normal_Force_Model:
    pass

# 自定义模块
@container_model()
class Tangential_Force_Model:
    pass

@container_model()
class CustomMaterialInteraction:
    surface_energy = Quantity(value=0.0, unit='J/m2', caption='Surface Energy')
    sliding_velocity_threshold = Quantity(value=0.001, unit='m/s', caption='Sliding Velocity Threshold')


class ContactWithErosionSpecs(RockyAddinSpecs):
    name = NAME
    model = Contact_With_Erosion
    adhesion_model = JKR_With_Erosion_Model
    normal_force_model = Normal_Force_Model
    tangential_force_model = Tangential_Force_Model

    material_interaction_properties = CustomMaterialInteraction

    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'contact_with_erosion')
    
class ContactWithErosionPlugin(IPlugin):
    def get_addin_specs(self):
        return ContactWithErosionSpecs