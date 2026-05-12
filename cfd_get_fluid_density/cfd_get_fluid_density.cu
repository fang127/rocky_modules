#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api_cfd.h>

struct ModuleData
{
    int fluid_density;
    // double air_density = 1.225;   // kg/m3
    // double water_density = 998.2; // kg/m3
};

ROCKY_PLUGIN("CFD Get Fluid Density", "1.0.0")

ROCKY_PLUGIN_CONFIGURE(input_data, module_data)
{
    ModuleData *data = new ModuleData();
    module_data = static_cast<void *>(data);
}

ROCKY_PLUGIN_SETUP(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    data->fluid_density = model.get_particle_scalars().add<double>("soften factor", "-", true);
}

// ROCKY_PLUGIN_NON_DIMENSIONALIZE(model, module_data)
// {
//     auto data = static_cast<ModuleData *>(module_data);
//     data->air_density /= (model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
//     data->water_density /= (model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
// }

ROCKY_PLUGIN_INITIALIZE_CUDA(model, host_data, device_id, module_device_data)
{
    auto h_data = static_cast<ModuleData *>(host_data);
    ModuleData *data_device = nullptr;
    CUDA_MALLOC_TYPE(data_device, 1, ModuleData);
    CUDA_COPY_H2D(data_device, h_data, 1);
    module_device_data = static_cast<void *>(data_device);
}

// ROCKY_PLUGIN_PRE_OUTPUT(model, module_data)
// {
//     auto data = static_cast<ModuleData *>(module_data);
//     model.get_particle_scalars().set_dimension(data->fluid_density, model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
// }

ROCKY_PLUGIN_TEAR_DOWN_CUDA(model, device_id, module_device_data)
{
    auto d_data = static_cast<ModuleData *>(module_device_data);
    CUDA_FREE(d_data);
}

ROCKY_PLUGIN_TEAR_DOWN(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    delete data;
}

// CFD_COUPLING
ROCKY_PLUGIN_CFD_COUPLING()

ROCKY_PLUGIN_PRE_FORCE_ON_FLUID(model, particle, cfd, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    // Sr = (density - 1.225) / (998.2-1.225)
    const double fluid_density = cfd.get_fluid_density();
    double Sr = (fluid_density * 1000 - 1.225) / (998.2 - 1.225);
    // Sr范围[0,1]
    if (Sr < 0)
        Sr = 0;
    if (Sr > 1)
        Sr = 1;
    // Sr不可以小于之前的值
    // double temp = particle.get_scalars().get_scalar<double>(data->fluid_density);
    // if (Sr < temp)
    //     Sr = temp;
    particle.get_scalars().set_scalar<double>(data->fluid_density, Sr);
}
ROCKY_PLUGIN_PRE_FORCE_ON_FLUID_END()

ROCKY_PLUGIN_CFD_COUPLING_END()

ROCKY_PLUGIN_END