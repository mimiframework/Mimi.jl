connector_comp_name(i::Int) = Symbol("ConnectorComp$i")

# Return the datatype to use for instance variables/parameters
function _instance_datatype(md::ModelDef, def::DatumDef)    
    dtype = def.datatype == Number ? number_type(md) : def.datatype
    dims = dimensions(def)
    num_dims = dim_count(def)

    if num_dims == 0
        T = ScalarModelParameter{dtype}

    elseif dims[1] != :time
        T = Array{dtype, num_dims}
    
    else   
        if isuniform(md)
            first, stepsize = first_and_step(md)
            T = TimestepArray{FixedTimestep{first, stepsize}, Union{dtype, Missing}, num_dims}
        else
            times = time_labels(md)
            T = TimestepArray{VariableTimestep{(times...,)}, Union{dtype, Missing}, num_dims}
        end
    end

    # @info "_instance_datatype returning $T"
    return T
end

# Create the Ref or Array that will hold the value(s) for a Parameter or Variable
function _instantiate_datum(md::ModelDef, def::DatumDef)
    dtype = _instance_datatype(md, def)
    dims = dimensions(def)
    num_dims = length(dims)
    
    # Scalar datum
    if num_dims == 0
        value = dtype(0)
      
    # Array datum, with :time dimension
    elseif dims[1] == :time 

        if num_dims == 1
            value = dtype(dim_count(md, :time))
        else 
            counts = dim_counts(md, Vector{Symbol}(dims))
            value = dtype <: AbstractArray ? dtype(undef, counts...) : dtype(counts...)
        end

    # Array datum, without :time dimension
    else 
        # TBD: Handle unnamed indices properly
        counts = dim_counts(md, Vector{Symbol}(dims))
        value = dtype <: AbstractArray ? dtype(undef, counts...) : dtype(counts...)
    end

    return value
end

"""
    _instantiate_component_vars(md::ModelDef, comp_def::ComponentDef)

Instantiate a component `comp_def` in the model `md` and its variables (but not its 
parameters). Return the resulting ComponentInstanceVariables.
"""
function _instantiate_component_vars(md::ModelDef, comp_def::ComponentDef)
    comp_name = name(comp_def)
    var_defs = variables(comp_def)    

    names  = ([name(vdef) for vdef in var_defs]...,)
    types  = Tuple{[_instance_datatype(md, vdef) for vdef in var_defs]...}
    values = [_instantiate_datum(md, def) for def in var_defs]

    return ComponentInstanceVariables(names, types, values)
end

function _combine_exported_vars(md::ModelDef, comp_def::CompositeComponentDef, var_dict::Dict{Symbol, Any})
    # exports is Vector{Pair{DatumReference, Symbol}}
    names = []
    values = []

    for (dr, name) in comp_def.subcomps.exports
        if has_variable(comp_def, name)
            civ = var_dict[dr.comp_id.comp_name]  # TBD: should var_dict hash on ComponentId instead?
            value = getproperty(civ, dr.datum_name)
            push!(names, name)
            push!(values, value)
        end
    end

    types = map(typeof, values)
    @info "names: $names"
    @info "types: $types"
    @info "values: $values"

    return ComponentInstanceVariables(Tuple(names), Tuple{types...}, Tuple(values))
end

# 

# Recursively instantiate all variables and store refs in the given dict.
function _instantiate_vars(md::ModelDef, comp_def::ComponentDef, var_dict::Dict{Symbol, Any})
    comp_name = name(comp_def)

    if is_composite(comp_def)
        for cd in compdefs(comp_def)
            _instantiate_vars(md, cd, var_dict)
        end

        # Create aggregate comp-inst-vars without allocating new storage
        # var_dict[comp_name] = 

    else
        var_dict[comp_name] = _instantiate_component_vars(md, comp_def)
    end
end

# Save a reference to the model's dimension dictionary to make it 
# available in calls to run_timestep.
function save_dim_dict_reference(mi::ModelInstance)
    dim_dict = dim_value_dict(mi.md)

    for ci in values(mi.components)
        ci.dim_dict = dim_dict
    end

    return nothing
end

# Return a built leaf or composite ComponentInstance
function build(md::ModelDef, comp_def::ComponentDef, var_dict::Dict{Symbol, Any}, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    @info "build $(comp_def.comp_id)"
    comp_name = name(comp_def)

    par_dict[comp_name] = par_values = Dict()  # param value keyed by param name

    subcomps = nothing

    # recursive build...
    if is_composite(comp_def)
        comps = [build(md, cd, var_dict, par_dict) for cd in compdefs(comp_def.subcomps)]
        subcomps = SubcompsInstance(comps)

        # Iterate over connections to create parameters, referencing storage in vars   
        for ipc in internal_param_conns(comp_def)
            src_comp_name = ipc.src_comp_name      

            vars = var_dict[src_comp_name]
            var_value_obj = get_property_obj(vars, ipc.src_var_name)
            
            _par_values = par_dict[ipc.dst_comp_name]
            _par_values[ipc.dst_par_name] = var_value_obj
        end

        for ext in external_param_conns(comp_def)
            param = external_param(comp_def, ext.external_param)
            _par_values = par_dict[ext.comp_name]
            _par_values[ext.param_name] = param isa ScalarModelParameter ? param : value(param)
        end
    
        # Make the external parameter connections for the hidden ConnectorComps.
        # Connect each :input2 to its associated backup value.
        for (i, backup) in enumerate(backups(md))
            conn_comp_name = connector_comp_name(i)
            param = external_param(comp_def, backup)
    
            _par_values = par_dict[conn_comp_name]
            _par_values[:input2] = param isa ScalarModelParameter ? param : value(param)
        end
    end

    # Do the rest for both leaf and composite components
    pnames = Tuple(parameter_names(comp_def))
    pvals  = [par_values[pname] for pname in pnames]
    ptypes = Tuple{map(typeof, pvals)...}
    pars = ComponentInstanceParameters(pnames, ptypes, pvals)

    # first = first_period(md, comp_def)
    # last = last_period(md, comp_def)
    # ci = ComponentInstance{typeof(vars), typeof(pars)}(comp_def, vars, pars, first, last, comp_name)
    ci = ComponentInstance{typeof(subcomps), typeof(vars), typeof(pars)}(comp_def, vars, pars, comp_name, 
                                                                         subcomps=subcomps)
    return ci
end

function build(m::Model)
    # Reference a copy in the ModelInstance to avoid changes underfoot
    m.mi = build(deepcopy(m.md))
    return nothing
end

function build(md::ModelDef)
    add_connector_comps(md)
    
    # check if all parameters are set
    not_set = unconnected_params(md)
    if ! isempty(not_set)
        params = join(not_set, " ")
        msg = "Cannot build model; the following parameters are not set: $params"
        error(msg)
    end

    var_dict = Dict{Symbol, Any}()                 # collect all var defs and
    par_dict = Dict{Symbol, Dict{Symbol, Any}}()   # store par values as we go

    _instantiate_vars(md, md.ccd, var_dict)

    ci = build(md, md.ccd, var_dict, par_dict)
    mi = ModelInstance(md, ci)
    save_dim_dict_reference(mi)
    return mi
end

"""
    create_marginal_model(base::Model, delta::Float64=1.0)

Create a `MarginalModel` where `base` is the baseline model and `delta` is the 
difference used to create the `marginal` model.  Return the resulting `MarginaModel`
which shares the internal `ModelDef` between the `base` and `marginal`.
"""
function create_marginal_model(base::Model, delta::Float64=1.0)
    # Make sure the base has a ModelInstance before we copy since this
    # copies the ModelDef to avoid being affected by later changes.
    if base.mi === nothing
        build(base)
    end

    # Create a marginal model, which shares the internal ModelDef between base and marginal
    mm = MarginalModel(base, delta)
end

function Base.run(mm::MarginalModel, ntimesteps::Int=typemax(Int))
    run(mm.base, ntimesteps=ntimesteps)
    run(mm.marginal, ntimesteps=ntimesteps)
end
