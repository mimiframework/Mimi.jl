connector_comp_name(i::Int) = Symbol("ConnectorComp$i")

# Return the datatype to use for instance variables/parameters
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
            first === nothing && @warn "_instance_datatype: first === nothing"
            T = TimestepArray{FixedTimestep{first, stepsize}, Union{dtype, Missing}, num_dims, ti}
        else
            times = time_labels(md)
            T = TimestepArray{VariableTimestep{(times...,)}, Union{dtype, Missing}, num_dims, ti}
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
    var_defs = variables(comp_def)

    names  = Symbol[nameof(def) for def in var_defs]
    values = Any[_instantiate_datum(md, def) for def in var_defs]
    types  = DataType[_instance_datatype(md, def) for def in var_defs]
    paths  = repeat(Any[comp_def.comp_path], length(names))

    return ComponentInstanceVariables(names, types, values, paths)
end

# Create ComponentInstanceVariables for a composite component from the list of exported vars
function _combine_exported_vars(comp_def::AbstractCompositeComponentDef, var_dict::Dict{ComponentPath, Any})
    names  = Symbol[]
    values = Any[]

    types = DataType[typeof(val) for val in values]
    paths = repeat(Any[comp_def.comp_path], length(names))
    ci_vars = ComponentInstanceVariables(names, types, values, paths)
    # @info "ci_vars: $ci_vars"]
    return ci_vars
end

function _combine_exported_pars(comp_def::AbstractCompositeComponentDef, par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})
    names  = Symbol[]
    values = Any[]
    paths = repeat(Any[comp_def.comp_path], length(names))
    types = DataType[typeof(val) for val in values]
    return ComponentInstanceParameters(names, types, values, paths)
end

function _instantiate_vars(comp_def::ComponentDef, md::ModelDef, var_dict::Dict{ComponentPath, Any})
    var_dict[comp_def.comp_path] = _instantiate_component_vars(md, comp_def)
end

# Creates the top-level vars for the model
function _instantiate_vars(md::ModelDef, var_dict::Dict{ComponentPath, Any})
    _instantiate_vars(md, md, var_dict)
end


# Recursively instantiate all variables and store refs in the given dict.
function _instantiate_vars(comp_def::AbstractCompositeComponentDef, md::ModelDef, var_dict::Dict{ComponentPath, Any})
    comp_path = comp_def.comp_path
    # @info "_instantiate_vars composite $comp_path"

    for cd in compdefs(comp_def)
        _instantiate_vars(cd, md, var_dict)
    end
    var_dict[comp_path] = _combine_exported_vars(comp_def, var_dict)
end

# Do nothing if called on a leaf component
_collect_params(comp_def::ComponentDef, var_dict, par_dict) = nothing

# Recursively collect all parameters with connections to allocated storage for variables
function _collect_params(comp_def::AbstractCompositeComponentDef,
                         var_dict::Dict{ComponentPath, Any},
                         par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})

    # TBD: with reformulation of parameter importing, we shouldn't need to recurse.
    # depth-first search of composites
    for cd in compdefs(comp_def)
        _collect_params(cd, var_dict, par_dict)
    end

    # @info "Collecting params for $(comp_def.comp_id)"

    # Iterate over connections to create parameters, referencing storage in vars
    for ipc in internal_param_conns(comp_def)
        src_vars = var_dict[ipc.src_comp_path]
        var_value_obj = get_property_obj(src_vars, ipc.src_var_name)
        par_dict[(ipc.dst_comp_path, ipc.dst_par_name)] = var_value_obj
        # @info "internal conn: $(ipc.src_comp_path):$(ipc.src_var_name) => $(ipc.dst_comp_path):$(ipc.dst_par_name)"
    end

    for ext in external_param_conns(comp_def)
        param = external_param(comp_def, ext.external_param)
        par_dict[(ext.comp_path, ext.param_name)] = (param isa ScalarModelParameter ? param : value(param))
        # @info "external conn: $(ext.comp_name).$(ext.param_name) => $(param)"
    end

    # Make the external parameter connections for the hidden ConnectorComps.
    # Connect each :input2 to its associated backup value.
    for (i, backup) in enumerate(comp_def.backups)
        conn_comp = compdef(comp_def, connector_comp_name(i))
        conn_path = conn_comp.comp_path

        param = external_param(comp_def, backup)
        par_dict[(conn_path, :input2)] = (param isa ScalarModelParameter ? param : value(param))
    end
end

function _instantiate_params(comp_def::ComponentDef, par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})
    # @info "Instantiating params for $(comp_def.comp_path)"
    comp_path = comp_def.comp_path
    names = parameter_names(comp_def)
    vals  = Any[par_dict[(comp_path, name)] for name in names]
    types = DataType[typeof(val) for val in vals]
    paths = repeat([comp_def.comp_path], length(names))

    return ComponentInstanceParameters(names, types, vals, paths)
end

function _instantiate_params(comp_def::AbstractCompositeComponentDef, par_dict::Dict{Tuple{ComponentPath, Symbol}, Any})
    _combine_exported_pars(comp_def, par_dict)
end

# Return a built leaf or composite LeafComponentInstance
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

function _build(comp_def::AbstractCompositeComponentDef,
                var_dict::Dict{ComponentPath, Any},
                par_dict::Dict{Tuple{ComponentPath, Symbol}, Any},
                time_bounds::Tuple{Int, Int})
    # @info "_build composite $(comp_def.comp_id)"
    # @info "  var_dict $(var_dict)"
    # @info "  par_dict $(par_dict)"

    comps = [_build(cd, var_dict, par_dict, time_bounds) for cd in compdefs(comp_def)]
    return CompositeComponentInstance(comps, comp_def, time_bounds)
end

function _build(md::ModelDef)
    # import any unconnected params into ModelDef
    import_params!(md)

    # @info "_build(md)"
    add_connector_comps!(md)

    # check if all parameters are set
    not_set = unconnected_params(md)

    if ! isempty(not_set)
        params = join(not_set, "\n  ")
        error("Cannot build model; the following parameters are not set:\n  $params")
    end

    var_dict = Dict{ComponentPath, Any}()                 # collect all var defs and
    par_dict = Dict{Tuple{ComponentPath, Symbol}, Any}()  # store par values as we go

    _instantiate_vars(md, var_dict)
    _collect_params(md, var_dict, par_dict)

    # @info "var_dict: $var_dict"
    # @info "par_dict: $par_dict"

    t = dimension(md, :time)
    time_bounds = (firstindex(t), lastindex(t))

    propagate_time!(md, t)

    ci = _build(md, var_dict, par_dict, time_bounds)
    mi = ModelInstance(ci, md)
    return mi
end

function build(m::Model)
    # fix paths and propagate imports
    fix_comp_paths!(m.md)

    # Reference a copy in the ModelInstance to avoid changes underfoot
    md = deepcopy(m.md)
    m.mi = _build(md)
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
        build(base)
    end

    # Create a marginal model, which shares the internal ModelDef between base and marginal
    mm = MarginalModel(base, delta)
end

function Base.run(mm::MarginalModel; ntimesteps::Int=typemax(Int))
    run(mm.base, ntimesteps=ntimesteps)
    run(mm.marginal, ntimesteps=ntimesteps)
end

function build(mm::MarginalModel)
    build(mm.base)
    build(mm.marginal)
end
