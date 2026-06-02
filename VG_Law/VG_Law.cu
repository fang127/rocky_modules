#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api_cfd.h>

struct Data
{
    // double param_power_coeff;      // 幂指数系数
    // double param_viscous_coeff;    // 黏性系数
    // double param_kinetic_coeff;    // 动能系数
    double n;                      // n
    double relax_alpha;            // 松弛系数
    double vg_alpha;               // alpha，单位 1/m
    double residual_water_content; // 残余含水量
    double K_sat;                  // 饱和水力传导率，单位 m/s
    double scale_factor;           // 缩放因子
    double fluent_gravity;         // Fluent侧重力加速度
    double water_density;          // 水密度，单位 kg/m3
    double air_density;            // 空气密度，单位 kg/m3
    bool output_explicit_fluid_momentum_source;
    bool output_implicit_fluid_momentum_source;
    bool output_vg_saturation;
    bool output_vg_theta;
    bool output_vg_effective_saturation;
    bool output_vg_suction;
    bool output_vg_k_unsat;
    bool output_vg_forchheimer_f;
    bool output_vg_darcy_d;
    bool output_vg_reynolds;
    bool output_vg_fluid_speed;
    bool output_vg_porosity;
    bool output_vg_kr;
    bool output_fluid_density;
    bool output_fluid_viscosity;
    bool output_density_for_permeability;
    bool output_d_times_viscosity;
    bool output_f_times_density_speed;
    bool output_fluent_gravity;
    bool output_vg_k_intrinsic;
};

struct ModuleData
{
    Data *data;                   // 输入的参数
    int explicit_source;          // 显式源项标量
    int implicit_source;          // 隐式源项标量
    int vg_saturation;            // VG 饱和度
    int vg_theta;                 // VG 体积含水率
    int vg_effective_saturation;  // VG 有效饱和度
    int vg_suction;               // VG 基质吸力
    int vg_k_unsat;               // VG 非饱和水力传导率
    int vg_forchheimer_f;         // Forchheimer 惯性阻力系数
    int vg_darcy_d;               // Darcy 黏性阻力系数
    int vg_reynolds;              // Reynolds 数
    int vg_fluid_speed;           // 流体速度幅值
    int vg_porosity;              // 孔隙率
    int vg_kr;                    // 无量纲相对渗透率
    int fluid_density;            // 流体密度
    int fluid_viscosity;          // 流体黏度
    int density_for_permeability; // 渗透率计算使用的密度
    int d_times_viscosity;        // Darcy 隐式项分量 D * viscosity
    int f_times_density_speed;    // Forchheimer 隐式项分量 F * density * speed
    int fluent_gravity;           // 输出fluent gravity
    int vg_k_intrinsic;           // 输出k_intrinsic
};

ROCKY_PLUGIN("VG_Law", "1.0.0")

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
    pluginData->data->residual_water_content = input_data.get_model().get_double("residual_water_content");
    pluginData->data->relax_alpha = input_data.get_model().get_double("relax_alpha");
    pluginData->data->K_sat = input_data.get_model().get_double("K_sat");
    pluginData->data->scale_factor = input_data.get_model().get_double("scale_factor");
    pluginData->data->fluent_gravity = input_data.get_model().get_double("fluent_gravity");
    pluginData->data->water_density = input_data.get_model().get_double("water_density");
    pluginData->data->air_density = input_data.get_model().get_double("air_density");
    pluginData->data->output_explicit_fluid_momentum_source = input_data.get_model().get_bool("output_explicit_fluid_momentum_source");
    pluginData->data->output_implicit_fluid_momentum_source = input_data.get_model().get_bool("output_implicit_fluid_momentum_source");
    pluginData->data->output_vg_saturation = input_data.get_model().get_bool("output_vg_saturation");
    pluginData->data->output_vg_theta = input_data.get_model().get_bool("output_vg_theta");
    pluginData->data->output_vg_effective_saturation = input_data.get_model().get_bool("output_vg_effective_saturation");
    pluginData->data->output_vg_suction = input_data.get_model().get_bool("output_vg_suction");
    pluginData->data->output_vg_k_unsat = input_data.get_model().get_bool("output_vg_k_unsat");
    pluginData->data->output_vg_forchheimer_f = input_data.get_model().get_bool("output_vg_forchheimer_f");
    pluginData->data->output_vg_darcy_d = input_data.get_model().get_bool("output_vg_darcy_d");
    pluginData->data->output_vg_reynolds = input_data.get_model().get_bool("output_vg_reynolds");
    pluginData->data->output_vg_fluid_speed = input_data.get_model().get_bool("output_vg_fluid_speed");
    pluginData->data->output_vg_porosity = input_data.get_model().get_bool("output_vg_porosity");
    pluginData->data->output_vg_kr = input_data.get_model().get_bool("output_vg_kr");
    pluginData->data->output_fluid_density = input_data.get_model().get_bool("output_fluid_density");
    pluginData->data->output_fluid_viscosity = input_data.get_model().get_bool("output_fluid_viscosity");
    pluginData->data->output_density_for_permeability = input_data.get_model().get_bool("output_density_for_permeability");
    pluginData->data->output_d_times_viscosity = input_data.get_model().get_bool("output_d_times_viscosity");
    pluginData->data->output_f_times_density_speed = input_data.get_model().get_bool("output_f_times_density_speed");
    pluginData->data->output_fluent_gravity = input_data.get_model().get_bool("output_fluent_gravity");
    pluginData->data->output_vg_k_intrinsic = input_data.get_model().get_bool("output_k_intrinsic");

    module_data = static_cast<void *>(pluginData);
}

// 设置运行时计算的标量
ROCKY_PLUGIN_SETUP(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    data->explicit_source = model.get_particle_scalars().add<double3>("ExplicitFluidMomentumSource", "N/m3", data->data->output_explicit_fluid_momentum_source);
    data->implicit_source = model.get_particle_scalars().add<double>("ImplicitFluidMomentumSource", "N.s/m4", data->data->output_implicit_fluid_momentum_source);
    data->vg_saturation = model.get_particle_scalars().add<double>("VG_Saturation", "-", data->data->output_vg_saturation);
    data->vg_theta = model.get_particle_scalars().add<double>("VG_Theta", "-", data->data->output_vg_theta);
    data->vg_effective_saturation = model.get_particle_scalars().add<double>("VG_EffectiveSaturation", "-", data->data->output_vg_effective_saturation);
    data->vg_suction = model.get_particle_scalars().add<double>("VG_Suction", "Pa", data->data->output_vg_suction);
    data->vg_k_unsat = model.get_particle_scalars().add<double>("VG_K_unsat", "m/s", data->data->output_vg_k_unsat);
    data->vg_forchheimer_f = model.get_particle_scalars().add<double>("VG_Forchheimer_F", "1/m", data->data->output_vg_forchheimer_f);
    data->vg_darcy_d = model.get_particle_scalars().add<double>("VG_Darcy_D", "1/m2", data->data->output_vg_darcy_d);
    data->vg_reynolds = model.get_particle_scalars().add<double>("VG_Reynolds", "-", data->data->output_vg_reynolds);
    data->vg_fluid_speed = model.get_particle_scalars().add<double>("VG_FluidSpeed", "m/s", data->data->output_vg_fluid_speed);
    data->vg_porosity = model.get_particle_scalars().add<double>("VG_Porosity", "-", data->data->output_vg_porosity);
    data->vg_kr = model.get_particle_scalars().add<double>("VG_Kr", "-", data->data->output_vg_kr);
    data->fluid_density = model.get_particle_scalars().add<double>("fluid_density", "kg/m3", data->data->output_fluid_density);
    data->fluid_viscosity = model.get_particle_scalars().add<double>("fluid_viscosity", "Pa.s", data->data->output_fluid_viscosity);
    data->density_for_permeability = model.get_particle_scalars().add<double>("density_for_permeability", "kg/m3", data->data->output_density_for_permeability);
    data->d_times_viscosity = model.get_particle_scalars().add<double>("D_times_viscosity", "N.s/m4", data->data->output_d_times_viscosity);
    data->f_times_density_speed = model.get_particle_scalars().add<double>("F_times_density_speed", "N.s/m4", data->data->output_f_times_density_speed);
    data->fluent_gravity = model.get_particle_scalars().add<double>("fluent_grivity", "m/s2", data->data->output_fluent_gravity);
    data->vg_k_intrinsic = model.get_particle_scalars().add<double>("VG_K_intrinsic", "m2", data->data->output_vg_k_intrinsic);
    model.get_fluid_scalars().enable_storage_cell_volume();
}

ROCKY_PLUGIN_NON_DIMENSIONALIZE(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    data->data->K_sat /= model.get_length_factor() / model.get_time_factor();
    data->data->vg_alpha /= 1.0 / model.get_length_factor();
    data->data->fluent_gravity /= model.get_length_factor() / (model.get_time_factor() * model.get_time_factor());
    const double density_factor = model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor());
    data->data->water_density /= density_factor;
    data->data->air_density /= density_factor;
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
    model.get_particle_scalars().set_dimension(data->explicit_source, model.get_force_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->implicit_source, model.get_force_factor() * model.get_time_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->vg_saturation, 1.0);
    model.get_particle_scalars().set_dimension(data->vg_theta, 1.0);
    model.get_particle_scalars().set_dimension(data->vg_effective_saturation, 1.0);
    model.get_particle_scalars().set_dimension(data->vg_suction, model.get_pressure_factor());
    model.get_particle_scalars().set_dimension(data->vg_k_unsat, model.get_length_factor() / model.get_time_factor());
    model.get_particle_scalars().set_dimension(data->vg_forchheimer_f, 1.0 / model.get_length_factor());
    model.get_particle_scalars().set_dimension(data->vg_darcy_d, 1.0 / (model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->vg_reynolds, 1.0);
    model.get_particle_scalars().set_dimension(data->vg_fluid_speed, model.get_length_factor() / model.get_time_factor());
    model.get_particle_scalars().set_dimension(data->vg_porosity, 1.0);
    model.get_particle_scalars().set_dimension(data->vg_kr, 1.0);
    model.get_particle_scalars().set_dimension(data->fluid_density, model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->fluid_viscosity, model.get_force_factor() * model.get_time_factor() / (model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->density_for_permeability, model.get_mass_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->d_times_viscosity, model.get_force_factor() * model.get_time_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->f_times_density_speed, model.get_force_factor() * model.get_time_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
    model.get_particle_scalars().set_dimension(data->fluent_gravity, model.get_length_factor() / (model.get_time_factor() * model.get_time_factor()));
    model.get_particle_scalars().set_dimension(data->vg_k_intrinsic, model.get_length_factor() * model.get_length_factor());
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

// 在流体求解前计算颗粒对流体的阻力源项
ROCKY_PLUGIN_PRE_FORCE_ON_FLUID(device_model, particle, cfd, module_data)
{

    auto plugin_data = static_cast<ModuleData *>(module_data);

    // =========================
    // 1. CFD/DEM 基本变量
    // =========================

    const double porosity = 1 - cfd.get_solid_fraction(); // 孔隙率

    // 当前时间获取流体和颗粒数据
    const double fluid_density = cfd.get_fluid_density(); // 流体密度
    double density_for_permeability = fluid_density;
    if (density_for_permeability < 1e-12)
        density_for_permeability = 1e-12;
    // Fluent 侧重力加速度
    double gravity = plugin_data->data->fluent_gravity;
    if (gravity < 0.0)
        gravity = -gravity;
    if (gravity < 1e-12)
        gravity = 1e-12;

    const double rho_g = density_for_permeability * gravity;

    const double partical_diameter = cfd.get_particle_equivalent_diameter(); // 颗粒直径

    // 饱和度
    const double density_span = plugin_data->data->water_density - plugin_data->data->air_density;
    double Sr = 0.0; // 饱和度
    if (density_span > 1e-12)
        Sr = (fluid_density - plugin_data->data->air_density) / density_span;
    // Sr范围[0,1]
    if (Sr < 0)
        Sr = 0;
    if (Sr > 1)
        Sr = 1;

    // double dt = cfd.get_cfd_time_step();
    double3 relative_v = cfd.get_relative_velocity();           // 相对速度
    double3 particle_v = particle.get_translational_velocity(); // 颗粒速度
    double3 fluid_v = relative_v + particle_v;                  // 流体速度

    const double viscosity = cfd.get_fluid_viscosity(); // 流体粘度
    const double reynolds = cfd.get_reynolds_number();  // 雷诺数

    const double speed = sqrt(fluid_v.x * fluid_v.x + fluid_v.y * fluid_v.y + fluid_v.z * fluid_v.z);

    // =========================
    // 2. VG 参数
    // =========================
    const double theta_r = plugin_data->data->residual_water_content; // 残余含水率
    const double theta_s = porosity;                                  // 饱和含水率
    const double n = plugin_data->data->n;                            // VG n参数
    const double m = 1.0 - 1.0 / n;
    const double vg_alpha = plugin_data->data->vg_alpha; // VG alpha参数
    const double normalized_scale = plugin_data->data->scale_factor / 1000.0;
    const double scale_multiplier = normalized_scale * normalized_scale;
    const double K_sat = plugin_data->data->K_sat * scale_multiplier; // 饱和水力传导率

    // =========================
    // 3. 含水率与有效饱和度
    // =========================

    // 计算体积含水率
    const double theta = porosity * Sr;
    double Se = 0.0;
    const double small_eps = 1e-12; // TODO 硬编码，可能需要无量纲化
    if (theta_s - theta_r > small_eps)
    {
        Se = (theta - theta_r) / (theta_s - theta_r);
        if (Se < 0.0)
            Se = 0.0;
        if (Se > 1.0)
            Se = 1.0;
    }

    // =========================
    // 4. VG 吸力与非饱和水力传导率
    // =========================

    double suction = 0.0;       // Pa
    double pressure_head = 0.0; // m
    double K_unsat = K_sat;     // 非饱和水力传导率初始化，单位 m/s

    // 数值保护参数
    // TODO 硬编码，可能需要无量纲化
    const double Se_min = 1e-6;     // 避免 pow(0, neg)
    const double Se_ramp = 0.2;     // 当 Se < 0.2 时做平滑
    const double suction_cap = 1e5; // 最大吸力限制（Pa）

    // K 下限随 K_sat 缩放
    const double Kr_min = 1e-4;
    const double K_min = K_sat * Kr_min; // K_sat 已经随尺度缩放过

    if (theta > theta_r && theta < theta_s && theta_s - theta_r > small_eps)
    {
        // 1. 计算原始等效饱和度 Se_raw
        Se = (theta - theta_r) / (theta_s - theta_r);
        if (Se <= Se_min)
        {
            Se = Se_min;
        }
        if (Se > 1.0)
        {
            Se = 1.0;
        }

        // VG 反算压力头：
        // pressure_head = [(Se^(-1/m) - 1)^(1/n)] / alpha
        const double Se_inv = pow(Se, -1.0 / m);
        pressure_head = pow(Se_inv - 1.0, 1.0 / n) / vg_alpha; // m

        // 2. 小 Se 区间做平滑，避免吸力突变
        if (Se <= Se_ramp)
        {
            // 计算平滑权重 w ∈ [0,1]
            double w = Se / Se_ramp;
            if (w < 0.0)
                w = 0.0;
            if (w > 1.0)
                w = 1.0;

            // 平滑（从 0 平滑到正常吸力）
            suction = w * rho_g * pressure_head;
        }
        else
        {
            // 3. 正常 VG 计算区
            suction = rho_g * pressure_head;
        }

        // 4. 最大吸力保护
        if (suction > suction_cap)
            suction = suction_cap;

        // 5. VG 模型下的非饱和渗透率计算
        pressure_head = suction / rho_g; // 若 suction 被截断，则重新计算 pressure_head，保证后续 alpha_h 一致
        // VG-Mualem 非饱和水力传导率
        const double alpha_h = vg_alpha * pressure_head;
        const double temp_1 = pow(alpha_h, n - 1);
        const double temp_2 = pow(alpha_h, n);
        const double temp_fz = pow(1.0 - temp_1 * pow(1.0 + temp_2, -m), 2.0);
        const double temp_fm = pow(1.0 + temp_2, m / 2.0);
        K_unsat = K_sat * temp_fz / temp_fm;
        if (K_unsat < K_min)
            K_unsat = K_min;
    }

    // =========================
    // 5. Darcy–Forchheimer 阻力系数
    // =========================

    // Darcy–Forchheimer方程，层流时退化为达西,S= - (D * viscosity + 0.5 * F *
    // fluid_density * speed) * fluid_v

    const double relax_alpha = plugin_data->data->relax_alpha; // 松弛因子

    // // K_unsat 是水力传导率，单位 m/s
    // 转为固有渗透率 k_intrinsic，单位 m2
    double k_intrinsic = K_unsat * viscosity / (density_for_permeability * gravity); // 固有渗透率，单位 m2

    const double k_intrinsic_min = K_min * viscosity / (density_for_permeability * gravity);
    if (k_intrinsic < k_intrinsic_min)
        k_intrinsic = k_intrinsic_min;

    // Darcy 黏性阻力系数 D = 1/k，单位 1/m2
    double D = 1.0 / k_intrinsic;
    // Forchheimer 惯性阻力系数
    double F = 0.0;

    const double eps_v = 1e-9;

    const bool source_active = speed > eps_v && porosity > 1e-4 && porosity < 0.999 && partical_diameter > 1e-12;
    if (source_active && reynolds > 10)
    {
        F = 1.75 * (1.0 - porosity) / (pow(porosity, 3.0) * partical_diameter); // ergun方程经验值
    }

    const double D_times_viscosity = D * viscosity;
    const double F_times_density_speed = F * fluid_density * speed;

    // =========================
    // 6. 显式源项与隐式源项
    // =========================
    // 半隐式线性化：
    // 目标源项：S = -[mu*D + 0.5*rho*F*|u|]u

    // 显式源项（N/m3)
    double3 source = {0.0, 0.0, 0.0};
    if (source_active)
    {

        source.x = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.x;
        source.y = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.y;
        source.z = relax_alpha * (0.5 * F * fluid_density * speed) * fluid_v.z;
    }

    // 隐式源项系数 (N·s/m4)
    double implicit_factor = 0.0;
    if (source_active)
    {
        implicit_factor =
            -relax_alpha * (D_times_viscosity + F_times_density_speed);
    }

    // =========================
    // 7. 输出辅助变量
    // =========================
    double Kr = 0.0;
    if (K_sat > 0.0)
        Kr = K_unsat / K_sat;

    // 设置颗粒源项
    particle.get_scalars().add_explicit_fluid_momentum(source);
    particle.get_scalars().add_implicit_fluid_momentum(implicit_factor);
    particle.get_scalars().set_scalar<double3>(plugin_data->explicit_source, source);
    particle.get_scalars().set_scalar<double>(plugin_data->implicit_source, implicit_factor);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_saturation, Sr);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_theta, theta);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_effective_saturation, Se);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_suction, suction);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_k_unsat, K_unsat);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_forchheimer_f, F);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_darcy_d, D);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_reynolds, reynolds);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_fluid_speed, speed);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_porosity, porosity);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_kr, Kr);
    particle.get_scalars().set_scalar<double>(plugin_data->fluid_density, fluid_density);
    particle.get_scalars().set_scalar<double>(plugin_data->fluid_viscosity, viscosity);
    particle.get_scalars().set_scalar<double>(plugin_data->density_for_permeability, density_for_permeability);
    particle.get_scalars().set_scalar<double>(plugin_data->d_times_viscosity, D_times_viscosity);
    particle.get_scalars().set_scalar<double>(plugin_data->f_times_density_speed, F_times_density_speed);
    particle.get_scalars().set_scalar<double>(plugin_data->fluent_gravity, gravity);
    particle.get_scalars().set_scalar<double>(plugin_data->vg_k_intrinsic, k_intrinsic);
}

ROCKY_PLUGIN_PRE_FORCE_ON_FLUID_END()

ROCKY_PLUGIN_CFD_COUPLING_END()

ROCKY_PLUGIN_END
