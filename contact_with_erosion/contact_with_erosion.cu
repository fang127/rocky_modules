#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api.h>
#define SMALL_VALUE 1.0e-15
#define SMALL_VALUE_2 1.0e-10
#define M_PI 3.14159265358979323846

// 结构体，用于储存ui界面输入的该模块的数据
struct ModuleMaterialInteraction
{
    double surface_energy; //表面能
    double sliding_velocity_threshold; // 滑动速度阈值sliding_velocity_threshold
};

// 结构体，储存在计算时，分配给该模块接触表量的索引
struct ModuleData
{
    // ppi代表粒子-粒子索引，而pti代表粒子-边界三角形索引
    int ppi_normal,pti_normal; // 法向力
    int ppi_tangential,pti_tangential; // 弹性切向力，储存double3类型
    int ppi_dis_tangential,pti_dis_tangential; // 阻尼切向力，储存double3类型
    int ppi_sliding_distance,pti_sliding_distance;

    // double S_r = 1;

    ModuleMaterialInteraction *material_interactions;
};

// 创造粒子 - 粒子接触标量和粒子 - 三角形接触标量
template<typename T>
inline ROCKY_FUNCTIONS void create_contact_scalars(IRockyModel &model,const char* name,const char* unit,int &pp_scalar_index,int &pt_scalar_index)
{
    auto pp_scalars = model.get_particle_contact_scalars();
    auto pt_scalars = model.get_triangle_contact_scalars();

    pp_scalar_index = pp_scalars.add<T>(name,unit,true);
    pt_scalar_index = pt_scalars.add<T>(name,unit,true);
}

// 获取粒子 - 粒子接触标量和粒子 - 三角形接触标量
template<typename T>
inline ROCKY_FUNCTIONS T get_contact_scalar_value(IRockyContact &contact,int pp_scalar_index,int pt_scalar_index)
{
    return contact.is_particle_particle_contact() 
    ? contact.get_particle_contact_scalars().get_scalar<T>(pp_scalar_index)
    : contact.get_triangle_contact_scalars().get_scalar<T>(pt_scalar_index);
}

// 设置粒子 - 粒子接触标量和粒子 - 三角形接触标量
template<typename T>
inline ROCKY_FUNCTIONS void set_contact_scalar_value(IRockyContact &contact, int pp_scalar_index, int pt_scalar_index, T value)
{
    contact.is_particle_particle_contact() 
    ? contact.get_particle_contact_scalars().set_scalar<T>(pp_scalar_index, value)
    : contact.get_triangle_contact_scalars().set_scalar<T>(pt_scalar_index, value);
}

// 解析法求解JKR接触半径 (从Rocky内置代码复制)
inline ROCKY_FUNCTIONS double solve_jkr_contact_radius(double E_star, double R_star, double overlap, double surface_energy)
{
    /* Real root larger than sqrt(R_start * overlap) of the quartic equation
       a^4 - 2.0 * overlap * R_star * a^2 - 2.0 * pi * surface_energy * R_star^2 / E_star * a + (R_star * overlap)^2 = 0 */
    const double alpha = -2.0 * overlap * R_star;
    const double beta = -2.0 * M_PI * surface_energy * R_star * R_star / E_star;
    const double gamma = overlap * overlap * R_star * R_star;

    const double P = -alpha * alpha / 12.0 - gamma;
    const double Q = -alpha * alpha * alpha / 108.0 + alpha * gamma / 3.0 - 0.125 * beta * beta;
    const double U = cbrt(-0.5 * Q + sqrt(0.25 * Q * Q + P * P * P / 27.0));
    const double s = fabs(P) > SMALL_VALUE
        ? -5.0 / 6.0 * alpha + U - P / (3.0 * U)
        : -5.0 / 6.0 * alpha - cbrt(Q);
    const double w = sqrt(alpha + 2.0 * s);
    const double l = 0.5 * beta / w;

    return 0.5 * (w + sqrt(w * w - 4.0 * (alpha + s + l)));
}
// 计算阻尼比
inline ROCKY_FUNCTIONS double get_damping_ratio(double restitution_coefficient)
{
    const int n_points = 200;
    const double rc_min = 1.0 / (double)n_points;
    const double rc_max = 1.0;
    const double rc_delta = (rc_max - rc_min) / (double)(n_points - 1);

    const double damping_ratio[200] = 
    {
		6.91312427549934,4.80694180177965,3.86679804104916,3.30292300444048,2.91607227250060,2.62915570722940,2.40520022728050,2.22395454101025,2.07326778291948,1.94534618440771,1.83492858287806,1.73831686951498,1.65282485963303,1.57644759899473,1.50765391841130,1.44525136756020,1.38829544711461,1.33602692559862,1.28782751231661,1.24318785101378,1.20168397928146,1.16295972712443,1.12671336034811,1.09268730895178,1.06066017177982,1.03044042394755,1.00186141413003,0.97477735023637,0.94906005051508,0.92459629324992,0.90128563882710,0.87903862771549,0.85777527994892,0.83742383820234,0.81791970902598,0.79920456631306,0.78122558839229,0.76393480580686,0.74728854127117,0.73124692678045,0.71577348560660,0.70083476911194,0.68640004007419,0.67244099563631,0.65893152414592,0.64584749108645,0.63316655007014,0.62086797549359,0.60893251397866,0.59734225215346,0.58608049868880,0.57513167880652,0.56448123972895,0.55411556575175,0.54402190180221,0.53418828449778,0.52460347984933,0.51525692686438,0.50613868640039,0.49723939469929,0.48855022110472,0.48006282952346,0.47176934324508,0.46366231277883,0.45573468640630,0.44797978318255,0.44039126814846,0.43296312954305,0.42568965782763,0.41856542635369,0.41158527352431,0.40474428631429,0.39803778502840,0.39146130918895,0.38501060445509,0.37868161048575,0.37247044966661,0.36637341662933,0.36038696849787,0.35450771580309,0.34873241401198,0.34305795562293,0.33748136278288,0.33199978038595,0.32661046961695,0.32131080190605,0.31609825326419,0.31097039897091,0.30592490858924,0.30095954128379,0.29607214142061,0.29126063442903,0.28652302290699,0.28185738295329,0.27726186071121,0.27273466910915,0.26827408478531,0.26387844518402,0.25954614581264,0.25527563764865,0.25106542468711,0.24691406161980,0.24282015163759,0.23878234434845,0.23479933380398,0.23086985662772,0.22699269023924,0.22316665116808,0.21939059345242,0.21566340711728,0.21198401672775,0.20835138001285,0.20476448655601,0.20122235654834,0.19772403960121,0.19426861361478,0.19085518369942,0.18748288114712,0.18415086245008,0.18085830836414,0.17760442301441,0.17438843304100,0.17120958678277,0.16806715349700,0.16496042261317,0.16188870301919,0.15885132237825,0.15584762647490,0.15287697858878,0.14993875889475,0.14703236388796,0.14415720583275,0.14131271223423,0.13849832533133,0.13571350161042,0.13295771133844,0.13023043811468,0.12753117844026,0.12485944130455,0.12221474778772,0.11959663067871,0.11700463410784,0.11443831319352,0.11189723370230,0.10938097172176,0.10688911334561,0.10442125437050,0.10197700000405,0.09955596458348,0.09715777130463,0.09478205196060,0.09242844668996,0.09009660373382,0.08778617920154,0.08549683684472,0.08322824783907,0.08098009057387,0.07875205044874,0.07654381967730,0.07435509709764,0.07218558798911,0.07003500389536,0.06790306245325,0.06578948722752,0.06369400755084,0.06161635836917,0.05955628009222,0.05751351844865,0.05548782434603,0.05347895373529,0.05148666747948,0.04951073122667,0.04755091528689,0.04560699451293,0.04367874818484,0.04176595989801,0.03986841745471,0.03798591275895,0.03611824171453,0.03426520412623,0.03242660360389,0.03060224746943,0.02879194666666,0.02699551567369,0.02521277241798,0.02344353819383,0.02168763758238,0.01994489837379,0.01821515149175,0.01649823092017,0.01479397363191,0.01310221951955,0.01142281132817,0.00975559458990,0.00810041756044,0.00645713115724,0.00482558889947,0.00320564684954,0.00159716355636,0.00000000000000
    };

    int i = (int)((restitution_coefficient - rc_min) / rc_delta);
    i = min(max(i, 0), (n_points - 2));
    double a = (restitution_coefficient - rc_min - (double)i * rc_delta) / rc_delta;
    return (1.0 - a) * damping_ratio[i] + a * damping_ratio[i + 1];
}
// 计算重叠量的时间导数
inline ROCKY_FUNCTIONS double get_overlap_time_derivative(IRockyContact contact, double normal_relative_velocity)
{
    double previous_overlap = contact.get_previous_overlap();
    const double overlap = contact.get_overlap();
    const double timestep = contact.get_timestep();

    return (overlap - rocky::dmax(previous_overlap, 0.0)) / timestep;
}

// 链接module
ROCKY_PLUGIN("Contact With Erosion", "1.0.1")
// 保存ui输入的数据
ROCKY_PLUGIN_CONFIGURE(input_data, module_data) 
{
    //给所有数据开辟内存空间
    auto data = new ModuleData();
    int n_material_interactions = input_data.get_number_material_interactions();
    data->material_interactions = new ModuleMaterialInteraction[n_material_interactions];
    // 获取设置的材料相互作用的数据参数
    for(int i=0; i<n_material_interactions; i++) 
    {
        auto &m_i = data->material_interactions[i];
        auto input_mi = input_data.get_material_interaction(i);
        m_i.surface_energy = input_mi.get_double("surface_energy");
        m_i.sliding_velocity_threshold = input_mi.get_double("sliding_velocity_threshold");
    }
    module_data = static_cast<void*>(data);
}

ROCKY_PLUGIN_SETUP(model,module_data)
{
    auto data = static_cast<ModuleData*>(module_data);
    // 创造粒子 - 粒子接触标量和粒子 - 三角形接触标量，用来储存相应的力
    create_contact_scalars<double>(model,"Previous Normal Force","N",data->ppi_normal,data->pti_normal);
    create_contact_scalars<double3>(model,"Elastic Tangential Force","N",data->ppi_tangential,data->pti_tangential);
    create_contact_scalars<double3>(model,"Dissipative Tangential Force","N",data->ppi_dis_tangential,data->pti_dis_tangential);
    create_contact_scalars<double>(model,"sliding distance","m",data->ppi_sliding_distance,data->pti_sliding_distance);
    // 开启必要的标量数据
    model.get_particle_contact_scalars().enable_storage_is_sliding_marker();
    model.get_triangle_contact_scalars().enable_storage_is_sliding_marker();
    model.get_particle_contact_scalars().enable_storage_previous_normal_vector();
    model.get_triangle_contact_scalars().enable_storage_previous_normal_vector();
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_tangential);
    model.get_particle_contact_scalars().mark_scalar_as_history_dependent(data->ppi_dis_tangential);
    model.get_particle_contact_scalars().enable_storage_normal_adhesion_force();
    model.get_triangle_contact_scalars().enable_storage_normal_adhesion_force();
    // 设置自定义数据的量纲
    model.get_particle_contact_scalars().set_dimension(data->ppi_normal,model.get_force_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_normal,model.get_force_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_tangential,model.get_force_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_tangential,model.get_force_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_dis_tangential,model.get_force_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_dis_tangential,model.get_force_factor());
    model.get_particle_contact_scalars().set_dimension(data->ppi_sliding_distance,model.get_length_factor());
    model.get_triangle_contact_scalars().set_dimension(data->pti_sliding_distance,model.get_length_factor());
}

ROCKY_PLUGIN_NON_DIMENSIONALIZE(model,module_data)
{
    auto data = static_cast<ModuleData*>(module_data);
    int n_material_interactions = model.get_number_of_material_interactions();
    for(int i = 0;i < n_material_interactions;i++)
    {
        data->material_interactions[i].sliding_velocity_threshold /= model.get_length_factor() / model.get_time_factor();
        data->material_interactions[i].surface_energy /= model.get_energy_factor() / (model.get_length_factor() * model.get_length_factor());
    }
}

// 初始化cuda
ROCKY_PLUGIN_INITIALIZE_CUDA(model,host_data,device_id,module_device_data)
{
    auto h_data = static_cast<ModuleData*>(host_data);
    auto d_data = *h_data;
    // 为gpu分配material_interactions内存
    int size = model.get_number_of_material_interactions(); //获取个数
    ModuleMaterialInteraction *d_material_interactions = nullptr;//定义一个指针同时置空
    CUDA_MALLOC_TYPE(d_material_interactions,size,ModuleMaterialInteraction);// 分配内容，利用指针指向该内存
    // 拷贝数据
    CUDA_COPY_H2D(d_material_interactions,h_data->material_interactions,size);// 将主机数据拷贝到gpu
    d_data.material_interactions = d_material_interactions;

    // 为gpu分配module data内存
    ModuleData *device_data = nullptr;
    CUDA_MALLOC_TYPE(device_data,1,ModuleData);
    CUDA_COPY_H2D(device_data,&d_data,1);

    module_device_data = static_cast<void*>(device_data);
}

// 赫兹法向力修正计算
ROCKY_PLUGIN_NORMAL_FORCE_ON_CONTACTS(contact,intermediate_data,output_data,module_data)
{
    auto data = static_cast<ModuleData*>(module_data);
    // 获取参数
    auto m_index = contact.get_material_interaction_index();
    const double Gamma = data->material_interactions[m_index].surface_energy;
    const double R_star = contact.get_equivalent_radius();
    const double E_star = contact.get_reduced_young_modulus();
    const double overlap = max(0.0,contact.get_overlap());
    
    // 弹性力
    // 求解接触半径
    const double contact_radius = solve_jkr_contact_radius(E_star, R_star, overlap, Gamma);
    const double a3 = contact_radius * contact_radius * contact_radius;
    double elastic_force =  4.0 / 3.0 * E_star * a3 / R_star;


    // 阻尼力
    const double damping_ratio = get_damping_ratio(contact.get_restitution_coefficient());
    const double overlap_derivative = get_overlap_time_derivative(contact,output_data.get_normal_relative_velocity());
    const double m_star = contact.get_equivalent_mass();
    
    const double stiffness = 4.0 / 3.0 * E_star * sqrt(R_star * overlap);
    const double damping_coefficient = 2.0 * HERTZ_DAMPING_SCALING * damping_ratio * sqrt(m_star * stiffness);
    const double damping_force = damping_coefficient * overlap_derivative;

    double new_normal_force = max(0.0,elastic_force + damping_force);
    output_data.set_normal_force(new_normal_force);
    set_contact_scalar_value<double>(contact,data->ppi_normal,data->pti_normal,elastic_force); // 将计算得到的法向力储存到自定义的ModuleData结构体中，方便下一步的计算
}
ROCKY_PLUGIN_NORMAL_FORCE_ON_CONTACTS_END() // 结束自定义法向力的计算

// 明德林切向力计算
ROCKY_PLUGIN_TANGENTIAL_FORCE_ON_CONTACTS(contact,intermediate_data,output_data,module_data)
{
    auto data = static_cast<ModuleData*>(module_data); // 获取自定义数据
    // 获取摩擦系数
    bool is_sliding = contact.get_is_sliding_marker();
    const double mu = is_sliding?contact.get_material_interaction().get_dynamic_friction_coefficient():contact.get_material_interaction().get_static_friction_coefficient();
    const double overlap = contact.get_overlap(); // 获取重叠量

    output_data.set_tangential_force({0.0,0.0,0.0});
    is_sliding = false;
    output_data.set_sliding(is_sliding);
    set_contact_scalar_value<double>(contact,data->ppi_sliding_distance,data->pti_sliding_distance,0.0);
    if(mu < SMALL_VALUE_2 || overlap < SMALL_VALUE_2) 
    {
        set_contact_scalar_value<double3>(contact,data->ppi_tangential,data->pti_tangential,{0.0,0.0,0.0});
        return;
    }// 摩擦系数或者重叠量接近0，不用计算切向力
    
    // maximum relative tangential displacement
    const double v_h = contact.get_home_material().get_poisson_ratio();
    const double v_n = contact.get_near_material().get_poisson_ratio();
    const double maximum_displacement = mu * overlap / ((1 - v_h) / (2 - v_h) + (1 - v_n) / (2 - v_n));

    // 接触检查​：如果前一步存在接触，计算；否则，跳过历史位移计算（置0）。
    const double overlap_prev = contact.get_previous_overlap(); // 获取上一步重叠量
    double3 previous_displacement_vector = {0,0,0}; // 初始化上一步切向位移
    if(overlap_prev > SMALL_VALUE_2) // 当上一步重叠量大于0才计算
    {
        // 上一步法向力
        const double previous_normal_force = contact.get_normal_contact_force() + contact.get_normal_adhesion_force();// contact.get_normal_contact_force();
        // 上一步切向力大小                              
        const double3 previous_tangential_force_vector = contact.just_started_frictional()?
                                                        make_double3(0.0,0.0,0.0):
                                                        get_contact_scalar_value<double3>(contact,data->ppi_tangential,data->pti_tangential);
        // const double3 previous_tangential_force_vector = contact.get_tangential_contact_force();
        const double previous_tangential_force = get_norm(previous_tangential_force_vector);
        
        // 当上一步法向力和切向力大小都大于0时，才计算
        if(previous_tangential_force > SMALL_VALUE_2 && previous_normal_force > SMALL_VALUE_2)
        {
            // Mindlin 非线性弹性位移关系
            const double ratio = previous_tangential_force / (mu * previous_normal_force);
            double length = maximum_displacement * overlap_prev / overlap;
            if(ratio <= 0.999)
            {

                length *= (1.0 - pow((1.0 - ratio), (2.0 / 3.0)));
            }
            previous_displacement_vector = length * previous_tangential_force_vector / previous_tangential_force;
        }

        // 旋转校正
        const double3 n = contact.get_normal_unit_vector();
        const double3 no = contact.get_previous_normal_vector();
        const double3 v = cross(no,n);
        previous_displacement_vector += cross(v,previous_displacement_vector);
    }

    // 当前切向位移
    const double3 tangential_velocity_vector = output_data.get_tangential_relative_velocity();
    const double normal_force = output_data.get_normal_force();
    const double timestep = contact.get_timestep();

    const double3 displacement_vector = previous_displacement_vector - tangential_velocity_vector * timestep;
    const double displacement = get_norm(displacement_vector);

    // 切向弹性摩擦力和粘性耗散力
    // （仅弹性摩擦力被存储用于下一次迭代）
    if(displacement > SMALL_VALUE)
    {
        double3 dissipative_tangential_force = {0,0,0};
        double tangential_force = mu * normal_force;
        const double normalized_displacement = 1.0 - displacement / maximum_displacement;

        if(normalized_displacement > SMALL_VALUE)
        {
            const double sqrt_normalized_displacement = sqrt(normalized_displacement);
            tangential_force *= 1.0 - normalized_displacement * sqrt_normalized_displacement;
            const double m_star = contact.get_equivalent_mass();
            const double damping_ratio = get_damping_ratio(contact.get_restitution_coefficient());
            const double damping_coefficient = damping_ratio * sqrt(6.0 * sqrt_normalized_displacement * mu * m_star * normal_force / maximum_displacement);
            dissipative_tangential_force = -damping_coefficient * tangential_velocity_vector;
        }
        else
        {
            const double tangential_velocity = get_norm(tangential_velocity_vector);
            int m_index = contact.get_material_interaction_index();
            is_sliding = tangential_velocity >= (data->material_interactions[m_index].sliding_velocity_threshold);
            output_data.set_sliding(is_sliding);
            if(is_sliding)
            {
                set_contact_scalar_value<double>(contact,data->ppi_sliding_distance,data->pti_sliding_distance,tangential_velocity * timestep);
            }
        }
        double3 elastic_tangential_force = tangential_force * displacement_vector / displacement;
        set_contact_scalar_value<double3>(contact,data->ppi_tangential,data->pti_tangential,elastic_tangential_force);
        double3 new_tangential_force = elastic_tangential_force + dissipative_tangential_force;
        set_contact_scalar_value<double3>(contact,data->ppi_dis_tangential,data->pti_dis_tangential,dissipative_tangential_force);
        output_data.set_tangential_force(new_tangential_force);
    }
}
ROCKY_PLUGIN_TANGENTIAL_FORCE_ON_CONTACTS_END()

// 自定义粘结力计算(JKR)
ROCKY_PLUGIN_COMPUTE_CONTACT_ADHESIVE_FORCES(contact,output_data,module_data)
{
    auto data = static_cast<ModuleData*>(module_data);

    // double S_r = data->S_r;
    double adhesion_force = 0;
    // 获取衰减弹性模量以及等效半径,
    const double overlap = contact.get_overlap();
    // 法向力存在计算粘结力，不存在等于0
    if(get_contact_scalar_value<double>(contact,data->ppi_normal,data->pti_normal) > SMALL_VALUE)
    {
        const double E_star = contact.get_reduced_young_modulus();
        const double R_star = contact.get_equivalent_radius();
        auto m_index = contact.get_material_interaction_index();
        const double Gamma = data->material_interactions[m_index].surface_energy;

        const double factor = M_PI * Gamma / E_star;
        const double pull_off_distance = 0.75 * cbrt(factor * factor * R_star);

        if (overlap > -pull_off_distance)
        {
            const double contact_radius = solve_jkr_contact_radius(E_star, R_star, overlap, Gamma);
            const double a3 = contact_radius * contact_radius * contact_radius;
            adhesion_force = sqrt(8 * M_PI * Gamma * E_star * a3);
            if(overlap <= 0)
            {
                adhesion_force -= 4.0 / 3.0 * E_star * a3 / R_star;
            }
        }
        else
        {
            set_contact_scalar_value<double>(contact,data->ppi_normal,data->pti_normal,0);
        }
    }
    output_data.set_normal_force(-adhesion_force);
}
ROCKY_PLUGIN_COMPUTE_CONTACT_ADHESIVE_FORCES_END()

// 释放执行期间为gpu自定义数据分配的内存
ROCKY_PLUGIN_TEAR_DOWN_CUDA(model,device_id,device_data)
{
    auto d_data = static_cast<ModuleData*>(device_data);

    ModuleData data_ptr;
    CUDA_COPY_D2H(&data_ptr,d_data,1);
    CUDA_FREE(data_ptr.material_interactions);
    CUDA_FREE(d_data);
}

// 释放主机内存
ROCKY_PLUGIN_TEAR_DOWN(model,module_data)
{
    auto data = static_cast<ModuleData*>(module_data);
    delete[] data->material_interactions;
    delete data;
}

ROCKY_PLUGIN_END