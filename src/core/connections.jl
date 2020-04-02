using LightGraphs
using MetaGraphs

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)
    # If the path isn't set yet, we look for a comp in the eventual location
    path = @or(comp_def.comp_path, ComponentPath(obj, comp_def.name))

    # @info "disconnect_param!($(obj.comp_path), $path, :$param_name)"

    if is_descendant(obj, comp_def) === nothing
        error("Cannot disconnect a component ($path) that is not within the given composite ($(obj.comp_path))")
    end

    filter!(x -> !(x.dst_comp_path == path && x.dst_par_name == param_name), obj.internal_param_conns)

    if obj isa ModelDef
        filter!(x -> !(x.comp_path == path && x.param_name == param_name), obj.external_param_conns)
    end
    dirty!(obj)
end

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)
    comp = compdef(obj, comp_name)
    comp === nothing && error("Did not find $comp_name in composite $(printable(obj.comp_path))")
    disconnect_param!(obj, comp, param_name)
end

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in the component identified by
`comp_path` which must be under the composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol)
    if (comp_def = find_comp(obj, comp_path)) === nothing
        return
    end
    disconnect_param!(obj, comp_def, param_name)
end

# Default string, string unit check function
verify_units(unit1::AbstractString, unit2::AbstractString) = (unit1 == unit2)

function _check_labels(obj::AbstractCompositeComponentDef,
                       comp_def::AbstractComponentDef, param_name::Symbol, ext_param::ArrayModelParameter)
    param_def = parameter(comp_def, param_name)

    t1 = eltype(ext_param.values)
    t2 = eltype(param_def.datatype)
    if !(t1 <: Union{Missing, t2})
        error("Mismatched datatype of parameter connection: Component: $(comp_def.comp_id) ($t1), Parameter: $param_name ($t2)")
    end

    comp_dims  = dim_names(param_def)
    param_dims = dim_names(ext_param)

    if ! isempty(param_dims) && size(param_dims) != size(comp_dims)
        d1 = size(comp_dims)
        d2 = size(param_dims)
        error("Mismatched dimensions of parameter connection: Component: $(comp_def.comp_id) ($d1), Parameter: $param_name ($d2)")
    end

    # Don't check sizes for ConnectorComps since they won't match.
    if nameof(comp_def) in (:ConnectorCompVector, :ConnectorCompMatrix)
        return nothing
    end

    # index_values = indexvalues(obj)

    for (i, dim) in enumerate(comp_dims)
        if isa(dim, Symbol)
            param_length = size(ext_param.values)[i]
            if dim == :time
                t = dimension(obj, :time)
                first = find_first_period(comp_def)
                last = find_last_period(comp_def)
                comp_length = t[last] - t[first] + 1
            else
                comp_length = dim_count(obj, dim)
            end
            if param_length != comp_length
                error("Mismatched data size for a parameter connection: dimension :$dim in $(comp_def.comp_id) has $comp_length elements; external parameter :$param_name has $param_length elements.")
            end
        end
    end
end

"""
    connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol;
                   check_labels::Bool=true)

Connect a parameter `param_name` in the component `comp_name` of composite `obj` to
the external parameter `ext_param_name`.
"""
function connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol,
                        param_name::Symbol, ext_param_name::Symbol;
                        check_labels::Bool=true)
    comp_def = compdef(obj, comp_name)
    connect_param!(obj, comp_def, param_name, ext_param_name, check_labels=check_labels)
end

function connect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                        param_name::Symbol, ext_param_name::Symbol; check_labels::Bool=true)
    ext_param = external_param(obj, ext_param_name)

    if ext_param isa ArrayModelParameter && check_labels
        _check_labels(obj, comp_def, param_name, ext_param)
    end

    disconnect_param!(obj, comp_def, param_name)    # calls dirty!()

    comp_path = @or(comp_def.comp_path, ComponentPath(obj.comp_path, comp_def.name))
    conn = ExternalParameterConnection(comp_path, param_name, ext_param_name)
    add_external_param_conn!(obj, conn)

    return nothing
end

"""
    connect_param!(obj::AbstractCompositeComponentDef,
        dst_comp_path::ComponentPath, dst_par_name::Symbol,
        src_comp_path::ComponentPath, src_var_name::Symbol,
        backup::Union{Nothing, Array}=nothing;
        ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst_par_name` of one component `dst_comp_path` of composite `obj` to a
variable `src_var_name` in another component `src_comp_path` of the same model using
`backup` to provide default values and the `ignoreunits` flag to indicate the need to
check match units between the two.  The `offset` argument indicates the offset between
the destination and the source ie. the value would be `1` if the destination component
parameter should only be calculated for the second timestep and beyond.
"""
function connect_param!(obj::AbstractCompositeComponentDef,
                        dst_comp_path::ComponentPath, dst_par_name::Symbol,
                        src_comp_path::ComponentPath, src_var_name::Symbol,
                        backup::Union{Nothing, Array}=nothing;
                        ignoreunits::Bool=false, offset::Int=0)

    # remove any existing connections for this dst parameter
    disconnect_param!(obj, dst_comp_path, dst_par_name)  # calls dirty!()

    dst_comp_def = compdef(obj, dst_comp_path)
    src_comp_def = compdef(obj, src_comp_path)

    # @info "dst_comp_def: $dst_comp_def"
    # @info "src_comp_def: $src_comp_def"

    if backup !== nothing
        # If value is a NamedArray, we can check if the labels match
        if isa(backup, NamedArray)
            dims = dimnames(backup)
            check_parameter_dimensions(obj, backup, dims, dst_par_name)
        else
            dims = nothing
        end

        # Check that the backup data is the right size
        if size(backup) != datum_size(obj, dst_comp_def, dst_par_name)
            error("Cannot connect parameter; the provided backup data is the wrong size. ",
                  "Expected size $(datum_size(obj, dst_comp_def, dst_par_name)) but got $(size(backup)).")
        end

        # some other check for second dimension??
        dst_param = parameter(dst_comp_def, dst_par_name)
        dst_dims  = dim_names(dst_param)

        # convert number type and, if it's a NamedArray, convert to Array
        backup = convert(Array{Union{Missing, number_type(obj)}}, backup)
        first = first_period(obj, dst_comp_def)

        T = eltype(backup)

        dim_count = length(dst_dims)

        if dim_count == 0
            values = backup
        else
            ti = get_time_index_position(dst_param)

            if isuniform(obj)
                # use the first from the comp_def not the ModelDef
                stepsize = step_size(obj)
                last = last_period(obj, dst_comp_def)
                values = TimestepArray{FixedTimestep{first, stepsize, last}, T, dim_count, ti}(backup)
            else
                times = time_labels(obj)
                # use the first from the comp_def
                first_index = findfirst(isequal(first), times)
                values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, dim_count, ti}(backup)
            end

        end

        set_external_array_param!(obj, dst_par_name, values, dst_dims)
        backup_param_name = dst_par_name

    else
        # If backup not provided, make sure the source component covers the span of the destination component
        src_first, src_last = first_and_last(src_comp_def)
        dst_first, dst_last = first_and_last(dst_comp_def)
        if (dst_first !== nothing && src_first !== nothing && dst_first < src_first) ||
            (dst_last  !== nothing && src_last  !== nothing && dst_last  > src_last)
            src_first = printable(src_first)
            src_last  = printable(src_last)
            dst_first = printable(dst_first)
            dst_last  = printable(dst_last)
            error("""Cannot connect parameter: $src_comp_path runs only from $src_first to $src_last,
whereas $dst_comp_path runs from $dst_first to $dst_last. Backup data must be provided for missing years.
Try calling:
    `connect_param!(m, comp_name, par_name, comp_name, var_name, backup_data)`""")
        end

        backup_param_name = nothing
    end

    # Check the units, if provided
    if ! ignoreunits && ! verify_units(variable_unit(src_comp_def, src_var_name),
                                       parameter_unit(dst_comp_def, dst_par_name))
        error("Units of $src_comp_path:$src_var_name do not match $dst_comp_path:$dst_par_name.")
    end

    conn = InternalParameterConnection(src_comp_path, src_var_name, dst_comp_path, dst_par_name,
                                       ignoreunits, backup_param_name, offset=offset)
    add_internal_param_conn!(obj, conn)

    return nothing
end

function connect_param!(obj::AbstractCompositeComponentDef,
                        dst_comp_name::Symbol, dst_par_name::Symbol,
                        src_comp_name::Symbol, src_var_name::Symbol,
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_param!(obj, ComponentPath(obj, dst_comp_name), dst_par_name,
                        ComponentPath(obj, src_comp_name), src_var_name,
                        backup; ignoreunits=ignoreunits, offset=offset)
end

"""
    connect_param!(obj::AbstractCompositeComponentDef,
        dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol},
        backup::Union{Nothing, Array}=nothing;
        ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst[2]` of one component `dst[1]` of composite `obj`
to a variable `src[2]` in another component `src[1]` of the same composite
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination
component parameter should only be calculated for the second timestep and beyond.
"""
function connect_param!(obj::AbstractCompositeComponentDef,
                        dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol},
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_param!(obj, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

"""
    split_datum_path(obj::AbstractCompositeComponentDef, s::AbstractString)

Split a string of the form "/path/to/component:datum_name" into the component path,
`ComponentPath(:path, :to, :component)` and name `:datum_name`.
"""
function split_datum_path(obj::AbstractCompositeComponentDef, s::AbstractString)
    elts = split(s, ":")
    length(elts) != 2 && error("Can't split datum path '$s' into ComponentPath and datum name")
    return (ComponentPath(obj, elts[1]), Symbol(elts[2]))
end

# TBD: Deprecated?
"""
Connect a parameter and variable using string notation "/path/to/component:datum_name" where
the potion before the ":" is the string representation of a component path from `obj` and the
portion after is the name of the src or dst datum.
"""
function connect_param!(obj::AbstractCompositeComponentDef, dst::AbstractString, src::AbstractString,
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    dst_path, dst_name = split_datum_path(obj, dst)
    src_path, src_name = split_datum_path(obj, src)

    connect_param!(obj, dst_path, dst_name, src_path, src_name,
                   backup; ignoreunits=ignoreunits, offset=offset)
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
    comp !== nothing || error("Can't find $(top_dst_path) from $(md.comp_id)")
    par_sub_paths, param_names = _find_paths_and_names(comp, conn.dst_par_name)
    param_paths = [ComponentPath(top_dst_path, sub_path) for sub_path in par_sub_paths]

    top_src_path = conn.src_comp_path
    comp = find_comp(md, top_src_path)
    comp !== nothing || error("Can't find $(top_src_path) from $(md.comp_id)")
    var_sub_path, var_name = _find_paths_and_names(comp, conn.src_var_name)
    var_path = ComponentPath(top_src_path, var_sub_path[1])

    ipcs = [InternalParameterConnection(var_path, var_name[1], param_path, param_name, 
        conn.ignoreunits, conn.backup; offset=conn.offset) for (param_path, param_name) in
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
    comp !== nothing || error("Can't find $(epc.comp_path) from $(md.comp_id)")
    par_sub_paths, param_names = _find_paths_and_names(comp, epc.param_name)

    leaf_epcs = ExternalParameterConnection[]
    external_param_name = epc.external_param

    top_path = epc.comp_path

    for (par_sub_path, param_name) in zip(par_sub_paths, param_names)
        param_path = ComponentPath(top_path, par_sub_path)
        epc = ExternalParameterConnection(param_path, param_name, external_param_name)
        push!(leaf_epcs, epc)
    end

    return leaf_epcs
end

"""
    connection_refs(obj::AbstractCompositeComponentDef)

Return a vector of UnnamedReference's to parameters from subcomponents that are either found in
internal connections or that have been already imported in a parameter definition.
"""
function connection_refs(obj::AbstractCompositeComponentDef)
    refs = UnnamedReference[]

    for conn in obj.internal_param_conns
        push!(refs, UnnamedReference(conn.dst_comp_path.names[end], conn.dst_par_name))
    end

    for item in values(obj.namespace)
        if item isa CompositeParameterDef
            for ref in item.refs
                push!(refs, ref)
            end
        end
    end

    return refs
end

"""
    connection_refs(obj::ModelDef)

Return a vector of UnnamedReference's to parameters from subcomponents that are either found in
internal connections or that have been already connected to external parameter values.
"""
function connection_refs(obj::ModelDef)
    refs = UnnamedReference[]

    for conn in obj.internal_param_conns
        push!(refs, UnnamedReference(conn.dst_comp_path.names[end], conn.dst_par_name))
    end

    for conn in obj.external_param_conns
        push!(refs, UnnamedReference(conn.comp_path.names[end], conn.param_name))
    end

    return refs
end

"""
    unconnected_params(obj::AbstractCompositeComponentDef)

Return a list of UnnamedReference's to parameters that have not been connected
to a value.
"""
function unconnected_params(obj::AbstractCompositeComponentDef)
    return setdiff(subcomp_params(obj), connection_refs(obj))
end

"""
    set_leftover_params!(m::Model, parameters::Dict)

Set all of the parameters in model `m` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are strings that match the names of unset parameters in the model.
"""
function set_leftover_params!(md::ModelDef, parameters::Dict{T, Any}) where T
    for param_ref in unconnected_params(md)
        param_name = param_ref.datum_name
        comp_name = param_ref.comp_name
        comp_def = find_comp(md, comp_name)
        param_def = comp_def[param_name]


        # @info "set_leftover_params: comp_name=$comp_name, param=$param_name"
        # check whether we need to set the external parameter
        _skip = false
        if external_param(md, param_name, missing_ok=true) === nothing
            if haskey(parameters, string(param_name))  
                value = parameters[string(param_name)]
                param_dims = parameter_dimensions(md, comp_name, param_name)

                set_external_param!(md, param_name, value; param_dims = param_dims)
            elseif param_def.default != nothing
                _skip = true
            else
                error("Cannot set parameter :$param_name, not found in provided dictionary and no default value deteceted.")
            end
        end
        _skip || connect_param!(md, comp_name, param_name, param_name)
    end
    nothing
end

# Find internal param conns to a given destination component
function internal_param_conns(obj::AbstractCompositeComponentDef, dst_comp_path::ComponentPath)
    return filter(x->x.dst_comp_path == dst_comp_path, internal_param_conns(obj))
end

function internal_param_conns(obj::AbstractCompositeComponentDef, comp_name::Symbol)
    return internal_param_conns(obj, ComponentPath(obj.comp_path, comp_name))
end

function add_internal_param_conn!(obj::AbstractCompositeComponentDef, conn::InternalParameterConnection)
    push!(obj.internal_param_conns, conn)
    dirty!(obj)
end

#
# These should all take ModelDef instead of AbstractCompositeComponentDef as 1st argument
#

# Find external param conns for a given comp
function external_param_conns(obj::ModelDef, comp_path::ComponentPath)
    return filter(x -> x.comp_path == comp_path, external_param_conns(obj))
end

function external_param_conns(obj::ModelDef, comp_name::Symbol)
    return external_param_conns(obj, ComponentPath(obj.comp_path, comp_name))
end

function external_param(obj::ModelDef, name::Symbol; missing_ok=false)
    haskey(obj.external_params, name) && return obj.external_params[name]

    missing_ok && return nothing

    error("$name not found in external parameter list")
end

function add_external_param_conn!(obj::ModelDef, conn::ExternalParameterConnection)
    push!(obj.external_param_conns, conn)
    dirty!(obj)
end

function set_external_param!(obj::ModelDef, name::Symbol, value::ModelParameter)
    # if haskey(obj.external_params, name)
    #     @warn "Redefining external param :$name in $(obj.comp_path) from $(obj.external_params[name]) to $value"
    # end
    obj.external_params[name] = value
    dirty!(obj)
    return value
end

function set_external_param!(obj::ModelDef, name::Symbol, value::Number;
                             param_dims::Union{Nothing,Array{Symbol}} = nothing)
    set_external_scalar_param!(obj, name, value)
end

function set_external_param!(obj::ModelDef, name::Symbol,
                             value::Union{AbstractArray, AbstractRange, Tuple};
                             param_dims::Union{Nothing,Array{Symbol}} = nothing)
    ti = get_time_index_position(param_dims)
    if ti != nothing
        value = convert(Array{number_type(obj)}, value)
        num_dims = length(param_dims)
        values = get_timestep_array(obj, eltype(value), num_dims, ti, value)
    else
        values = value
    end

    set_external_array_param!(obj, name, values, param_dims)
end

"""
    set_external_array_param!(obj::ModelDef,
                              name::Symbol, value::TimestepVector, dims)

Add a one dimensional time-indexed array parameter indicated by `name` and
`value` to the composite `obj`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(obj::ModelDef,
                                   name::Symbol, value::TimestepVector, dims)
    param = ArrayModelParameter(value, [:time])  # must be :time
    set_external_param!(obj, name, param)
end

"""
    set_external_array_param!(obj::ModelDef,
                              name::Symbol, value::TimestepMatrix, dims)

Add a multi-dimensional time-indexed array parameter `name` with value
`value` to the composite `obj`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(obj::ModelDef,
                                   name::Symbol, value::TimestepArray, dims)
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(obj, name, param)
end

"""
    set_external_array_param!(obj::ModelDef,
                              name::Symbol, value::AbstractArray, dims)

Add an array type parameter `name` with value `value` and `dims` dimensions to the composite `obj`.
"""
function set_external_array_param!(obj::ModelDef,
                                   name::Symbol, value::AbstractArray, dims)
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(obj, name, param)
end

"""
    set_external_scalar_param!(obj::ModelDef, name::Symbol, value::Any)

Add a scalar type parameter `name` with the value `value` to the composite `obj`.
"""
function set_external_scalar_param!(obj::ModelDef, name::Symbol, value::Any)
    param = ScalarModelParameter(value)
    set_external_param!(obj, name, param)
end

"""
    update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value; update_timesteps = false)

Update the `value` of an external model parameter in composite `obj`, referenced
by `name`. Optional boolean argument `update_timesteps` with default value
`false` indicates whether to update the time keys associated with the parameter
values to match the model's time index.
"""
function update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value; update_timesteps = false)
    _update_param!(obj::AbstractCompositeComponentDef, name, value, update_timesteps; raise_error = true)
end

function _update_param!(obj::AbstractCompositeComponentDef,
                        name::Symbol, value, update_timesteps; raise_error = true)
    param = external_param(obj, name, missing_ok=true)
    if param === nothing
        error("Cannot update parameter; $name not found in composite's external parameters.")
    end

    if param isa ScalarModelParameter
        if update_timesteps && raise_error
            error("Cannot update timesteps; parameter $name is a scalar parameter.")
        end
        _update_scalar_param!(param, name, value)
    else
        _update_array_param!(obj, name, value, update_timesteps, raise_error)
    end

    dirty!(obj)
end

function _update_scalar_param!(param::ScalarModelParameter, name, value)
    if ! (value isa typeof(param.value))
        try
            value = convert(typeof(param.value), value)
        catch e
            error("Cannot update parameter $name; expected type $(typeof(param.value)) but got $(typeof(value)).")
        end
    end
    param.value = value
    nothing
end

function _update_array_param!(obj::AbstractCompositeComponentDef, name, value, update_timesteps, raise_error)
    # Get original parameter
    param = external_param(obj, name)

    # Check type of provided parameter
    if !(typeof(value) <: AbstractArray)
        error("Cannot update array parameter $name with a value of type $(typeof(value)).")

    elseif !(eltype(value) <: eltype(param.values))
        try
            value = convert(Array{eltype(param.values)}, value)
        catch e
            error("Cannot update parameter $name; expected array of type $(eltype(param.values)) but got $(eltype(value)).")
        end
    end

    # Check size of provided parameter
    if update_timesteps && param.values isa TimestepArray
        expected_size = ([length(dim_keys(obj, d)) for d in dim_names(param)]...,)
    else
        expected_size = size(param.values)
    end
    if size(value) != expected_size
        error("Cannot update parameter $name; expected array of size $expected_size but got array of size $(size(value)).")
    end

    if update_timesteps
        if param.values isa TimestepArray
            T = eltype(value)
            N = length(size(value))
            ti = get_time_index_position(param)
            new_timestep_array = get_timestep_array(obj, T, N, ti, value)
            set_external_param!(obj, name, ArrayModelParameter(new_timestep_array, dim_names(param)))

        elseif raise_error
            error("Cannot update timesteps; parameter $name is not a TimestepArray.")
        else
            param.values = value
        end
    else
        if param.values isa TimestepArray
            param.values.data = value
        else
            param.values = value
        end
    end
    dirty!(obj)
    nothing
end

"""
    update_params!(obj::AbstractCompositeComponentDef, parameters::Dict{T, Any};
                   update_timesteps = false) where T

For each (k, v) in the provided `parameters` dictionary, `update_param!`
is called to update the external parameter by name k to value v, with optional
Boolean argument update_timesteps. Each key k must be a symbol or convert to a
symbol matching the name of an external parameter that already exists in the
component definition.
"""
function update_params!(obj::AbstractCompositeComponentDef, parameters::Dict; update_timesteps = false)
    parameters = Dict(Symbol(k) => v for (k, v) in parameters)
    for (param_name, value) in parameters
        _update_param!(obj, param_name, value, update_timesteps; raise_error = false)
    end
    nothing
end

function add_connector_comps!(obj::AbstractCompositeComponentDef)
    conns = internal_param_conns(obj)
    i = 1 # counter to track the number of connector comps added

    for comp_def in compdefs(obj)
        comp_name = nameof(comp_def)
        comp_path = comp_def.comp_path

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_path == comp_path, conns)
        need_conn_comps = filter(x -> x.backup !== nothing, internal_conns)

        # isempty(need_conn_comps) || @info "Need connectors comps: $need_conn_comps"

        for conn in need_conn_comps
            add_backup!(obj, conn.backup)

            num_dims = length(size(external_param(obj, conn.backup).values))

            if ! (num_dims in (1, 2))
                error("Connector components for parameters with > 2 dimensions are not implemented.")
            end

            # Fetch the definition of the appropriate connector commponent
            conn_comp_def = (num_dims == 1 ? Mimi.ConnectorCompVector : Mimi.ConnectorCompMatrix)
            conn_comp_name = connector_comp_name(i) # generate a new name
            i += 1 # increment connector comp counter

            # Add the connector component before the user-defined component that required it
            conn_comp = add_comp!(obj, conn_comp_def, conn_comp_name, before=comp_name)
            conn_path = conn_comp.comp_path

            # add a connection between src_component and the ConnectorComp
            add_internal_param_conn!(obj, InternalParameterConnection(conn.src_comp_path, conn.src_var_name,
                                                                      conn_path, :input1,
                                                                      conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            add_internal_param_conn!(obj, InternalParameterConnection(conn_path, :output,
                                                                      conn.dst_comp_path, conn.dst_par_name,
                                                                      conn.ignoreunits))

            # add a connection between ConnectorComp and the external backup data
            add_external_param_conn!(obj, ExternalParameterConnection(conn_path, :input2, conn.backup))

            # TBD: first/last stuff may be deprecated
            src_comp_def = compdef(obj, conn.src_comp_path)
            set_param!(obj, conn_comp_name, :first, first_period(obj, src_comp_def))
            set_param!(obj, conn_comp_name, :last, last_period(obj, src_comp_def))
        end
    end

    # Save the sorted component order for processing
    # obj.sorted_comps = _topological_sort(obj)

    return nothing
end
