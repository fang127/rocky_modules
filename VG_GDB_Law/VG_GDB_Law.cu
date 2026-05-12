#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api_cfd.h>

struct Data
{
    // double param_power_coeff;      // 幂指数系数
    // double param_viscous_coeff;    // 黏性系数
    // double param_kinetic_coeff;    // 动能系数
    double n;                      // n
    double relax_alpha;            // 松弛系数
    double vg_alpha;               // alpha
    double residual_water_content; // 残余含水量
    double K_sat;                  // 饱和渗透率
};

struct ModuleData
{
    Data *data;          // 输入的参数
    int explicit_source; // 显式源项标量
    int implicit_source; // 隐式源项标量
};

ROCKY_PLUGIN("VG_GDB_Law", "1.0.0")

ROCKY_PLUGIN_CONFIGURE(input_data, module_data)
{
    ModuleData *pluginData = new ModuleData();
    pluginData->data = new Data();
    // // 获取GDB输入参数
    // pluginData->data->param_power_coeff =
    //     input_data.get_model().get_double("param_power_coeff");
    // pluginData->data->param_viscous_coeff =
    //     input_data.get_model().get_double("param_viscous_coeff");
    // pluginData->data->param_kinetic_coeff =
    //     input_data.get_model().get_double("param_kinetic_coeff");
    // 获取VG基质吸力参数
    pluginData->data->n = input_data.get_model().get_double("n");
    pluginData->data->vg_alpha = input_data.get_model().get_double("vg_alpha");
    pluginData->data->residual_water_content =
        input_data.get_model().get_double("residual_water_content");
    pluginData->data->relax_alpha =
        input_data.get_model().get_double("relax_alpha");
    pluginData->data->K_sat = input_data.get_model().get_double("K_sat");

    module_data = static_cast<void *>(pluginData);
}

// 设置运行时计算的标量
ROCKY_PLUGIN_SETUP(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    data->explicit_source = model.get_particle_scalars().add<double3>(
        "ExplicitFluidMomentumSource", "N/m3", true);
    data->implicit_source = model.get_particle_scalars().add<double>(
        "ImplicitFluidMomentumSource", "N.s/m4", true);
    model.get_fluid_scalars().enable_storage_cell_volume();
}

// CUDA初始化
ROCKY_PLUGIN_INITIALIZE_CUDA(model, host_data, device_id, module_device_data)
{
    auto h_data = static_cast<ModuleData *>(host_data);
    auto d_data = *h_data;
    // 分配设备内存并复制数据
    Data *d_plugin_data = nullptr;
    CUDA_MALLOC_TYPE(d_plugin_data, 1, Data);      // 分配设备内存
    CUDA_COPY_H2D(d_plugin_data, h_data->data, 1); // 复制数据到设备
    d_data.data = d_plugin_data;
    ModuleData *device_data = nullptr;
    CUDA_MALLOC_TYPE(device_data, 1, ModuleData);
    CUDA_COPY_H2D(device_data, &d_data, 1);

    module_device_data = static_cast<void *>(device_data);
}

ROCKY_PLUGIN_PRE_OUTPUT(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    model.get_particle_scalars().set_dimension(
        data->explicit_source,
        model.get_force_factor() /
            (model.get_length_factor() * model.get_length_factor() *
             model.get_length_factor()));
    model.get_particle_scalars().set_dimension(
        data->implicit_source,
        model.get_force_factor() * model.get_time_factor() /
            (model.get_length_factor() * model.get_length_factor() *
             model.get_length_factor() * model.get_length_factor()));
}

ROCKY_PLUGIN_TEAR_DOWN(model, data)
{
    auto module_data = static_cast<ModuleData *>(data);
    delete module_data->data;
    delete module_data;
}

ROCKY_PLUGIN_TEAR_DOWN_CUDA(model, device_id, device_data)
{
    auto module_data = static_cast<ModuleData *>(device_data);
    ModuleData data_ptr;
    // 拷贝数据回主机
    CUDA_COPY_D2H(&data_ptr, module_data, 1);
    // 释放设备内存
    CUDA_FREE(data_ptr.data);
    CUDA_FREE(module_data);
}

ROCKY_PLUGIN_CFD_COUPLING()

// inline ROCKY_FUNCTIONS double parametric_gidaspow(double Re,
//                                                 double alpha_f,
//                                                 double phi,
//                                                 double param_power_coeff,
//                                                 double param_viscous_coeff,
//                                                 double param_kinetic_coeff)
// {
//     double Cd;

//     if (alpha_f > 0.8)
//     {
//         if (Re * alpha_f < 1000)
//         {
//             Cd = 24 / alpha_f / Re * (1 + 0.15 * pow(alpha_f * Re, 0.687)) *
//                 pow(alpha_f, -param_power_coeff);
//         }
//         else
//         {
//             Cd = 0.44 * pow(alpha_f, -param_power_coeff);
//         }
//     }
//     else
//     {
//         Cd = param_viscous_coeff * (1 - alpha_f) / (alpha_f * phi * phi * Re)
//         +
//             param_kinetic_coeff / phi;
//     }

//     return Cd;
// }

// // GDB计算拖曳力系数
// ROCKY_PLUGIN_CFD_COUPLING_DRAG_COEFFICIENT(particle, cfd, data)
// {
//     auto plugin_data = static_cast<Data *>(data);

//     const double reynolds = cfd.get_reynolds_number();          // 雷诺数
//     const double fluid_fraction = 1 - cfd.get_solid_fraction(); //
//     流体体积分数 const double sphericity = particle.get_sphericity(); //
//     颗粒球形度

//     return parametric_gidaspow(
//         reynolds, fluid_fraction, sphericity, plugin_data->param_power_coeff,
//         plugin_data->param_viscous_coeff, plugin_data->param_kinetic_coeff);
// }

// ROCKY_PLUGIN_CFD_COUPLING_DRAG_COEFFICIENT_END()

// 在流体求解前计算颗粒对流体的阻力源项
ROCKY_PLUGIN_PRE_FORCE_ON_FLUID(device_model, particle, cfd, module_data)
{

    auto plugin_data = static_cast<ModuleData *>(module_data);

    // 高孔隙率直接跳过计算
    const double porosity = 1 - cfd.get_solid_fraction(); // 孔隙率
    // if (porosity >= 0.7)
    // {
    //     double3 zero = {0.0, 0.0, 0.0};

    //     particle.get_scalars().add_explicit_fluid_momentum(zero);
    //     particle.get_scalars().add_implicit_fluid_momentum(0.0);

    //     particle.get_scalars().set_scalar<double3>(plugin_data->explicit_source,
    //                                                zero);
    //     particle.get_scalars().set_scalar<double>(plugin_data->implicit_source,
    //                                               0.0);

    //     return;
    // }

    // 当前时间获取流体和颗粒数据
    const double fluid_density = cfd.get_fluid_density(); // 流体密度
    const double partical_diameter =
        cfd.get_particle_equivalent_diameter();                   // 颗粒直径
    double Sr = (fluid_density * 1000 - 1.225) / (998.2 - 1.225); // 饱和度
    double dt = cfd.get_cfd_time_step();
    double3 relative_v = cfd.get_relative_velocity();           // 相对速度
    double3 particle_v = particle.get_translational_velocity(); // 颗粒速度
    double3 fluid_v = relative_v + particle_v;                  // 流体速度
    const double theta_r =
        plugin_data->data->residual_water_content; // 残余含水率
    const double theta_s = porosity;               // 饱和含水率
    const double n = plugin_data->data->n;         // VG n参数
    double m = 1.0 - 1.0 / n;
    const double vg_alpha = plugin_data->data->vg_alpha; // VG alpha参数
    const double K_sat = plugin_data->data->K_sat;       // 饱和渗透率

    // Sr范围[0,1]
    if (Sr < 0)
        Sr = 0;
    if (Sr > 1)
        Sr = 1;

    // 计算体积含水率
    double theta = porosity * Sr;

    double suction = 0.0;
    double K_rel = K_sat; // 非饱和渗透率初始化
    // 数值保护
    const double small_eps = 1e-12;
    const double Se_min = 1e-6;     // 避免 pow(0, neg)
    const double Se_ramp = 0.2;     // 当 Se < 0.2 时做平滑
    const double suction_cap = 1e5; // 最大吸力限制（Pa）

    if (theta > theta_r && theta < theta_s)
    {
        if (theta_s - theta_r > small_eps)
        {
            // 1. 计算原始等效饱和度 Se_raw
            double Se = (theta - theta_r) / (theta_s - theta_r);

            // clamp 到 [Se_min, 1]
            if (Se <= Se_min)
                Se = Se_min; // 防止 pow(0,负指数) 数值爆炸，使用 Se_min 代替
            if (Se > 1.0)
                Se = 1.0;

            // 2. 小 Se 区间：平滑
            if (Se <= Se_ramp)
            {
                // 计算平滑权重 w ∈ [0,1]
                double w = Se / Se_ramp;
                if (w < 0.0)
                    w = 0.0;
                if (w > 1.0)
                    w = 1.0;
                double Se_inv = pow(Se, -1.0 / m);
                double psi_abs = pow(Se_inv - 1.0, 1.0 / n) / vg_alpha;
                double psi_pa = psi_abs * 98.0638;

                // 平滑（从 0 平滑到正常吸力）
                suction = w * psi_pa;
            }
            else
            {
                // 3. 正常 VG 计算区
                double Se_inv = pow(Se, -1.0 / m);
                double psi_abs = pow(Se_inv - 1.0, 1.0 / n) / vg_alpha;
                suction = psi_abs * 98.0638;
            }

            // 4. 最大吸力保护
            if (suction > suction_cap)
                suction = suction_cap;

            // 5. VG 模型下的非饱和渗透率计算
            double K_min = 1e-12;
            double alpha_psi = vg_alpha * suction / 98.0638;
            double temp_1 = pow(alpha_psi, n - 1);
            double temp_2 = pow(alpha_psi, n);
            double temp_fz = pow(1 - temp_1 * pow(1 + temp_2, -m), 2);
            double temp_fm = pow(1 + temp_2, m / 2);
            K_rel = K_sat * temp_fz / temp_fm;
            if (K_rel < K_min)
                K_rel = K_min;
        }
    }

    // Darcy–Forchheimer方程，层流时退化为达西,S= - (D * viscosity + 0.5 * F *
    // fluid_density * speed) * fluid_v
    double relax_alpha = plugin_data->data->relax_alpha;
    double viscosity = cfd.get_fluid_viscosity(); // 流体粘度
    double reynolds = cfd.get_reynolds_number();  // 雷诺数
    double speed = sqrt(fluid_v.x * fluid_v.x + fluid_v.y * fluid_v.y +
                        fluid_v.z * fluid_v.z);
    double eps_v = 1e-9;
    // 计算阻力系数D和F
    double D = 1 / K_rel; // 粘性阻力系数
    double F = 0.0;       // 惯性阻力系数，层流为0
    if (reynolds > 10)
    {
        F = 3.5 / (pow(porosity, 3) * partical_diameter); // euler方程经验值
    }
    // 显式源项（N/m3)
    double3 source = {0.0, 0.0, 0.0};
    if (speed > eps_v && porosity < 0.7)
    {
        source.x = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.x;
        source.y = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.y;
        source.z = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.z;
    }

    // 隐式源项系数 (N·s/m4)
    double implicit_factor = 0.0;
    if (speed > eps_v && porosity < 0.7)
    {
        implicit_factor =
            -relax_alpha * (D * viscosity + F * fluid_density * speed);
    }

    // 设置颗粒源项
    particle.get_scalars().add_explicit_fluid_momentum(source);
    particle.get_scalars().add_implicit_fluid_momentum(implicit_factor);
    particle.get_scalars().set_scalar<double3>(plugin_data->explicit_source,
                                               source);
    particle.get_scalars().set_scalar<double>(plugin_data->implicit_source,
                                              implicit_factor);
}

ROCKY_PLUGIN_PRE_FORCE_ON_FLUID_END()

ROCKY_PLUGIN_CFD_COUPLING_END()

ROCKY_PLUGIN_END