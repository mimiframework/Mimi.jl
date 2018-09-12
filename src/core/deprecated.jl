using Base: @deprecate

@deprecate addcomponent add_comp!
@deprecate set_parameter! set_param!

@deprecate connect_parameter(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol) connect_param!(md, comp_name, param_name, ext_param_name)

@deprecate(
    connect_parameter(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, src_var_name::Symbol, backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0),
    connect_parameter(md, dst_comp_name, dst_par_name, src_comp_name, src_var_name, backup; ignoreunits=ignoreunits, offset=offset)
)

@deprecate(
    connect_parameter(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, src_var_name::Symbol, 
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0),
    connect_param!(m, dst_comp_name, dst_par_name, src_comp_name, src_var_name, backup;  ignoreunits=ignoreunits, offset=offset)
)
