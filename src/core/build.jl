"""
    _substitute_views!(vals::Array{T, N}, comp_def) where {T, N}

For each value in `vals`, if the value is a `TimestepArray` swap in a new 
TimestepArray with the same type parameterization but with its `data` field 
holding a view of the original value's `data` defined by the first and last
indices of Component `comp_def`.
"""
# helper function to substitute views for data 
function _substitute_views!(vals::Array{T, N}, comp_def) where {T, N}
    times = [keys(comp_def.dim_dict[:time])...]
    first_idx = findfirst(times .== comp_def.first)
    last_idx = findfirst(times .== comp_def.last)
    for (i, val) in enumerate(vals)
        if val isa TimestepArray
            vals[i] = _get_view(val, first_idx, last_idx)
        end
    end
end

"""
    _get_view(val::TimestepArray{T_TS, T, N, ti, S}, first_idx, last_idx) where {T_TS, T, N, ti, S}

Return a TimestepArray with the same type parameterization as the `val` TimestepArray,
but with its `data` field holding a view of the `val.data` based on the entered
`first-idx` and `last_idx`. 
"""
function _get_view(val::TimestepArray{T_TS, T, N, ti, S}, first_idx, last_idx) where {T_TS, T, N, ti, S}
    
    idxs  = Array{Any}(fill(:, N))
    idxs[ti] = first_idx:last_idx
    # if we are making a connection, the val.data may already be a view, in which case
    # we need to return to the parent of that view before taking our new view
    return TimestepArray{T_TS, T, N, ti}(val.data isa SubArray ? view(val.data.parent, idxs...) : view(val.data, idxs...))
end

"""
    _instance_datatype(md::ModelDef, def::AbstractDatumDef)

Return the datatype of the AbstractDataumDef `def` in ModelDef `md`, which will
be used to create ModelInstance instance variables and parameters.    
"""
function _instance_datatype(md::ModelDef, def::AbstractDatumDef)
    dtype = def.datatype == Number ? number_type(md) : def.datatype
    dims = dim_names(def)
    num_dims = dim_count(def)

    ti = get_time_index_position(def)

    if num_dims == 0
        T = ScalarModelParameter{dtype}

    elseif ti === nothing     # there's no time dimension
        T = Array{dtype, num_dims}

    else
        if isuniform(md)
            first, stepsize = first_and_step(md)
            last = last_period(md)
            first === nothing && @warn "_instance_datatype: first === nothing"
            T = TimestepArray{FixedTimestep{first, stepsize, last}, Union{dtype, Missing}, num_dims, ti}
        else
            times = time_labels(md)
            T = TimestepArray{VariableTimestep{(times...,)}, Union{dtype, Missing}, num_dims, ti}
        end
    end

    # @info "_instance_datatype returning $T"
    return T
end

"""
    _instantiate_datum(md::ModelDef, def::AbstractDatumDef)

Return the parameterized datum, broadly either Scalar or Array, pertaining to 
AbstractDatumDef `def` in the Model Def `md`, that will support instantiate of parameters 
and variables.
"""
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
    var_defs = variables(comp_def)

    names  = Symbol[nameof(def) for def in var_defs]
    values = Any[_instantiate_datum(md, def) for def in var_defs]
    _substitute_views!(values, comp_def)

    # this line was replaced with the one below because calling _instance_datatype
    # does not concretely type the S type parameter (the type of the TimestepArray's
    # and thus DataType[typeof(val) for val in values] errored when trying to 
    # convert typeof(val<:TimestepArray) to a DataType

    # types  = DataType[_instance_datatype(md, def) for def in var_defs]
    types = DataType[typeof(val) for val in values]
    paths  = repeat(Any[comp_def.comp_path], length(names))

    return ComponentInstanceVariables(names, types, values, paths)
end

"""
    function _instantiate_vars(md::ModelDef)

Create the top-level variables for the Model Def `md` and return the dictionary 
of the resulting ComponentInstanceVariables.
"""
function _instantiate_vars(md::ModelDef)
    vdict = Dict{ComponentPath, Any}()
    recurse(md, cd -> vdict[cd.comp_path] = _instantiate_component_vars(md, cd); leaf_only=true)
    return vdict
end

"""
    _find_paths_and_names(obj::AbstractComponentDef, datum_name::Symbol)

Recurses through sub components and finds the full path(s) to desired datum, and their
names at the leaf level. Returns a tuple (paths::Vector{ComponentPath}, datum_names::Vector{Symbol})
"""
function _find_paths_and_names(obj::AbstractComponentDef, datum_name::Symbol)

    # Base case-- leaf component
    if obj isa ComponentDef
        return ([nothing], [datum_name])
    end

    datumdef = obj[datum_name]
    if datumdef isa CompositeVariableDef
        refs = [datumdef.ref]   # CompositeVariableDef's can only point to one subcomponent
    else
        refs = datumdef.refs    # ComposteParameterDef's can have multiple refs
    end

    paths = []
    datum_names = []

    for ref in refs
        # Get the comp and datum's for the current ref
        next_obj = obj[ref.comp_name]
        next_datum_name = ref.datum_name

        # Recurse
        sub_paths, sub_datum_names = _find_paths_and_names(next_obj, next_datum_name)

        # Append the paths, and save with datum_names
        for (sp, dn) in zip(sub_paths, sub_datum_names)
            push!(paths, ComponentPath(next_obj.name, sp))
            push!(datum_names, dn)
        end
    end

    return (paths, datum_names)
end

"""
    _get_leaf_level_ipcs(md::ModelDef, conn::InternalParameterConnection)

Returns a vector of InternalParameterConnections that represent all of the connections at the leaf level 
that need to be made under the hood as specified by `conn`.
"""
function _get_leaf_level_ipcs(md::ModelDef, conn::InternalParameterConnection)

    top_dst_path = conn.dst_comp_path
    comp = find_comp(md, top_dst_path)
    comp !== nothing || error("Cannot find $(top_dst_path) from $(md.comp_id)")
    par_sub_paths, param_names = _find_paths_and_names(comp, conn.dst_par_name)
    param_paths = [ComponentPath(top_dst_path, sub_path) for sub_path in par_sub_paths]

    top_src_path = conn.src_comp_path
    comp = find_comp(md, top_src_path)
    comp !== nothing || error("Cannot find $(top_src_path) from $(md.comp_id)")
    var_sub_path, var_name = _find_paths_and_names(comp, conn.src_var_name)
    var_path = ComponentPath(top_src_path, var_sub_path[1])

    ipcs = [InternalParameterConnection(var_path, var_name[1], param_path, param_name, 
        conn.ignoreunits, conn.backup; backup_offset=conn.backup_offset) for (param_path, param_name) in
        zip(param_paths, param_names)]
    return ipcs
end


"""
    _get_leaf_level_epcs(md::AbstractCompositeComponentDef, epc::ExternalParameterConnection)

Returns a vector that has a new ExternalParameterConnections that represent all of the connections at the leaf level 
that need to be made under the hood as specified by `epc`.
"""
function _get_leaf_level_epcs(md::ModelDef, epc::ExternalParameterConnection)

    comp = find_comp(md, epc.comp_path)
    comp !== nothing || error("Cannot find $(epc.comp_path) from $(md.comp_id)")
    par_sub_paths, param_names = _find_paths_and_names(comp, epc.param_name)

    leaf_epcs = ExternalParameterConnection[]
    model_param_name = epc.model_param_name

    top_path = epc.comp_path

    for (par_sub_path, param_name) in zip(par_sub_paths, param_names)
        param_path = ComponentPath(top_path, par_sub_path)
        epc = ExternalParameterConnection(param_path, param_name, model_param_name)
        push!(leaf_epcs, epc)
    end

    return leaf_epcs
end

# generic helper function to get connector component name
connector_comp_name(i::Int) = Symbol("ConnectorComp$i")

"""
    _collect_params(md::ModelDef, var_dict::Dict{ComponentPath, Any})

Collect all parameters in ModelDef `md` with connections to allocated variable 
storage in `var_dict` and return a dictionary of (comp_path, par_name) => ModelParameter 
elements.
"""
function _collect_params(md::ModelDef, var_dict::Dict{ComponentPath, Any})

    # @info "Collecting params for $(comp_def.comp_id)"

    # Iterate over connections to create parameters, referencing storage in vars
    conns = []
    recurse(md, cd -> append!(conns, internal_param_conns(cd)); composite_only=true)

    pdict = Dict{Tuple{ComponentPath, Symbol}, Any}()

    for conn in conns
        ipcs = _get_leaf_level_ipcs(md, conn)
        src_vars = var_dict[ipcs[1].src_comp_path]
        var_value_obj = get_property_obj(src_vars, ipcs[1].src_var_name)
        for ipc in ipcs 
            _check_attributes(md, ipc)
            pdict[(ipc.dst_comp_path, ipc.dst_par_name)] = var_value_obj
        end
    end

    for epc in external_param_conns(md)
        param = model_param(md, epc.model_param_name)
        leaf_level_epcs = _get_leaf_level_epcs(md, epc)
        for leaf_epc in leaf_level_epcs
            pdict[(leaf_epc.comp_path, leaf_epc.param_name)] = (param isa ScalarModelParameter ? param : value(param))
        end
    end

    # Make the external parameter connections for the hidden ConnectorComps.
    # Connect each :input2 to its associated backup value.
    backups = []
    recurse(md, cd -> append!(backups, cd.backups); composite_only=true)

    for (i, backup) in enumerate(backups)
        conn_comp = compdef(md, connector_comp_name(i))
        conn_path = conn_comp.comp_path

        param = model_param(md, backup)
        pdict[(conn_path, :input2)] = (param isa ScalarModelParameter ? param : value(param))
    end

    return pdict
end

"""
    _instantiate_params(comp_def::ComponentDef, par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})

Create the top-level parameters for the Model Def `md` using the parameter dictionary
`par_dict` and return the resulting ComponentInstanceParameters.
"""
function _instantiate_params(comp_def::ComponentDef, par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})
    # @info "Instantiating params for $(comp_def.comp_path)"
    comp_path = comp_def.comp_path
    names = parameter_names(comp_def)   
    vals  = Any[par_dict[(comp_path, name)] for name in names]
    _substitute_views!(vals, comp_def)
    types = DataType[typeof(val) for val in vals]
    paths = repeat([comp_def.comp_path], length(names))

    return ComponentInstanceParameters(names, types, vals, paths)
end

"""
    _build(comp_def::ComponentDef,
                    var_dict::Dict{ComponentPath, Any},
                    par_dict::Dict{Tuple{ComponentPath, Symbol}, Any},
                    time_bounds::Tuple{Int, Int})

Return a built leaf or composite LeafComponentInstance created using ComponentDef
`comp_def`, variables and parameters from `var_dict` and `par_dict` and the time 
bounds set by `time_bounds`.
"""
function _build(comp_def::ComponentDef,
                var_dict::Dict{ComponentPath, Any},
                par_dict::Dict{Tuple{ComponentPath, Symbol}, Any},
                time_bounds::Tuple{Int, Int})
    # @info "_build leaf $(comp_def.comp_id)"
    # @info "  var_dict $(var_dict)"
    # @info "  par_dict $(par_dict)"

    pars = _instantiate_params(comp_def, par_dict)
    vars = var_dict[comp_def.comp_path]

    return LeafComponentInstance(comp_def, vars, pars, time_bounds)
end

"""
    _build(comp_def::AbstractCompositeComponentDef,
                    var_dict::Dict{ComponentPath, Any},
                    par_dict::Dict{Tuple{ComponentPath, Symbol}, Any},
                    time_bounds::Tuple{Int, Int})

Return a built CompositeComponentInstance created using AbstractCompositeComponentDef
`comp_def`, variables and parameters from `var_dict` and `par_dict` and the time 
bounds set by `time_bounds`.
"""
function _build(comp_def::AbstractCompositeComponentDef,
                var_dict::Dict{ComponentPath, Any},
                par_dict::Dict{Tuple{ComponentPath, Symbol}, Any},
                time_bounds::Tuple{Int, Int})
    # @info "_build composite $(comp_def.comp_id)"
    # @info "  var_dict $(var_dict)"
    # @info "  par_dict $(par_dict)"

    comps = [_build(cd, var_dict, par_dict, time_bounds) for cd in compdefs(comp_def)]

    variables = _get_variables(comp_def)
    parameters = _get_parameters(comp_def)

    return CompositeComponentInstance(comps, comp_def, time_bounds, variables, parameters)
end

"""
    _get_variables(comp_def::AbstractCompositeComponentDef)

Return a vector of NamedTuples for all variables in the CompositeComponentInstance
`comp_def`.
"""
# helper functions for to create the variables and parameters NamedTuples for a 
# CompositeComponentInstance
function _get_variables(comp_def::AbstractCompositeComponentDef)

    namespace = comp_def.namespace
    var_defs = filter(namespace -> isa(namespace.second, CompositeVariableDef), namespace)
    names = [k for (k,v) in var_defs]
    vals = [v.ref for (k,v) in var_defs]
    variables = (; zip(names, vals)...)
    
    return variables
end

"""
    _get_parameters(comp_def::AbstractCompositeComponentDef)

Return a vector of NamedTuples for all parameters in the CompositeComponentInstance
`comp_def`.
"""
function _get_parameters(comp_def::AbstractCompositeComponentDef)

    namespace = comp_def.namespace
    par_defs = filter(namespace -> isa(namespace.second, CompositeParameterDef), namespace)
    names = [k for (k,v) in par_defs]
    vals = [v.refs[1] for (k,v) in par_defs]
    parameters = (; zip(names, vals)...)

    return parameters
end

"""
    _build(md::ModelDef)

Build ModelDef `md` (lowest build function called by `build(md::ModelDef)`) and return the ModelInstance..
"""
function _build(md::ModelDef)

    # @info "_build(md)"
    add_connector_comps!(md)

    # check if any of the parameters initialized with the value(s) of nothing 
    # are  still nothing
    nothingparams = nothing_params(md)
    if ! isempty(nothingparams)
        params = join([string(p.datum_name, " (in Component ", p.comp_name, ")") for p in nothingparams], "\n  ")
        error("Cannot build model; the following parameters still have values of `nothing` and need to be updated:\n  $params")
    end

    vdict = _instantiate_vars(md)
    pdict = _collect_params(md, vdict)

    # @info "vdict: $vdict"
    # @info "pdict: $pdict"

    t = dimension(md, :time)
    time_bounds = (firstindex(t), lastindex(t))

    _propagate_time_dim!(md, t) # this might not be needed, but is a final propagation to double check everything
    
    ci = _build(md, vdict, pdict, time_bounds)
    mi = ModelInstance(ci, md)
    return mi
end

"""
    build(m::Model)

Build Model `m` and return the ModelInstance.
"""
function build(m::Model)    
    # Reference a copy in the ModelInstance to avoid changes underfoot
    md = deepcopy(m.md)
    mi = _build(md)
    return mi
end

"""
    build!(m::Model)

Build Model `m` for and dirty `m`'s ModelDef.
"""
function build!(m::Model)
    m.mi = build(m)
    m.md.dirty = false
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
        build!(base)
    end

    # Create a marginal model, which shares the internal ModelDef between base and marginal
    mm = MarginalModel(base, delta)
end

"""
    Base.run(mm::MarginalModel; ntimesteps::Int=typemax(Int))

Run the marginal model `mm` once with `ntimesteps`.
"""
function Base.run(mm::MarginalModel; ntimesteps::Int=typemax(Int))
    run(mm.base, ntimesteps=ntimesteps)
    run(mm.modified, ntimesteps=ntimesteps)
end

"""
    build!(mm::MarginalModel)

Build MarginalModel `mm` by building both its `base` and `modified models`.
"""
function build!(mm::MarginalModel)
    build!(mm.base)
    build!(mm.modified)
end
