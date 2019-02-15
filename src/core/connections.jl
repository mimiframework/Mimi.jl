using LightGraphs
using MetaGraphs

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)
    if is_descendant(obj, comp_def) === nothing
        error("Cannot disconnect a component ($comp_def.comp_path) that is not within the given composite ($(obj.comp_path))")
    end

    path = comp_def.comp_path    
    filter!(x -> !(x.dst_comp_path == path && x.dst_par_name == param_name), internal_param_conns(obj))
    filter!(x -> !(x.comp_path == path && x.param_name == param_name), external_param_conns(obj))
    dirty!(obj)
end

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)
    disconnect_param!(obj, compdef(obj, comp_name), param_name)
end

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in the component identified by
`comp_path` which must be under the composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol)
    if (comp_def = find_comp(obj, comp_path, relative=false)) === nothing
        return
    end
    disconnect_param!(obj, comp_def, param_name)
end

# Default string, string unit check function
verify_units(unit1::AbstractString, unit2::AbstractString) = (unit1 == unit2)

function _check_labels(obj::AbstractCompositeComponentDef, 
                       comp_def::ComponentDef, param_name::Symbol, ext_param::ArrayModelParameter)
    param_def = parameter(comp_def, param_name)

    t1 = eltype(ext_param.values)
    t2 = eltype(param_def.datatype)
    if !(t1 <: t2)
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
                first = first_period(obj, comp_def)
                last = last_period(obj, comp_def)
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
    connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)

Connect a parameter `param_name` in the component `comp_name` of composite `obj` to
the external parameter `ext_param_name`. 
"""
function connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)
    comp_def = compdef(obj, comp_name)
    comp_path = comp_def.comp_path
    ext_param = external_param(obj, ext_param_name)

    if ext_param isa ArrayModelParameter
        _check_labels(obj, comp_def, param_name, ext_param)
    end

    disconnect_param!(obj, comp_name, param_name)    # calls dirty!()

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
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

    # remove any existing connections for this dst parameter
    disconnect_param!(obj, dst_comp_path, dst_par_name)  # calls dirty!()

    dst_comp_def = compdef(obj, dst_comp_path)
    src_comp_def = compdef(obj, src_comp_path)

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
            error("Cannot connect parameter; the provided backup data is the wrong size. Expected size $(datum_size(obj, dst_comp_def, dst_par_name)) but got $(size(backup)).")
        end

        # some other check for second dimension??
        dst_param = parameter(dst_comp_def, dst_par_name)
        dst_dims  = dim_names(dst_param)

        backup = convert(Array{Union{Missing, number_type(obj)}}, backup) # converts number type and, if it's a NamedArray, it's converted to Array
        first = first_period(obj, dst_comp_def)
        T = eltype(backup)        
        
        dim_count = length(dst_dims)

        if dim_count == 0
            values = backup
        else
            
            if isuniform(obj)
                # use the first from the comp_def not the ModelDef
                stepsize = step_size(obj)
                values = TimestepArray{FixedTimestep{first, stepsize}, T, dim_count}(backup)
            else
                times = time_labels(obj)
                # use the first from the comp_def 
                first_index = findfirst(isequal(first), times) 
                values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, dim_count}(backup)
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

    # @info "connect($src_comp_path:$src_var_name => $dst_comp_path:$dst_par_name)"
    conn = InternalParameterConnection(src_comp_path, src_var_name, dst_comp_path, dst_par_name, ignoreunits, backup_param_name, offset=offset)
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
    connected_params(obj::AbstractCompositeComponentDef, comp_name::Symbol)

Return list of parameters that have been set for component `comp_name` in composite `obj`.
"""
function connected_params(obj::AbstractCompositeComponentDef, comp_name::Symbol)
    ext_set_params = map(x->x.param_name,   external_param_conns(obj, comp_name))
    int_set_params = map(x->x.dst_par_name, internal_param_conns(obj, comp_name))

    return union(ext_set_params, int_set_params)
end

"""
    unconnected_params(obj::AbstractCompositeComponentDef)

Return a list of tuples (comp_path, parame_name) of parameters
that have not been connected to a value in the composite `obj`.
"""
function unconnected_params(obj::AbstractCompositeComponentDef)
    unconnected = Vector{Tuple{ComponentPath,Symbol}}()
    
    for comp_def in compdefs(obj)
        comp_path = comp_def.comp_path
        params = parameter_names(comp_def)
        connected = connected_params(obj, nameof(comp_def))
        append!(unconnected, map(x->(comp_path, x), setdiff(params, connected)))
    end

    return unconnected
end

"""
    set_leftover_params!(m::Model, parameters::Dict)

Set all of the parameters in model `m` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are strings that match the names of unset parameters in the model.
"""
function set_leftover_params!(md::ModelDef, parameters::Dict{T, Any}) where T
    parameters = Dict(k => v for (k, v) in parameters)

    for (comp_path, param_name) in unconnected_params(md)
        comp_def = compdef(md, comp_path)
        comp_name = nameof(comp_def)

        # check whether we need to set the external parameter
        if external_param(md, param_name, missing_ok=true) !== nothing
            value = parameters[string(param_name)]
            param_dims = parameter_dimensions(md, comp_name, param_name)

            set_external_param!(md, param_name, value; param_dims = param_dims)

        end
        connect_param!(md, comp_name, param_name, param_name)
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

# Find external param conns for a given comp
function external_param_conns(obj::AbstractCompositeComponentDef, comp_path::ComponentPath)
    return filter(x -> x.comp_path == comp_path, external_param_conns(obj))
end

function external_param_conns(obj::AbstractCompositeComponentDef, comp_name::Symbol)
    return external_param_conns(obj, ComponentPath(obj.comp_path, comp_name))
end

function external_param(obj::AbstractCompositeComponentDef, name::Symbol; missing_ok=false)
    try
        return obj.external_params[name]
    catch err
        if err isa KeyError
            missing_ok && return nothing

            error("$name not found in external parameter list")
        else
            rethrow(err)
        end
    end
end

function add_internal_param_conn!(obj::AbstractCompositeComponentDef, conn::InternalParameterConnection)
    push!(obj.internal_param_conns, conn)
    dirty!(obj)
end

function add_external_param_conn!(obj::AbstractCompositeComponentDef, conn::ExternalParameterConnection)
    push!(obj.external_param_conns, conn)
    dirty!(obj)
end

function set_external_param!(obj::AbstractCompositeComponentDef, name::Symbol, value::ModelParameter)
    obj.external_params[name] = value
    dirty!(obj)
end

function set_external_param!(obj::AbstractCompositeComponentDef, name::Symbol, value::Number; 
                             param_dims::Union{Nothing,Array{Symbol}} = nothing)
    set_external_scalar_param!(obj, name, value)
end

function set_external_param!(obj::AbstractCompositeComponentDef, name::Symbol, 
                             value::Union{AbstractArray, AbstractRange, Tuple}; 
                             param_dims::Union{Nothing,Array{Symbol}} = nothing)
    if param_dims[1] == :time   
        value = convert(Array{number_type(obj)}, value)
        num_dims = length(param_dims)
        values = get_timestep_array(obj, eltype(value), num_dims, value)      
    else
        values = value
    end

    set_external_array_param!(obj, name, values, param_dims)
end

"""
    set_external_array_param!(obj::AbstractCompositeComponentDef, 
                              name::Symbol, value::TimestepVector, dims)

Add a one dimensional time-indexed array parameter indicated by `name` and
`value` to the composite `obj`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(obj::AbstractCompositeComponentDef, 
                                   name::Symbol, value::TimestepVector, dims)
    # println("set_external_array_param!: dims=$dims, setting dims to [:time]")
    param = ArrayModelParameter(value, [:time])  # must be :time
    set_external_param!(obj, name, param)
end

"""
    set_external_array_param!(obj::AbstractCompositeComponentDef, 
                              name::Symbol, value::TimestepMatrix, dims)

Add a multi-dimensional time-indexed array parameter `name` with value
`value` to the composite `obj`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(obj::AbstractCompositeComponentDef, 
                                   name::Symbol, value::TimestepArray, dims)
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(obj, name, param)
end

"""
    set_external_array_param!(obj::AbstractCompositeComponentDef, 
                              name::Symbol, value::AbstractArray, dims)

Add an array type parameter `name` with value `value` and `dims` dimensions to the composite `obj`.
"""
function set_external_array_param!(obj::AbstractCompositeComponentDef, 
                                   name::Symbol, value::AbstractArray, dims)
    numtype = number_type(obj)
    if !(typeof(value) <: Array{numtype})
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{numtype}(undef, value)
    end
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(obj, name, param)
end

"""
    set_external_scalar_param!(obj::AbstractCompositeComponentDef, name::Symbol, value::Any)

Add a scalar type parameter `name` with the value `value` to the composite `obj`.
"""
function set_external_scalar_param!(obj::AbstractCompositeComponentDef, name::Symbol, value::Any)
    p = ScalarModelParameter(value)
    set_external_param!(obj, name, p)
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
    param = external_param(ext_params, name, missing_ok=true)
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

    dirty!(md)
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
            new_timestep_array = get_timestep_array(obj, T, N, value)
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

function add_connector_comps(obj::AbstractCompositeComponentDef)
    conns = internal_param_conns(obj)

    for comp_def in compdefs(obj)
        comp_name = nameof(comp_def)
        comp_path = comp_def.comp_path

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_path == comp_path, conns)
        need_conn_comps = filter(x -> x.backup !== nothing, internal_conns)

        # println("Need connectors comps: $need_conn_comps")

        for (i, conn) in enumerate(need_conn_comps)
            add_backup!(obj, conn.backup)

            num_dims = length(size(external_param(obj, conn.backup).values))

            if ! (num_dims in (1, 2))
                error("Connector components for parameters with > 2 dimensions are not implemented.")
            end

            # Fetch the definition of the appropriate connector commponent
            conn_name = num_dims == 1 ? :ConnectorCompVector : :ConnectorCompMatrix
            conn_comp_def = compdef(conn_name)
            conn_comp_name = connector_comp_name(i) # generate a new name

            # Add the connector component before the user-defined component that required it
            # @info "add_connector_comps: add_comp!(obj, $(conn_comp_def.comp_id), $conn_comp_name, before=$comp_name)"
            add_comp!(obj, conn_comp_def, conn_comp_name, before=comp_name)
           
            # add a connection between src_component and the ConnectorComp
            add_internal_param_conn!(obj, InternalParameterConnection(conn.src_comp_path, conn.src_var_name,
                                                                      conn_comp_name, :input1,
                                                                      conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            add_internal_param_conn!(md, InternalParameterConnection(conn_comp_name, :output, 
                                                                     conn.dst_comp_path, conn.dst_par_name, 
                                                                     conn.ignoreunits))

            # add a connection between ConnectorComp and the external backup data
            add_external_param_conn!(md, ExternalParameterConnection(conn_comp_name, :input2, conn.backup))

            src_comp_def = compdef(md, conn.src_comp_path)
            set_param!(md, conn_comp_name, :first, first_period(md, src_comp_def))
            set_param!(md, conn_comp_name, :last, last_period(md, src_comp_def))

        end
    end

    # Save the sorted component order for processing
    # md.sorted_comps = _topological_sort(md)

    return nothing
end


#
# Support for automatic ordering of components
#

"""
    dependencies(md::ModelDef, comp_path::ComponentPath)

Return the set of component names that `comp_path` in `md` depends one, i.e.,
sources for which `comp_name` is the destination of an internal connection.
"""
function dependencies(md::ModelDef, comp_path::ComponentPath)
    conns = internal_param_conns(md)
    # For the purposes of the DAG, we don't treat dependencies on [t-1] as an ordering constraint
    deps = Set(c.src_comp_path for c in conns if (c.dst_comp_path == comp_path && c.offset == 0))
    return deps
end

"""
    comp_graph(md::ModelDef)

Return a MetaGraph containing a directed (LightGraph) graph of the components of 
ModelDef `md`. Each vertex has a :name property with its component name.
"""
function comp_graph(md::ModelDef)
    comp_paths = [c.comp_path for c in compdefs(md)]
    graph = MetaDiGraph()

    for comp_path in comp_paths
        add_vertex!(graph, :path, comp_path)
    end

    set_indexing_prop!(graph, :path)
   
    for comp_path in comp_paths
        for dep_path in dependencies(md, comp_path)
            src = graph[dep_path,  :path]
            dst = graph[comp_path, :path]
            add_edge!(graph, src, dst)
        end
    end

    #TODO:  for now we can allow cycles since we aren't using the offset
    # if is_cyclic(graph)
    #     error("Component graph contains a cycle")
    # end

    return graph
end

"""
    _topological_sort(md::ModelDef)

Build a directed acyclic graph referencing the positions of the components in 
the OrderedDict of model `md`, tracing dependencies to create the DAG.
Perform a topological sort on the graph for the given model and return a vector 
of component paths in the order that will ensure dependencies are processed 
prior to dependent components.
"""
function _topological_sort(md::ModelDef)
    graph = comp_graph(md)
    ordered = topological_sort_by_dfs(graph)
    paths = map(i -> graph[i, :path], ordered)
    return paths
end
