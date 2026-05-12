
/*
Enables you to use a parametric version of the Gidaspow, Bezburuah & Ding 
Drag Law for computing the drag coefficient for the drag force between particles 
and fluids when CFD Coupling 2-Way with Ansys Fluent is enabled. 
*/

#define ROCKY_CUDA_API
#include <rocky20/api/rocky_api_cfd.h>

struct Data
{
    /*
    This parameter defines the fluid volume fraction power coefficient of the parametric
    Gidaspow, Bezburuah & Ding Drag Law for solid volume fractions less than 20%. [Positive values.]
    */
    double param_power_coeff;  
    /*
    This parameter defines the viscous energy losses coefficient of the parametric
    Gidaspow, Bezburuah & Ding Drag Law for solid volume fractions greater than 20%. [Positive values.]
    */
    double param_viscous_coeff; 
    /*
    This parameter defines the kinetic energy losses coefficient of the parametric
    Gidaspow, Bezburuah & Ding Drag Law for solid volume fractions greater than 20%. [Positive values.]
    */
    double param_kinetic_coeff;
};

ROCKY_PLUGIN("Parametric Gidaspow, Bezburuah & Ding", "1.0.0")

ROCKY_PLUGIN_CONFIGURE(input_data, data)
{
    Data* plugin_data = new Data();

    plugin_data->param_power_coeff = input_data.get_model().get_double("param_power_coeff");
    plugin_data->param_viscous_coeff = input_data.get_model().get_double("param_viscous_coeff");
    plugin_data->param_kinetic_coeff = input_data.get_model().get_double("param_kinetic_coeff");

    data = static_cast<void*>(plugin_data);
}

ROCKY_PLUGIN_INITIALIZE_CUDA(model, host_data, device_id, device_data)
{
    auto module_data = static_cast<Data*>(host_data);

    Data* data_for_device = nullptr;
    CUDA_MALLOC_TYPE(data_for_device, 1, Data);
    CUDA_COPY_H2D(data_for_device, module_data, 1);
    device_data = static_cast<void*>(data_for_device);
}

ROCKY_PLUGIN_TEAR_DOWN(model, data)
{
    delete static_cast<Data*>(data);
}

ROCKY_PLUGIN_TEAR_DOWN_CUDA(model, device_id, device_data)
{
    auto d_data = static_cast<Data*>(device_data);
    CUDA_FREE(d_data);
}

ROCKY_PLUGIN_CFD_COUPLING()

// Function for Drag Coefficient (Cd) Calculation:
inline ROCKY_FUNCTIONS double parametric_gidaspow(double Re, double alpha_f, double phi, double param_power_coeff, double param_viscous_coeff, double param_kinetic_coeff)
{
    double Cd;

    if (alpha_f > 0.8)
    {
        if (Re*alpha_f < 1000)
        {
            Cd = 24 / alpha_f / Re * ( 1 + 0.15 * pow(alpha_f*Re,0.687) ) * pow(alpha_f,-param_power_coeff);
        }
        else
        {
            Cd =  0.44 * pow(alpha_f, -param_power_coeff);
        }
    }
    else
    {
        Cd = param_viscous_coeff * (1-alpha_f) / (alpha_f*phi*phi*Re) + param_kinetic_coeff / phi;
    }

    return Cd;
}


ROCKY_PLUGIN_CFD_COUPLING_DRAG_COEFFICIENT(particle, cfd, data)
{
    auto plugin_data = static_cast<Data*>(data);

    const double reynolds = cfd.get_reynolds_number();          // Reynolds number
    const double fluid_fraction = 1-cfd.get_solid_fraction();   // fluid volume fraction
    const double sphericity = particle.get_sphericity();        // particle sphericity

    return parametric_gidaspow(reynolds, fluid_fraction, sphericity, plugin_data->param_power_coeff, plugin_data->param_viscous_coeff, plugin_data->param_kinetic_coeff);
        
}
ROCKY_PLUGIN_CFD_COUPLING_DRAG_COEFFICIENT_END()

ROCKY_PLUGIN_CFD_COUPLING_END()

ROCKY_PLUGIN_END