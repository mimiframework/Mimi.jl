connector_comp_name(i::Int) = Symbol("ConnectorComp$i")

# Return the datatype to use for instance variables/parameters
function _instance_datatype(md::ModelDef, def::AbstractDatumDef)
    dtype = def.datatype == Number ? number_type(md) : def.datatype
    dims = dim_names(def)
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
function _instantiate_datum(md::ModelDef, def::AbstractDatumDef)
    dtype = _instance_datatype(md, def)
    dims = dim_names(def)
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
    comp_name = nameof(comp_def)
    var_defs = variables(comp_def)    

    names  = ([nameof(vdef) for vdef in var_defs]...,)
    types  = Tuple{[_instance_datatype(md, vdef) for vdef in var_defs]...}
    values = [_instantiate_datum(md, def) for def in var_defs]

    return ComponentInstanceVariables(names, types, values)
end

# Create ComponentInstanceVariables for a composite component from the list of exported vars
@method function _combine_exported_vars(comp_def::CompositeComponentDef, var_dict::Dict{Symbol, Any})
    names = []
    values = []

    for (dr, name) in comp_def.exports
        if is_variable(dr)
            obj = var_dict[dr.comp_id.comp_name]  # TBD: should var_dict hash on ComponentId instead?
            value = getproperty(obj, nameof(dr))
            push!(names, name)
            push!(values, value)
        end
    end

    types = map(typeof, values)
    return ComponentInstanceVariables(Tuple(names), Tuple{types...}, Tuple(values))
end

@method function _combine_exported_pars(comp_def::CompositeComponentDef, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    names = []
    values = []

    for (dr, name) in comp_def.exports
        if is_parameter(dr)
            d = par_dict[dr.comp_id.comp_name]  # TBD: should par_dict hash on ComponentId instead?
            value = d[nameof(dr)]
            push!(names, name)
            push!(values, value)
        end
    end

    types = map(typeof, values)
    return ComponentInstanceParameters(Tuple(names), Tuple{types...}, Tuple(values))
end

function _instantiate_vars(comp_def::ComponentDef, md::ModelDef, var_dict::Dict{Symbol, Any}, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    comp_name = nameof(comp_def)
    par_dict[comp_name] = Dict()

    var_dict[comp_name] = v = _instantiate_component_vars(md, comp_def)
    @info "_instantiate_vars leaf $comp_name: $v"
end

# Creates the top-level vars for the model
function _instantiate_vars(md::ModelDef, var_dict::Dict{Symbol, Any}, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    _instantiate_vars(md, md, var_dict, par_dict)
end


# Recursively instantiate all variables and store refs in the given dict.
@method function _instantiate_vars(comp_def::CompositeComponentDef, md::ModelDef, var_dict::Dict{Symbol, Any}, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    comp_name = nameof(comp_def)
    par_dict[comp_name] = Dict()

    @info "_instantiate_vars composite $comp_name"
    for cd in compdefs(comp_def)
        _instantiate_vars(cd, md, var_dict, par_dict)
    end
    var_dict[comp_name] = v = _combine_exported_vars(comp_def, var_dict)            
    @info "composite vars for $comp_name: $v "
end

# Do nothing if called on a leaf component
_collect_params(comp_def::ComponentDef, var_dict, par_dict) = nothing

# Recursively collect all parameters with connections to allocated storage for variables
@method function _collect_params(comp_def::CompositeComponentDef, var_dict::Dict{Symbol, Any}, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    # depth-first search of composites
    for cd in compdefs(comp_def)
        _collect_params(cd, var_dict, par_dict)
    end        

    @info "Collecting params for $(comp_def.comp_id)"

    # Iterate over connections to create parameters, referencing storage in vars   
    for ipc in internal_param_conns(comp_def)
        src_vars = var_dict[ipc.src_comp_name]
        var_value_obj = get_property_obj(src_vars, ipc.src_var_name)
        comp_pars = par_dict[ipc.dst_comp_name]
        comp_pars[ipc.dst_par_name] = var_value_obj
        @info "internal conn: $(ipc.src_comp_name).$(ipc.src_var_name) => $(ipc.dst_comp_name).$(ipc.dst_par_name)"
    end

    for ext in external_param_conns(comp_def)
        param = external_param(comp_def, ext.external_param)
        comp_pars = par_dict[ext.comp_name]
        comp_pars[ext.param_name] = param isa ScalarModelParameter ? param : value(param)
        @info "external conn: $(ext.comp_name).$(ext.param_name) => $(param)"
    end

    # Make the external parameter connections for the hidden ConnectorComps.
    # Connect each :input2 to its associated backup value.
    for (i, backup) in enumerate(comp_def.backups)
        conn_comp_name = connector_comp_name(i)
        param = external_param(comp_def, backup)
        comp_pars = par_dict[conn_comp_name]
        comp_pars[:input2] = param isa ScalarModelParameter ? param : value(param)
        @info "backup: $conn_comp_name $param"
    end
end

function _instantiate_params(comp_def::ComponentDef, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    @info "Instantiating params for $(comp_def.comp_id)"

    comp_name = nameof(comp_def)
    d = par_dict[comp_name]

    pnames = Tuple(parameter_names(comp_def))
    pvals = [d[pname] for pname in pnames]
    ptypes = Tuple{map(typeof, pvals)...}

    return ComponentInstanceParameters(pnames, ptypes, pvals)
end

@method function _instantiate_params(comp_def::CompositeComponentDef, par_dict::Dict{Symbol, Dict{Symbol, Any}})
    _combine_exported_pars(comp_def, par_dict)
end

# Return a built leaf or composite ComponentInstance
function _build(comp_def::ComponentDef, 
                var_dict::Dict{Symbol, Any},
                par_dict::Dict{Symbol, Dict{Symbol, Any}},
                dims::DimValueDict) # FIX pass just (first, last) tuple?
    @info "_build leaf $(comp_def.comp_id)"
    @info "  var_dict $(var_dict)"
    @info "  par_dict $(par_dict)"

    comp_name = nameof(comp_def)
    pars = _instantiate_params(comp_def, par_dict)
    vars = var_dict[comp_name]

    return ComponentInstance(comp_def, vars, pars, dims, comp_name)
end

@method function _build(comp_def::CompositeComponentDef, 
                        var_dict::Dict{Symbol, Any}, 
                        par_dict::Dict{Symbol, Dict{Symbol, Any}},
                        dims::DimValueDict) # FIX pass just (first, last) tuple?
    @info "_build composite $(comp_def.comp_id)"
    @info "  var_dict $(var_dict)"
    @info "  par_dict $(par_dict)"
    
    comps = [_build(cd, var_dict, par_dict, dims) for cd in compdefs(comp_def)]
    comp_name = nameof(comp_def)å
    
    return CompositeComponentInstance(comps, comp_def, dims, comp_name)
end

function _build(md::ModelDef)
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

    _instantiate_vars(md, var_dict, par_dict)
    _collect_params(md, var_dict, par_dict)

    @info "var_dict: $var_dict"
    @info "par_dict: $par_dict"

    dim_val_dict = DimValueDict(dim_dict(md))

    ci = _build(md, var_dict, par_dict, dim_val_dict)
    mi = ModelInstance(ci, md)

    return mi
end

function build(m::Model)
    # Reference a copy in the ModelInstance to avoid changes underfoot
    m.mi = _build(deepcopy(m.md))
    return nothing
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
    if ! is_built(base)
        build(base)
    end

    # Create a marginal model, which shares the internal ModelDef between base and marginal
    mm = MarginalModel(base, delta)
end

function Base.run(mm::MarginalModel, ntimesteps::Int=typemax(Int))
    run(mm.base, ntimesteps=ntimesteps)
    run(mm.marginal, ntimesteps=ntimesteps)
end
