#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api_cfd.h>
#include <rocky20/model/rocky_definitions.h>
#include <rocky20/core/utils/rocky_overloads.hpp>
struct ParticleGroupProperties
{
    double permeability_coefficient_x; // x方向渗透率
    double permeability_coefficient_y; // y方向渗透率
    double permeability_coefficient_z; // z方向渗透率
};

struct ModuleData
{
    int explicit_source;                                // 显式源项标量
    int implicit_source;                                // 隐式源项标量
    ParticleGroupProperties *particle_group_properties; // 自定义颗粒群数据,考虑多个颗粒群的情况
};

ROCKY_PLUGIN("Darcy Resistance Source", "1.0.0")

ROCKY_PLUGIN_CONFIGURE(input_data, module_data)
{
    ModuleData *data = new ModuleData();
    int i = input_data.get_number_particle_groups();
    data->particle_group_properties = new ParticleGroupProperties[i];
    auto pgp = data->particle_group_properties;
    if (input_data.has_particle_group_data())
    {
        for (int j = 0; j != i; ++i)
        {
            auto &pgp = data->particle_group_properties[i];
            auto index_pgp = input_data.get_particle_group_data(j);
            pgp.permeability_coefficient_x = index_pgp.get_double("Permeability Coefficient X");
            pgp.permeability_coefficient_y = index_pgp.get_double("Permeability Coefficient Y");
            pgp.permeability_coefficient_z = index_pgp.get_double("Permeability Coefficient Z");
        }
    }
    module_data = static_cast<void *>(data);
}

ROCKY_PLUGIN_SETUP(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    data->explicit_source = model.get_particle_scalars().add<double3>("ExplicitFluidMomentumSource", "N/m3", true);
    data->implicit_source = model.get_particle_scalars().add<double>("ImplicitFluidMomentumSource", "N.s/m4", true);
}

ROCKY_PLUGIN_NON_DIMENSIONALIZE(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    int i = model.get_number_of_particle_groups();
    for (int j = 0; j != i; ++j)
    {
        data->particle_group_properties[j].permeability_coefficient_x /= model.get_length_factor() / model.get_time_factor();
        data->particle_group_properties[j].permeability_coefficient_y /= model.get_length_factor() / model.get_time_factor();
        data->particle_group_properties[j].permeability_coefficient_z /= model.get_length_factor() / model.get_time_factor();
    }
}

ROCKY_PLUGIN_INITIALIZE_CUDA(model, host_data, device_id, module_device_data)
{
    auto h_data = static_cast<ModuleData *>(host_data);
    auto d_data = *h_data;
    // 拷贝数据
    int size = model.get_number_of_particle_groups();
    ParticleGroupProperties *d_particle_group_properties = nullptr;
    CUDA_MALLOC_TYPE(d_particle_group_properties, size, ParticleGroupProperties);
    CUDA_COPY_H2D(d_particle_group_properties, h_data->particle_group_properties, size);
    d_data.particle_group_properties = d_particle_group_properties;
    ModuleData *device_data = nullptr;
    CUDA_MALLOC_TYPE(device_data, 1, ModuleData);
    CUDA_COPY_H2D(device_data, &d_data, 1);

    module_device_data = static_cast<void *>(device_data);
}

ROCKY_PLUGIN_PRE_OUTPUT(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    model.get_particle_scalars().set_dimension(data->explicit_source, model.get_force_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->implicit_source, model.get_force_factor() * model.get_time_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
}

ROCKY_PLUGIN_TEAR_DOWN_CUDA(model, device_id, module_device_data)
{
    auto d_data = static_cast<ModuleData *>(module_device_data);
    ModuleData data_ptr;
    CUDA_COPY_D2H(&data_ptr, d_data, 1);
    CUDA_FREE(data_ptr.particle_group_properties);
    CUDA_FREE(d_data);
}

ROCKY_PLUGIN_TEAR_DOWN(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    delete[] data->particle_group_properties;
    delete data;
}

// CFD_COUPLING
ROCKY_PLUGIN_CFD_COUPLING()

// Darcy-Forchheimer阻力的标准形式:Ergun方程
ROCKY_PLUGIN_PRE_FORCE_ON_FLUID(device_model, particle, cfd, module_data)
{

    auto data = static_cast<ModuleData *>(module_data);
    const double porosity = 1.0 - cfd.get_solid_fraction(); // 孔隙率
    const double fluid_density = cfd.get_fluid_density();   // 水流密度
    const double3 v_fluid = cfd.get_relative_velocity();    // 水流相对速度

    // 获取当前粒子所属的颗粒群索引
    int group_index = particle.get_particle_group_index();
    const ParticleGroupProperties &pgp = data->particle_group_properties[group_index];

    // 获取渗透系数
    double kx = pgp.permeability_coefficient_x;
    double ky = pgp.permeability_coefficient_y;
    double kz = pgp.permeability_coefficient_z;

    double dt = device_model.get_time_step(); // DEM时间步长
    const double min_dt = 1e-6;               // 避免过小时间步导致数值不稳定
    const double max_dt = 1e-2;               // 避免过大时间步导致无效阻尼
    dt = rocky::dmax(dt, min_dt);
    dt = rocky::dmin(dt, max_dt);

    // 基于渗透系数的阻尼系数计算
    // 渗透系数越低，阻尼效应越强
    double permeability_scaling = 1e-8; // 基准渗透系数值

    // 计算阻尼强度因子（基于渗透系数）
    double base_damping_x = sqrt(permeability_scaling / rocky::dmax(kx, 1e-20)) / dt;
    double base_damping_y = sqrt(permeability_scaling / rocky::dmax(ky, 1e-20)) / dt;
    double base_damping_z = sqrt(permeability_scaling / rocky::dmax(kz, 1e-20)) / dt;

    // 重力方向参数配置（Y方向重力）
    const double target_velocity_y = 0.0; // Y方向目标速度（完全停止）

    // 计算方向阻尼系数
    double3 damping_coeff = make_double3(
        base_damping_x, // X方向阻尼（使用渗透系数）
        base_damping_y, // Y方向阻尼（重力方向）
        base_damping_z  // Z方向阻尼
    );

    // 计算显式阻力源项
    double3 source_term = make_double3(
        -fluid_density * damping_coeff.x * v_fluid.x,
        -fluid_density * damping_coeff.y * (v_fluid.y - target_velocity_y),
        -fluid_density * damping_coeff.z * v_fluid.z);

    // 数值稳定处理
    const double max_source = 1e6; // 最大源项值限制
    source_term.x = rocky::math::clamp(source_term.x, -max_source, 0.0);
    source_term.y = rocky::math::clamp(source_term.y, -max_source, 0.0);
    source_term.z = rocky::math::clamp(source_term.z, -max_source, 0.0);

    // 隐式系数（取最大阻尼方向确保稳定）
    const double implicit_coeff = fluid_density * rocky::dmax(damping_coeff.x,
                                                              rocky::dmax(damping_coeff.y, damping_coeff.z));

    // 应用源项到粒子
    particle.get_scalars().add_explicit_fluid_momentum(source_term);
    particle.get_scalars().add_implicit_fluid_momentum(implicit_coeff);

    // 存储源项用于输出/分析
    particle.get_scalars().set_scalar<double3>(data->explicit_source, source_term);
    particle.get_scalars().set_scalar<double>(data->implicit_source, implicit_coeff);
}
ROCKY_PLUGIN_PRE_FORCE_ON_FLUID_END()

ROCKY_PLUGIN_CFD_COUPLING_END()

ROCKY_PLUGIN_END