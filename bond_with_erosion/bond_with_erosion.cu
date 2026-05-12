#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api.h>
#include <cmath>
#define M_PI 3.14159265358979323846

struct ModuleMaterialInteraction
{
    bool bonds_enabled;                 // 开关
    double distance_factor;             // 作用距离因子
    double maximum_elongation;          // bond键激活距离
    double normal_stiffness;            // 法向刚度
    double tangential_stiffness;        // 切向刚度
    double damping_ratio;               // 阻尼比
    double normal_stress_limit;         // 法向应力极限
    double tangential_stress_limit;     // 切向应力极限
    double maximum_activation_distance; // 最大激活距离
    double radius_multiplier;           // 半径乘数
    double scale_factor;                // 作用力缩放因子
};

struct ModuleMaterialProperties
{
    double e;   // 孔隙比
    double w_p; // 塑限含水率
    // double c_prime_n; // 饱和有效粘聚力
    // double c_prime_t; // 饱和有效粘聚力
};

struct ModuleData
{
    int ppi_force, pti_force;                                 // 储存bond键的力
    int ppi_moment, pti_moment;                               // 储存bond键力矩
    int ppi_normal_stress_cur, pti_normal_stress_cur;         // 储存bond键的法向应力
    int ppi_tangential_stress_cur, pti_tangential_stress_cur; // 储存bond键的切向应力
    int ppi_normal_stress_linear, pti_normal_stress_linear;         // 储存bond键的法向线性应力
    int ppi_normal_stress_bending, pti_normal_stress_bending;       // 储存bond键的法向弯曲应力
    int ppi_tangential_stress_shear, pti_tangential_stress_shear;   // 储存bond键的切向剪切应力
    int ppi_tangential_stress_torsion, pti_tangential_stress_torsion; // 储存bond键的切向扭转应力
    int ppi_scale_factor_normal_stress_cur, pti_scale_factor_normal_stress_cur;         // 储存缩放后的法向应力
    int ppi_scale_factor_tangential_stress_cur, pti_scale_factor_tangential_stress_cur; // 储存缩放后的切向应力
    int ppi_bond_state, pti_bond_state;                       // bond状态，0为未激活，1为激活，2为破坏
    int ppi_linear_deformation, pti_linear_deformation;       // 储存bond线性变形
    int ppi_angular_deformation, pti_angular_deformation;     // 储存bond角变形
    int ppi_normal_stress_limit, pti_normal_stress_limit;                 // 法向强度
    int ppi_tangential_stress_limit, pti_tangential_stress_limit;         // 切向强度
    int ppi_scale_factor_normal_stress_limit, pti_scale_factor_normal_stress_limit;         // 储存缩放后的法向强度
    int ppi_scale_factor_tangential_stress_limit, pti_scale_factor_tangential_stress_limit; // 储存缩放后的切向强度
    int soft_factor;                                          // 软化程度
    int ppi_soft_factor, pti_soft_factor;                     // 储存软化程度
    double activation_time;                                   // 激活时间
    double search_distance;                                   // 搜索距离
    /* 输出控制 */
    bool output_bond_force;
    bool output_bond_moment;
    bool output_bond_normal_stress;
    bool output_bond_tangential_stress;
    bool output_bond_normal_stress_linear;
    bool output_bond_normal_stress_bending;
    bool output_bond_tangential_stress_shear;
    bool output_bond_tangential_stress_torsion;
    bool output_scaled_bond_normal_stress;
    bool output_scaled_bond_tangential_stress;
    bool output_bond_state;
    bool output_bond_linear_deformation;
    bool output_bond_angular_deformation;
    bool output_contact_normal_stress_limit;
    bool output_contact_tangential_stress_limit;
    bool output_scaled_contact_normal_stress_limit;
    bool output_scaled_contact_tangential_stress_limit;
    bool output_softening_factor;
    ModuleMaterialInteraction *material_interactions;         // 材料交互参数
    ModuleMaterialProperties *material_properties;            // 材料属性
};

// 创造粒子 - 粒子接触标量和粒子 - 三角形接触标量
template <typename T>
inline ROCKY_FUNCTIONS void create_contact_scalars(IRockyModel &model, const char *name, const char *unit, int &pp_scalar_index, int &pt_scalar_index, bool show)
{
    auto pp_scalars = model.get_particle_contact_scalars();
    auto pt_scalars = model.get_triangle_contact_scalars();

    pp_scalar_index = pp_scalars.add<T>(name, unit, show);
    pt_scalar_index = pt_scalars.add<T>(name, unit, show);
}

// 获取粒子 - 粒子接触标量和粒子 - 三角形接触标量
template <typename T>
inline ROCKY_FUNCTIONS T get_contact_scalar_value(IRockyContact &contact, int pp_scalar_index, int pt_scalar_index)
{
    return contact.is_particle_particle_contact()
               ? contact.get_particle_contact_scalars().get_scalar<T>(pp_scalar_index)
               : contact.get_triangle_contact_scalars().get_scalar<T>(pt_scalar_index);
}

// 设置粒子 - 粒子接触标量和粒子 - 三角形接触标量
template <typename T>
inline ROCKY_FUNCTIONS void set_contact_scalar_value(IRockyContact &contact, int pp_scalar_index, int pt_scalar_index, T value)
{
    contact.is_particle_particle_contact()
        ? contact.get_particle_contact_scalars().set_scalar<T>(pp_scalar_index, value)
        : contact.get_triangle_contact_scalars().set_scalar<T>(pt_scalar_index, value);
}

// 重置接触力/力矩
inline ROCKY_FUNCTIONS void reset_contact_forces(IRockyContact &contact, IRockyAdhesionOutputData &output_data, void *module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    output_data.set_normal_force(0);
    output_data.set_tangential_force({0, 0, 0});
    set_contact_scalar_value<double3>(contact, data->ppi_force, data->pti_force, {0, 0, 0});                                // force
    set_contact_scalar_value<double3>(contact, data->ppi_moment, data->pti_moment, {0, 0, 0});                              // moment
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_cur, data->pti_normal_stress_cur, 0.0);         // normal stress
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_cur, data->pti_tangential_stress_cur, 0.0); // tangential stress
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_linear, data->pti_normal_stress_linear, 0.0);         // normal linear stress
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_bending, data->pti_normal_stress_bending, 0.0);       // normal bending stress
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_shear, data->pti_tangential_stress_shear, 0.0);   // tangential shear stress
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_torsion, data->pti_tangential_stress_torsion, 0.0); // tangential torsion stress
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_normal_stress_cur, data->pti_scale_factor_normal_stress_cur, 0.0);         // scaled normal stress
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_tangential_stress_cur, data->pti_scale_factor_tangential_stress_cur, 0.0); // scaled tangential stress
}

// 初始化变形量
inline ROCKY_FUNCTIONS void initialize_deformation(IRockyContact &contact, void *module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    set_contact_scalar_value<double3>(contact, data->ppi_linear_deformation, data->pti_linear_deformation, {0, 0, 0});   // linear
    set_contact_scalar_value<double3>(contact, data->ppi_angular_deformation, data->pti_angular_deformation, {0, 0, 0}); // angular
}
// 更新变形量
inline ROCKY_FUNCTIONS void update_deformation(IRockyContact &contact, void *module_data, const double3 &v_rel, const double3 &w_rel, const double &dt)
{
    // 实现增量更新逻辑
    auto data = static_cast<ModuleData *>(module_data);
    double3 new_linear = get_contact_scalar_value<double3>(contact, data->ppi_linear_deformation, data->pti_linear_deformation) + v_rel * dt;
    double3 new_angular = get_contact_scalar_value<double3>(contact, data->ppi_angular_deformation, data->pti_angular_deformation) + w_rel * dt;
    set_contact_scalar_value<double3>(contact, data->ppi_linear_deformation, data->pti_linear_deformation, new_linear);
    set_contact_scalar_value<double3>(contact, data->ppi_angular_deformation, data->pti_angular_deformation, new_angular);
}

ROCKY_PLUGIN("Bond With Erosion", "1.0.0")

ROCKY_PLUGIN_CONFIGURE(input_data, module_data)
{
    // 开辟储存空间
    auto data = new ModuleData();
    int n_material_interactions = input_data.get_number_material_interactions();
    int n_materials = input_data.get_number_materials();
    data->material_interactions = new ModuleMaterialInteraction[n_material_interactions];
    data->material_properties = new ModuleMaterialProperties[n_materials];
    // 获取一般参数
    auto general_properties = input_data.get_model();
    data->activation_time = general_properties.get_double("activation_time");
    data->search_distance = general_properties.get_double("search_distance");
    data->output_bond_force = general_properties.get_bool("output_bond_force");
    data->output_bond_moment = general_properties.get_bool("output_bond_moment");
    data->output_bond_normal_stress = general_properties.get_bool("output_bond_normal_stress");
    data->output_bond_tangential_stress = general_properties.get_bool("output_bond_tangential_stress");
    data->output_bond_normal_stress_linear = general_properties.get_bool("output_bond_normal_stress_linear");
    data->output_bond_normal_stress_bending = general_properties.get_bool("output_bond_normal_stress_bending");
    data->output_bond_tangential_stress_shear = general_properties.get_bool("output_bond_tangential_stress_shear");
    data->output_bond_tangential_stress_torsion = general_properties.get_bool("output_bond_tangential_stress_torsion");
    data->output_scaled_bond_normal_stress = general_properties.get_bool("output_scaled_bond_normal_stress");
    data->output_scaled_bond_tangential_stress = general_properties.get_bool("output_scaled_bond_tangential_stress");
    data->output_bond_state = general_properties.get_bool("output_bond_state");
    data->output_bond_linear_deformation = general_properties.get_bool("output_bond_linear_deformation");
    data->output_bond_angular_deformation = general_properties.get_bool("output_bond_angular_deformation");
    data->output_contact_normal_stress_limit = general_properties.get_bool("output_contact_normal_stress_limit");
    data->output_contact_tangential_stress_limit = general_properties.get_bool("output_contact_tangential_stress_limit");
    data->output_scaled_contact_normal_stress_limit = general_properties.get_bool("output_scaled_contact_normal_stress_limit");
    data->output_scaled_contact_tangential_stress_limit = general_properties.get_bool("output_scaled_contact_tangential_stress_limit");
    data->output_softening_factor = general_properties.get_bool("output_softening_factor");
    // 获取材料交互参数
    for (int i = 0; i < n_material_interactions; ++i)
    {
        auto &m_i = data->material_interactions[i];
        auto index_mi = input_data.get_material_interaction(i);
        m_i.bonds_enabled = index_mi.get_bool("bonds_enabled");
        m_i.damping_ratio = index_mi.get_double("damping_ratio");
        m_i.distance_factor = index_mi.get_double("distance_factor");
        m_i.maximum_elongation = index_mi.get_double("maximum_elongation");
        m_i.normal_stiffness = index_mi.get_double("normal_stiffness");
        m_i.tangential_stiffness = index_mi.get_double("tangential_stiffness");
        m_i.normal_stress_limit = index_mi.get_double("normal_stress_limit");
        m_i.tangential_stress_limit = index_mi.get_double("tangential_stress_limit");
        m_i.maximum_activation_distance = index_mi.get_double("maximum_activation_distance");
        m_i.radius_multiplier = index_mi.get_double("radius_multiplier");
        m_i.scale_factor = index_mi.get_double("scale_factor");
    }
    // 获取材料属性参数
    for (int i = 0; i < n_materials; ++i)
    {
        auto &m_p = data->material_properties[i];
        auto index_m = input_data.get_material_data(i);
        m_p.e = index_m.get_double("e");
        m_p.w_p = index_m.get_double("w_p");
        // m_p.c_prime_n = index_m.get_double("c_prime_n");
        // m_p.c_prime_t = index_m.get_double("c_prime_t");
    }
    module_data = static_cast<void *>(data);
}

ROCKY_PLUGIN_SETUP(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    // bond力和力矩
    create_contact_scalars<double3>(model, "Bond Force", "N", data->ppi_force, data->pti_force, data->output_bond_force);
    create_contact_scalars<double3>(model, "Bond Moment", "N.m", data->ppi_moment, data->pti_moment, data->output_bond_moment);
    // bond当前法向和切向应力
    create_contact_scalars<double>(model, "Bond Normal Stress", "Pa", data->ppi_normal_stress_cur, data->pti_normal_stress_cur, data->output_bond_normal_stress);
    create_contact_scalars<double>(model, "Bond Tangential Stress", "Pa", data->ppi_tangential_stress_cur, data->pti_tangential_stress_cur, data->output_bond_tangential_stress);
    create_contact_scalars<double>(model, "Bond Normal Stress Linear", "Pa", data->ppi_normal_stress_linear, data->pti_normal_stress_linear, data->output_bond_normal_stress_linear);
    create_contact_scalars<double>(model, "Bond Normal Stress Bending", "Pa", data->ppi_normal_stress_bending, data->pti_normal_stress_bending, data->output_bond_normal_stress_bending);
    create_contact_scalars<double>(model, "Bond Tangential Stress Shear", "Pa", data->ppi_tangential_stress_shear, data->pti_tangential_stress_shear, data->output_bond_tangential_stress_shear);
    create_contact_scalars<double>(model, "Bond Tangential Stress Torsion", "Pa", data->ppi_tangential_stress_torsion, data->pti_tangential_stress_torsion, data->output_bond_tangential_stress_torsion);
    // 缩放后的法向和切向应力
    create_contact_scalars<double>(model, "Scaled Bond Normal Stress", "Pa", data->ppi_scale_factor_normal_stress_cur, data->pti_scale_factor_normal_stress_cur, data->output_scaled_bond_normal_stress);
    create_contact_scalars<double>(model, "Scaled Bond Tangential Stress", "Pa", data->ppi_scale_factor_tangential_stress_cur, data->pti_scale_factor_tangential_stress_cur, data->output_scaled_bond_tangential_stress);
    // bond状态和变形量
    create_contact_scalars<int>(model, "Bond State", "-", data->ppi_bond_state, data->pti_bond_state, data->output_bond_state);
    create_contact_scalars<double3>(model, "Bond Linear Deformation", "m", data->ppi_linear_deformation, data->pti_linear_deformation, data->output_bond_linear_deformation);
    create_contact_scalars<double3>(model, "Bond Angular Deformation", "rad", data->ppi_angular_deformation, data->pti_angular_deformation, data->output_bond_angular_deformation);
    // bond强度
    create_contact_scalars<double>(model, "Contact Normal Stress Limit", "N/m2", data->ppi_normal_stress_limit, data->pti_normal_stress_limit, data->output_contact_normal_stress_limit);
    create_contact_scalars<double>(model, "Contact Tangential Stress Limit", "N/m2", data->ppi_tangential_stress_limit, data->pti_tangential_stress_limit, data->output_contact_tangential_stress_limit);
    // 缩放后的bond强度
    create_contact_scalars<double>(model, "Scaled Contact Normal Stress Limit", "N/m2", data->ppi_scale_factor_normal_stress_limit, data->pti_scale_factor_normal_stress_limit, data->output_scaled_contact_normal_stress_limit);
    create_contact_scalars<double>(model, "Scaled Contact Tangential Stress Limit", "N/m2", data->ppi_scale_factor_tangential_stress_limit, data->pti_scale_factor_tangential_stress_limit, data->output_scaled_contact_tangential_stress_limit);
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_force);
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_moment);
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_linear_deformation);
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_angular_deformation);
    data->soft_factor = -1;
    if (model.get_particle_scalars().find("soften factor") != -1)
    {
        data->soft_factor = model.get_particle_scalars().find("soften factor");
        create_contact_scalars<double>(model, "Softening Factor", "-", data->ppi_soft_factor, data->pti_soft_factor, data->output_softening_factor);
    }
}

ROCKY_PLUGIN_NON_DIMENSIONALIZE(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    int n_material_interactions = model.get_number_of_material_interactions();
    int n_materials = model.get_number_of_materials();
    data->activation_time /= model.get_time_factor();
    data->search_distance /= model.get_length_factor();

    // 无量纲化材料相互作用属性参数
    for (int i = 0; i < n_material_interactions; ++i)
    {
        data->material_interactions[i].maximum_elongation /= model.get_length_factor();
        data->material_interactions[i].normal_stiffness /= (model.get_force_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
        data->material_interactions[i].tangential_stiffness /= (model.get_force_factor() / (model.get_length_factor() * model.get_length_factor() * model.get_length_factor()));
        data->material_interactions[i].normal_stress_limit /= model.get_pressure_factor();
        data->material_interactions[i].tangential_stress_limit /= model.get_pressure_factor();
        data->material_interactions[i].maximum_activation_distance /= model.get_length_factor();
    }
    // 无量纲化材料属性参数
    // for (int i = 0; i < n_materials; ++i)
    // {
    //     data->material_properties[i].c_prime_n /= model.get_pressure_factor();
    //     data->material_properties[i].c_prime_t /= model.get_pressure_factor();
    // }
}

ROCKY_PLUGIN_INITIALIZE_CUDA(model, host_data, device_id, module_device_data)
{
    auto h_data = static_cast<ModuleData *>(host_data);
    auto d_data = *h_data;
    // 拷贝数据
    int size = model.get_number_of_material_interactions();
    int size_m = model.get_number_of_materials();
    ModuleMaterialProperties *d_material_properties = nullptr;
    ModuleMaterialInteraction *d_material_interactions = nullptr;
    CUDA_MALLOC_TYPE(d_material_interactions, size, ModuleMaterialInteraction);
    CUDA_MALLOC_TYPE(d_material_properties, size_m, ModuleMaterialProperties);
    CUDA_COPY_H2D(d_material_properties, h_data->material_properties, size_m);
    CUDA_COPY_H2D(d_material_interactions, h_data->material_interactions, size);
    d_data.material_interactions = d_material_interactions;
    d_data.material_properties = d_material_properties;
    // 拷贝结构体
    ModuleData *device_data = nullptr;
    CUDA_MALLOC_TYPE(device_data, 1, ModuleData);
    CUDA_COPY_H2D(device_data, &d_data, 1);

    module_device_data = static_cast<void *>(device_data);
}

ROCKY_PLUGIN_COMPUTE_ADHESIVE_DISTANCES(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    const double search_distance = data->search_distance;
    int n_groups = model.get_number_particle_groups();
    for (int i = 0; i < n_groups; ++i)
    {
        int m_index_i = model.get_particle_material_index(i);
        for (int j = i; j < n_groups; ++j)
        {
            int m_index_j = model.get_particle_material_index(j);
            model.set_adhesive_distance(m_index_i, m_index_j, search_distance);
        }
        for (int bm = 0; bm < model.get_number_geometry_materials(); ++bm)
        {
            int m_index_bm = model.get_geometry_material_index(bm);
            model.set_adhesive_distance(m_index_i, m_index_bm, search_distance);
        }
    }
}

ROCKY_PLUGIN_PRE_OUTPUT(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    // 设置接触标量的量纲
    // 力/力矩单位转换为N和N.m
    model.get_particle_contact_scalars().set_dimension(data->ppi_force, model.get_force_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_force, model.get_force_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_moment, model.get_force_factor() * model.get_length_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_moment, model.get_force_factor() * model.get_length_factor());
    // bond 强度单位转换为Pa
    model.get_particle_contact_scalars().set_dimension(data->ppi_normal_stress_limit, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_normal_stress_limit, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_tangential_stress_limit, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_tangential_stress_limit, model.get_pressure_factor());
    // bond 缩放后的强度单位转换为Pa
    model.get_particle_contact_scalars().set_dimension(data->ppi_scale_factor_normal_stress_limit, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_scale_factor_normal_stress_limit, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_scale_factor_tangential_stress_limit, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_scale_factor_tangential_stress_limit, model.get_pressure_factor());
    // bond 当前应力单位转换为Pa
    model.get_particle_contact_scalars().set_dimension(data->ppi_normal_stress_cur, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_normal_stress_cur, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_tangential_stress_cur, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_tangential_stress_cur, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_normal_stress_linear, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_normal_stress_linear, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_normal_stress_bending, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_normal_stress_bending, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_tangential_stress_shear, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_tangential_stress_shear, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_tangential_stress_torsion, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_tangential_stress_torsion, model.get_pressure_factor());
    // bond 变形量单位转换为m和rad
    model.get_particle_contact_scalars().set_dimension(data->ppi_linear_deformation, model.get_length_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_linear_deformation, model.get_length_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_angular_deformation, 1.0);
    model.get_triangle_contact_scalars().set_dimension(data->pti_angular_deformation, 1.0);
    // bond 缩放后的当前应力单位转换为Pa
    model.get_particle_contact_scalars().set_dimension(data->ppi_scale_factor_normal_stress_cur, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_scale_factor_normal_stress_cur, model.get_pressure_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_scale_factor_tangential_stress_cur, model.get_pressure_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_scale_factor_tangential_stress_cur, model.get_pressure_factor());
}

ROCKY_PLUGIN_TEAR_DOWN_CUDA(model, device_id, device_data)
{
    auto d_data = static_cast<ModuleData *>(device_data);
    ModuleData data_ptr;
    CUDA_COPY_D2H(&data_ptr, d_data, 1);
    CUDA_FREE(data_ptr.material_interactions);
    CUDA_FREE(data_ptr.material_properties);
    CUDA_FREE(d_data);
}

ROCKY_PLUGIN_TEAR_DOWN(model, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    delete[] data->material_interactions;
    delete[] data->material_properties;
    delete data;
}

ROCKY_PLUGIN_COMPUTE_CONTACT_ADHESIVE_FORCES(contact, output_data, module_data)
{
    auto data = static_cast<ModuleData *>(module_data);
    const int m_i = contact.get_material_interaction_index();

    // 判断接触是否激活bond
    int bond_state = get_contact_scalar_value<int>(contact, data->ppi_bond_state, data->pti_bond_state);
    // 断裂bond直接返回并且清零
    if (bond_state == 2)
    {
        set_contact_scalar_value<int>(contact, data->ppi_bond_state, data->pti_bond_state, 2); // 标记断裂
        reset_contact_forces(contact, output_data, module_data);
        set_contact_scalar_value<double>(contact, data->ppi_normal_stress_limit, data->pti_normal_stress_limit, 0);
        set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_limit, data->pti_tangential_stress_limit, 0);
        set_contact_scalar_value<double>(contact, data->ppi_scale_factor_normal_stress_limit, data->pti_scale_factor_normal_stress_limit, 0);
        set_contact_scalar_value<double>(contact, data->ppi_scale_factor_tangential_stress_limit, data->pti_scale_factor_tangential_stress_limit, 0);
        return;
    }
    // 提前获取并存储强度
    double normal_force_limit = data->material_interactions[m_i].normal_stress_limit;         // 法向强度
    double tangential_force_limit = data->material_interactions[m_i].tangential_stress_limit; // 切向强度
    double prev_normal_force_limit =  normal_force_limit;
    double prev_tangential_force_limit = tangential_force_limit;
    if(bond_state == 1)
    {
        // 读取上一步强度
        prev_normal_force_limit = get_contact_scalar_value<double>(contact, data->ppi_normal_stress_limit, data->pti_normal_stress_limit);
        prev_tangential_force_limit = get_contact_scalar_value<double>(contact, data->ppi_tangential_stress_limit, data->pti_tangential_stress_limit);
    }
    // 激活机制修正
    const double current_time = contact.get_current_time();
    const double dt = contact.get_timestep();
    if (bond_state == 0)
    {

        // 判断激活时间步
        const bool is_activation_step = ((current_time >= data->activation_time) && ((current_time - dt) <= data->activation_time));
        if (is_activation_step)
        {
            // 计算激活距离
            const double s = contact.get_overlap();
            const double radii = contact.is_particle_particle_contact() ? (0.5 * contact.get_home_particle().get_size() + 0.5 * contact.get_near_particle().get_size()) : (2 * 0.5 * contact.get_home_particle().get_size());
            const double activation_distance = data->material_interactions[m_i].maximum_activation_distance;
            const double s_minor_penetration = 0.001 * (radii); // 重叠判断
            double h_ac = data->material_interactions[m_i].distance_factor * radii;
            h_ac = rocky::dmin(h_ac, activation_distance);
            const double delta_search = h_ac + data->material_interactions[m_i].maximum_elongation; // 最大激活距离
            // 创建新bond
            if (s <= s_minor_penetration && data->material_interactions[m_i].bonds_enabled && fabs(s) <= delta_search)
            {
                bond_state = 1;                                                                                 // 更新当前bond_state
                set_contact_scalar_value<int>(contact, data->ppi_bond_state, data->pti_bond_state, bond_state); // 激活bond
                initialize_deformation(contact, module_data);                                                   // 初始化变形量
            }
        }
    }
    // 仅处理激活态bond
    if (bond_state != 1)
    {
        reset_contact_forces(contact, output_data, module_data);
        return;
    }
    // 计算near速度
    double3 v_near = {0.0, 0.0, 0.0}, w_near = {0.0, 0.0, 0.0};
    if (contact.is_particle_particle_contact())
    {
        v_near = contact.get_near_particle().get_translational_velocity();
        w_near = contact.get_near_particle().get_rotational_velocity();
    }
    else
    {
        v_near = contact.get_near_triangle().get_translational_velocity(current_time);
        w_near = contact.get_near_triangle().get_geometry_rotational_velocity();
    }

    // 相对速度计算
    double3 v_home = contact.get_home_particle().get_translational_velocity(); // home平动速度
    double3 w_home = contact.get_home_particle().get_rotational_velocity();    // home旋转速度
    double3 bond_radii_home = contact.get_contact_position() - contact.get_home_particle().get_centroid_position();
    double3 bond_radii_near = {0.0, 0.0, 0.0};
    if (contact.is_particle_particle_contact())
    {
        bond_radii_near = contact.get_contact_position() - contact.get_near_particle().get_centroid_position();
    }
    else
    {
        bond_radii_near = -bond_radii_home;
    }
    const double3 v_rel = v_home - v_near + rocky::vector::cross<double3, false>(w_home, bond_radii_home) - rocky::vector::cross<double3, false>(w_near, bond_radii_near);
    const double3 w_rel = w_home - w_near;

    // 变形量更新
    update_deformation(contact, data, v_rel, w_rel, dt);

    // 力/力矩计算
    // 计算弹性力
    double r_b = contact.get_equivalent_radius(); // 等效半径
    if (contact.is_particle_particle_contact())
        r_b = data->material_interactions[m_i].radius_multiplier * rocky::dmin(0.5 * contact.get_home_particle().get_size(), 0.5 * contact.get_near_particle().get_size()); // 半径
    else
        r_b = data->material_interactions[m_i].radius_multiplier * 0.5 * contact.get_home_particle().get_size(); // 半径

    const double3 bond_normal_vector = contact.get_normal_unit_vector(); // rocky::vector::normalize(contact.get_home_particle().get_centroid_position() - contact.get_contact_position()); // bond键单位法向量
    const double3 s_b = get_contact_scalar_value<double3>(contact, data->ppi_linear_deformation, data->pti_linear_deformation);
    const double s_n = rocky::vector::dot(s_b, bond_normal_vector);                            // 法向线变形
    const double3 s_i = s_b - s_n * bond_normal_vector;                                        // 切向线变形
    const double normal_stiffness = data->material_interactions[m_i].normal_stiffness;         // 法向刚度
    const double tangential_stiffness = data->material_interactions[m_i].tangential_stiffness; // 切向刚度
    const double A_b = M_PI * r_b * r_b;
    double f_b_n = -normal_stiffness * A_b * s_n;      // 法向弹性力
    double3 f_b_i = -tangential_stiffness * A_b * s_i; // 切向弹性力
    // 计算弹性力矩
    const double3 theta_b = get_contact_scalar_value<double3>(contact, data->ppi_angular_deformation, data->pti_angular_deformation);
    const double theta_n = rocky::vector::dot(theta_b, bond_normal_vector); // 法向角变形
    const double3 theta_i = theta_b - theta_n * bond_normal_vector;         // 切向角变形
    const double J_b = 0.5 * M_PI * pow(r_b, 4);                            // 惯性矩
    const double I_b = 0.25 * M_PI * pow(r_b, 4);                           // 惯性矩
    double M_b_t = -tangential_stiffness * J_b * theta_n;                   // 弹性扭矩
    double3 M_b_b = -normal_stiffness * I_b * theta_i;                      // 弹性弯矩
    // 计算阻尼力
    const double damping_ratio = data->material_interactions[m_i].damping_ratio;
    const double m_star = contact.get_equivalent_mass();
    const double v_rel_n = rocky::vector::dot(v_rel, bond_normal_vector);
    const double3 v_rel_i = v_rel - v_rel_n * bond_normal_vector;
    const double w_rel_n = rocky::vector::dot(w_rel, bond_normal_vector);
    const double3 w_rel_i = w_rel - w_rel_n * bond_normal_vector;
    double f_bv_n = -2 * damping_ratio * sqrt(normal_stiffness * A_b * m_star) * v_rel_n;
    double3 f_bv_i = -2 * damping_ratio * sqrt(tangential_stiffness * A_b * m_star) * v_rel_i;
    double M_bv_t = -2 * damping_ratio * sqrt(tangential_stiffness * A_b * m_star) * J_b * w_rel_n / A_b;
    double3 M_bv_b = -2 * damping_ratio * sqrt(normal_stiffness * A_b * m_star) * I_b * w_rel_i / A_b;
    // 整合法向力，切向力，扭矩以及弯矩
    double normal_force = f_b_n + f_bv_n;
    double3 new_normal_force = normal_force * bond_normal_vector; // 法向力
    double3 new_tangential_force = f_b_i + f_bv_i;                // 切向力
    double torsiona_moment = M_b_t + M_bv_t;
    double3 new_torsiona_moment = torsiona_moment * bond_normal_vector; // 扭矩
    double3 new_bend_moment = M_b_b + M_bv_b;                           // 弯矩

    // 强度弱化
    if (data->soft_factor != -1)
    {
        // 材料常数
        int home_material_index = contact.get_home_particle().get_material_index();
        const double G_s = 2.71;                                               // 土粒比重
        const double e = data->material_properties[home_material_index].e;     // 孔隙比
        const double w_p = data->material_properties[home_material_index].w_p; // 塑限含水率
        const double S_rp = (w_p * G_s) / e;                                   // 塑限饱和度
        // const double c_prime_n = data->material_properties[home_material_index].c_prime_n; // 饱和有效粘聚力
        // const double c_prime_t = data->material_properties[home_material_index].c_prime_t; // 饱和有效粘聚力
        // 计算接触饱和度
        double home_saturation = contact.get_home_particle().get_scalars().get_scalar<double>(data->soft_factor);
        double near_saturation = 0.0;

        if (contact.is_particle_particle_contact())
        {
            near_saturation = contact.get_near_particle().get_scalars().get_scalar<double>(data->soft_factor);
        }
        else
        {
            near_saturation = home_saturation;
        }
        double avg_saturation = (home_saturation + near_saturation) / 2;
        set_contact_scalar_value<double>(contact, data->ppi_soft_factor, data->pti_soft_factor, avg_saturation); // 存储平均饱和度
        // 根据饱和度计算强度衰减因子
        double reduction_factor_norm = 1.0; // 法向强度衰减因子
        double reduction_factor_tang = 1.0; // 切向强度衰减因子

        // 计算强度衰减因子
        if (avg_saturation < S_rp)
        {
            // 低于塑限：对数衰减
            double w = 100 * avg_saturation * e / G_s; // 换算含水率（%）
            // 壁面w小于1时，强度衰减过大，导致数值不稳定，故限定w最小值为1.0
            w = rocky::dmax(1.0, w);
            // 经验公式，对数衰减
            double log_w = log(w);
            reduction_factor_norm = rocky::dmax(0.0, (1.0 - 0.297 * log_w));
            reduction_factor_tang = rocky::dmax(0.0, (1.0 - 0.297 * log_w)); 
        }
        else 
        {
            reduction_factor_norm =  1.0 - 0.297 * log(w_p * 100);
            reduction_factor_tang =  1.0 - 0.297 * log(w_p * 100);
        }

        normal_force_limit *= reduction_factor_norm ;     // 法向强度
        tangential_force_limit *= reduction_factor_tang ; // 切向强度

        // 确保强度不超过上一步
        normal_force_limit = rocky::dmin(normal_force_limit, prev_normal_force_limit);
        tangential_force_limit = rocky::dmin(tangential_force_limit, prev_tangential_force_limit);
        // 确保强度非负
        normal_force_limit = rocky::dmax(0.0, normal_force_limit);
        tangential_force_limit = rocky::dmax(0.0, tangential_force_limit);
    }

    // 断裂判断修正
    double scale_factor = 1000 / (data->material_interactions[m_i].scale_factor);

    // 存储更新后的强度数据
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_limit, data->pti_normal_stress_limit, normal_force_limit);
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_limit, data->pti_tangential_stress_limit, tangential_force_limit);
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_normal_stress_limit, data->pti_scale_factor_normal_stress_limit, normal_force_limit * pow(scale_factor, 2));
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_tangential_stress_limit, data->pti_scale_factor_tangential_stress_limit, tangential_force_limit * pow(scale_factor, 2));

    // 断裂判断修正
    double normal_stress_linear = -f_b_n / A_b;
    double normal_stress_bending = rocky::vector::get_norm(M_b_b) * r_b / I_b;
    double tangential_stress_shear = rocky::vector::get_norm(f_b_i) / A_b;
    double tangential_stress_torsion = M_b_t * r_b / J_b;
    double maximum_normal_stress = normal_stress_linear + normal_stress_bending;
    double maximum_tangential_stress = tangential_stress_shear + tangential_stress_torsion;
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_cur, data->pti_normal_stress_cur, maximum_normal_stress);
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_cur, data->pti_tangential_stress_cur, maximum_tangential_stress);
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_linear, data->pti_normal_stress_linear, normal_stress_linear);
    set_contact_scalar_value<double>(contact, data->ppi_normal_stress_bending, data->pti_normal_stress_bending, normal_stress_bending);
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_shear, data->pti_tangential_stress_shear, tangential_stress_shear);
    set_contact_scalar_value<double>(contact, data->ppi_tangential_stress_torsion, data->pti_tangential_stress_torsion, tangential_stress_torsion);
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_normal_stress_cur, data->pti_scale_factor_normal_stress_cur, pow(scale_factor,3) * maximum_normal_stress);
    set_contact_scalar_value<double>(contact, data->ppi_scale_factor_tangential_stress_cur, data->pti_scale_factor_tangential_stress_cur, pow(scale_factor,3) * maximum_tangential_stress);
    const bool stress_exceeded = (pow(scale_factor,3) * maximum_normal_stress >= pow(scale_factor,2) * normal_force_limit || pow(scale_factor,3) * maximum_tangential_stress >=pow(scale_factor,2) * tangential_force_limit);
    if (stress_exceeded)
    {
        set_contact_scalar_value<int>(contact, data->ppi_bond_state, data->pti_bond_state, 2); // 标记断裂
        reset_contact_forces(contact, output_data, module_data);                               // 立即清零
        return;
    }

    // 存储显示数据
    double3 total_moment = new_torsiona_moment + new_bend_moment;
    double3 total_force = new_normal_force + new_tangential_force;
    set_contact_scalar_value<double3>(contact, data->ppi_force, data->pti_force, total_force * contact.get_scale_factor());
    set_contact_scalar_value<double3>(contact, data->ppi_moment, data->pti_moment, total_moment * contact.get_scale_factor());

    // 施加成对作用力
    // 力/力矩施加修正
    // 力矩施加（补充near粒子反作用力）
    contact.get_home_particle().add_moment(total_moment);
    if (contact.is_particle_particle_contact())
    {
        contact.get_near_particle().add_moment(-total_moment);
    }
    output_data.set_normal_force(normal_force);
    output_data.set_tangential_force(new_tangential_force);
}
ROCKY_PLUGIN_COMPUTE_CONTACT_ADHESIVE_FORCES_END()

ROCKY_PLUGIN_END
