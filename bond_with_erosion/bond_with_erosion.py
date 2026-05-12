'''
Author: harry
Date: 2025-12-03 21:02:45
Version: 1.0
LastEditors: harry
LastEditTime: 2026-01-23 16:23:58
Description: 
FilePath: \bond_with_erosion\bond_with_erosion.py
'''
from pathlib import Path
from rocky20.addins.addin_models import container_model, data_model
from rocky20.addins.addin_specs import RockyAddinSpecs
from rocky20.addins.addin_types import Quantity, Boolean
from yapsy.IPlugin import IPlugin

NAME = 'Bond With Erosion'

@data_model(icon=None, caption=NAME)
class GeneralProperties:    
    activation_time = Quantity(value=0.0, unit='s', caption='Bond Activation Time')
    search_distance = Quantity(value=0.001, unit='mm', caption='Bond Search Distance')
    output_bond_force = Boolean(value=True, caption='Output Bond Force')
    output_bond_moment = Boolean(value=True, caption='Output Bond Moment')
    output_bond_normal_stress = Boolean(value=True, caption='Output Bond Normal Stress')
    output_bond_tangential_stress = Boolean(value=True, caption='Output Bond Tangential Stress')
    output_bond_normal_stress_linear = Boolean(value=True, caption='Output Bond Normal Stress Linear')
    output_bond_normal_stress_bending = Boolean(value=True, caption='Output Bond Normal Stress Bending')
    output_bond_tangential_stress_shear = Boolean(value=True, caption='Output Bond Tangential Stress Shear')
    output_bond_tangential_stress_torsion = Boolean(value=True, caption='Output Bond Tangential Stress Torsion')
    output_scaled_bond_normal_stress = Boolean(value=True, caption='Output Scaled Bond Normal Stress')
    output_scaled_bond_tangential_stress = Boolean(value=True, caption='Output Scaled Bond Tangential Stress')
    output_bond_state = Boolean(value=True, caption='Output Bond State')
    output_bond_linear_deformation = Boolean(value=True, caption='Output Bond Linear Deformation')
    output_bond_angular_deformation = Boolean(value=True, caption='Output Bond Angular Deformation')
    output_contact_normal_stress_limit = Boolean(value=True, caption='Output Contact Normal Stress Limit')
    output_contact_tangential_stress_limit = Boolean(value=True, caption='Output Contact Tangential Stress Limit')
    output_scaled_contact_normal_stress_limit = Boolean(value=True, caption='Output Scaled Contact Normal Stress Limit')
    output_scaled_contact_tangential_stress_limit = Boolean(value=True, caption='Output Scaled Contact Tangential Stress Limit')
    output_softening_factor = Boolean(value=True, caption='Output Softening Factor')


@container_model()
class AdhesionModel:
    pass  

@container_model()
class MaterialInteractionProperties:  
    bonds_enabled = Boolean(value=False, caption='Enable Bonds')
    distance_factor = Quantity(value=0.1, unit='-', caption='Distance Factor')
    maximum_elongation = Quantity(value=1e-5, unit='m', caption='Approximate Maximum Elongation')
    normal_stiffness = Quantity(value=1.0e10, unit='N/m3', caption='Normal Stiffness Per Area')
    tangential_stiffness = Quantity(value=1.0e09, unit='N/m3', caption='Tangential Stiffness Per Area')
    damping_ratio = Quantity(value=0.25, unit='-', caption='Damping Ratio')
    normal_stress_limit = Quantity(value=1.0e6, unit='Pa', caption='Tensile Stress Limit')
    tangential_stress_limit = Quantity(value=1.0e6, unit='Pa', caption='Shear Stress Limit')
    maximum_activation_distance = Quantity(value=1e-5, unit='m', caption='Maximum Activation Distance')
    radius_multiplier = Quantity(value=1.0, unit='-', caption='Radius Multiplier')
    scale_factor = Quantity(value=1.0, unit='-', caption='Scale Factor')

@container_model()
class CustomMaterialProperties:
    e = Quantity(value=0.75, unit='-', caption='Void Ratio') ## 孔隙比,至少大于0.6，推荐0.9-1.0，有问题，在于饱和度获取的时候会有0.1-0.2的误差
    w_p = Quantity(value=0.22, unit='-', caption='Plastic Limit Water Content') ## 塑限含水率 22%
    # c_prime_n = Quantity(value=5000.0, unit='Pa', caption='Saturated Effective Cohesion Norm') ## 法向饱和有效粘聚力
    # c_prime_t = Quantity(value=2500.0, unit='Pa', caption='Saturated Effective Cohesion Tangential') ## 切向饱和有效粘聚力

class ModuleSpecifications(RockyAddinSpecs):
    name = NAME
    model = GeneralProperties
    adhesion_model = AdhesionModel
    material_properties = CustomMaterialProperties
    material_interaction_properties = MaterialInteractionProperties

    @classmethod
    def CreateAddin(cls):
        return cls.CreateDynamicAddin(Path(__file__).parent, 'bond_with_erosion')

class BondWithErosionModule(IPlugin):
    def get_addin_specs(self):
        return ModuleSpecifications
