using LightGraphs
using MetaGraphs

"""
    disconnect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_name` of model `md`.
"""
function disconnect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    # println("disconnect_param!($comp_name, $param_name)")
    filter!(x -> !(x.dst_comp_name == comp_name && x.dst_par_name == param_name), internal_param_conns(md))
    filter!(x -> !(x.comp_name == comp_name && x.param_name == param_name), external_param_conns(md))
end

# Default string, string unit check function
function verify_units(one::AbstractString, two::AbstractString)
    # True if and only if they match
    return one == two
end

function _check_labels(md::ModelDef, comp_def::ComponentDef, param_name::Symbol, ext_param::ArrayModelParameter)
    param_def = parameter(comp_def, param_name)

    t1 = eltype(ext_param.values)
    t2 = eltype(datatype(param_def))
    if !(t1 <: t2)
        error("Mismatched datatype of parameter connection: Component: $(comp_def.comp_id) ($t1), Parameter: $param_name ($t2)")
    end

    comp_dims  = dimensions(param_def)
    param_dims = dimensions(ext_param)

    if ! isempty(param_dims) && size(param_dims) != size(comp_dims)
        d1 = size(comp_dims)
        d2 = size(param_dims)
        error("Mismatched dimensions of parameter connection: Component: $(comp_def.comp_id) ($d1), Parameter: $param_name ($d2)")
    end

    # Don't check sizes for ConnectorComps since they won't match.
    if name(comp_def) in (:ConnectorCompVector, :ConnectorCompMatrix)
        return nothing
    end

    # index_values = indexvalues(md)

    for (i, dim) in enumerate(comp_dims)
        if isa(dim, Symbol) 
            param_length = size(ext_param.values)[i]
            if dim == :time 
                t = dimensions(md)[:time]
                first = first_period(md, comp_def)
                last = last_period(md, comp_def)
                comp_length = t[last] - t[first] + 1
            else
                comp_length = dim_count(md, dim)
            end
            if param_length != comp_length
                error("Mismatched data size for a parameter connection: dimension :$dim in $(comp_def.comp_id) has $comp_length elements; external parameter :$param_name has $param_length elements.")
            end
        end
    end
end

"""
    connect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)

Connect a parameter `param_name` in the component `comp_name` of model `md` to
the external parameter `ext_param_name`. 
"""
function connect_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)
    comp_def = compdef(md, comp_name)
    ext_param = external_param(md, ext_param_name)

    if isa(ext_param, ArrayModelParameter)
        _check_labels(md, comp_def, param_name, ext_param)
    end

    disconnect_param!(md, comp_name, param_name)

    conn = ExternalParameterConnection(comp_name, param_name, ext_param_name)
    add_external_param_conn(md, conn)

    return nothing
end

"""
    connect_param!(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, 
        src_comp_name::Symbol, src_var_name::Symbol backup::Union{Nothing, Array}=nothing; 
        ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst_par_name` of one component `dst_comp_name` of model `md`
to a variable `src_var_name` in another component `src_comp_name` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination 
component parameter should only be calculated for the second timestep and beyond.
"""
function connect_param!(md::ModelDef, 
                           dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol,
                           backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

    # remove any existing connections for this dst parameter
    disconnect_param!(md, dst_comp_name, dst_par_name)

    if backup !== nothing
        # If value is a NamedArray, we can check if the labels match
        if isa(backup, NamedArray)
            dims = dimnames(backup)
            check_parameter_dimensions(md, backup, dims, dst_par_name)
        else
            dims = nothing
        end

        # Check that the backup value is the right size
        if size(backup)[1] != length(time_labels(md))  # TODO: should it be the length of the whole model or the lenght of the component? for now, lenght of the model
            error("Can't connect parameter: backup data size $(size(backup)) differs from model's time span $(length(time_labels(md))).")
        end

        dst_comp_def = compdef(md, dst_comp_name)
        src_comp_def = compdef(md, src_comp_name)

        # some other check for second dimension??
        dst_param = parameter(dst_comp_def, dst_par_name)
        dst_dims  = dimensions(dst_param)

        backup = convert(Array{number_type(md)}, backup) # converts number type and, if it's a NamedArray, it's converted to Array
        first = first_period(md, dst_comp_def)
        T = eltype(backup)        
        
        dim_count = length(dst_dims)

        if dim_count == 0
            values = backup
        else
            
            if isuniform(md)
                # use the first from the comp_def not the ModelDef
                _, stepsize = first_and_step(md)
                values = TimestepArray{FixedTimestep{first, stepsize}, T, dim_count}(backup)
            else
                times = time_labels(md)
                # use the first from the comp_def 
                first_index = findfirst(isequal(first), times) 
                values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, dim_count}(backup)
            end
            
        end

        set_external_array_param!(md, dst_par_name, values, dst_dims)
        backup_param_name = dst_par_name

    else 
        backup_param_name = nothing 
    end

    # Check the units, if provided
    if ! ignoreunits && ! verify_units(variable_unit(md, src_comp_name, src_var_name), 
                                       parameter_unit(md, dst_comp_name, dst_par_name))
        error("Units of $src_comp_name.$src_var_name do not match $dst_comp_name.$dst_par_name.")
    end

    # println("connect($src_comp_name.$src_var_name => $dst_comp_name.$dst_par_name)")
    conn = InternalParameterConnection(src_comp_name, src_var_name, dst_comp_name, dst_par_name, ignoreunits, backup_param_name, offset=offset)
    add_internal_param_conn(md, conn)

    return nothing
end

"""
    connect_param!(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

Bind the parameter `dst[2]` of one component `dst[1]` of model `md`
to a variable `src[2]` in another component `src[1]` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `offset` argument indicates the offset
between the destination and the source ie. the value would be `1` if the destination 
component parameter should only be calculated for the second timestep and beyond.
"""
function connect_param!(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_param!(md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

"""
    connected_params(md::ModelDef, comp_name::Symbol)

Return list of parameters that have been set for component `comp_name` in model `md`.
"""
function connected_params(md::ModelDef, comp_name::Symbol)
    ext_set_params = map(x->x.param_name,   external_param_conns(md, comp_name))
    int_set_params = map(x->x.dst_par_name, internal_param_conns(md, comp_name))

    return union(ext_set_params, int_set_params)
end

"""
    unconnected_params(md::ModelDef)

Return a list of tuples (componentname, parametername) of parameters
that have not been connected to a value in the model `md`.
"""
function unconnected_params(md::ModelDef)
    unconnected = Vector{Tuple{Symbol,Symbol}}()
    
    for comp_def in compdefs(md)
        comp_name = name(comp_def)
        params = parameter_names(comp_def)
        connected = connected_params(md, comp_name)
        append!(unconnected, map(x->(comp_name, x), setdiff(params, connected)))
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
    leftovers = unconnected_params(md)
    external_params = md.external_params

    for (comp_name, param_name) in leftovers
        # check whether we need to set the external parameter
        if ! haskey(md.external_params, param_name)
            value = parameters[string(param_name)]
            param_dims = parameter_dimensions(md, comp_name, param_name)

            set_external_param!(md, param_name, value; param_dims = param_dims)

        end
        connect_param!(md, comp_name, param_name, param_name)
    end
    nothing
end

internal_param_conns(md::ModelDef) = md.internal_param_conns

external_param_conns(md::ModelDef) = md.external_param_conns

# Find internal param conns to a given destination component
function internal_param_conns(md::ModelDef, dst_comp_name::Symbol)
    return filter(x->x.dst_comp_name == dst_comp_name, internal_param_conns(md))
end

# Find external param conns for a given comp
function external_param_conns(md::ModelDef, comp_name::Symbol)
    return filter(x -> x.comp_name == comp_name, external_param_conns(md))
end

function external_param(md::ModelDef, name::Symbol)
    try
        return md.external_params[name]
    catch err
        if err isa KeyError
            error("$name not found in external parameter list")
        else
            rethrow(err)
        end
    end
end

function add_internal_param_conn(md::ModelDef, conn::InternalParameterConnection)
    push!(md.internal_param_conns, conn)
end

function add_external_param_conn(md::ModelDef, conn::ExternalParameterConnection)
    push!(md.external_param_conns, conn)
end

function set_external_param!(md::ModelDef, name::Symbol, value::ModelParameter)
    md.external_params[name] = value
end

function set_external_param!(md::ModelDef, name::Symbol, value::Number; param_dims::Union{Nothing,Array{Symbol}} = nothing)
    set_external_scalar_param!(md, name, value)
end

function set_external_param!(md::ModelDef, name::Symbol, value::Union{AbstractArray, AbstractRange, Tuple}; 
                             param_dims::Union{Nothing,Array{Symbol}} = nothing)
    if param_dims[1] == :time   
        value = convert(Array{md.number_type}, value)
        num_dims = length(param_dims)
        values = get_timestep_array(md, eltype(value), num_dims, value)      
    else
        values = value
    end

    set_external_array_param!(md, name, values, param_dims)
end

"""
    set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepVector, dims)

Add a one dimensional time-indexed array parameter indicated by `name` and
`value` to the model `md`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepVector, dims)
    # println("set_external_array_param!: dims=$dims, setting dims to [:time]")
    param = ArrayModelParameter(value, [:time])  # must be :time
    set_external_param!(md, name, param)
end

"""
    set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepMatrix, dims)

Add a multi-dimensional time-indexed array parameter `name` with value
`value` to the model `md`.  In this case `dims` must be `[:time]`.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepArray, dims)
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(md, name, param)
end

"""
    set_external_array_param!(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter `name` with value `value` and `dims` dimensions to the model 'm'.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::AbstractArray, dims)
    numtype = md.number_type
    
    if !(typeof(value) <: Array{numtype})
        numtype = number_type(md)
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{numtype}(undef, value)
    end
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims)
    set_external_param!(md, name, param)
end

"""
    set_external_scalar_param!(md::ModelDef, name::Symbol, value::Any)

Add a scalar type parameter `name` with the value `value` to the model `md`.
"""
function set_external_scalar_param!(md::ModelDef, name::Symbol, value::Any)
    p = ScalarModelParameter(value)
    set_external_param!(md, name, p)
end

"""
    update_param!(md::ModelDef, name::Symbol, value; update_timesteps = false)

Update the `value` of an external model parameter in ModelDef `md`, referenced 
by `name`. Optional boolean argument `update_timesteps` with default value 
`false` indicates whether to update the time keys associated with the parameter 
values to match the model's time index.
"""
function update_param!(md::ModelDef, name::Symbol, value; update_timesteps = false)
    _update_param!(md::ModelDef, name::Symbol, value, update_timesteps; raise_error = true)
end

function _update_param!(md::ModelDef, name::Symbol, value, update_timesteps; raise_error = true)
    ext_params = md.external_params
    if ! haskey(ext_params, name)
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = ext_params[name]

    if param isa ScalarModelParameter
        if update_timesteps && raise_error
            error("Cannot update timesteps; parameter $name is a scalar parameter.")
        end
        _update_scalar_param!(param, value)
    else
        _update_array_param!(md, name, value, update_timesteps, raise_error)
    end

end

function _update_scalar_param!(param::ScalarModelParameter, value)
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

function _update_array_param!(md::ModelDef, name, value, update_timesteps, raise_error)
    # Get original parameter
    param = md.external_params[name]
    
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
        expected_size = ([length(dim_keys(md, d)) for d in param.dimensions]...,)
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
            new_timestep_array = get_timestep_array(md, T, N, value)
            md.external_params[name] = ArrayModelParameter(new_timestep_array, param.dimensions)
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
    nothing
end

"""
    update_params!(md::ModelDef, parameters::Dict{T, Any}; update_timesteps = false) where T

For each (k, v) in the provided `parameters` dictionary, update_param! 
is called to update the external parameter by name k to value v, with optional 
Boolean argument update_timesteps. Each key k must be a symbol or convert to a
symbol matching the name of an external parameter that already exists in the 
model definition.
"""
function update_params!(md::ModelDef, parameters::Dict; update_timesteps = false)
    parameters = Dict(Symbol(k) => v for (k, v) in parameters)
    for (param_name, value) in parameters
        _update_param!(md, param_name, value, update_timesteps; raise_error = false)
    end
    nothing
end


function add_connector_comps(md::ModelDef)
     conns = md.internal_param_conns        # we modify this, so we don't use functional API

    for comp_def in compdefs(md)
        comp_name = name(comp_def)

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_name == comp_name, conns)
        need_conn_comps = filter(x -> x.backup !== nothing, internal_conns)

        # println("Need connectors comps: $need_conn_comps")

        for (i, conn) in enumerate(need_conn_comps)
            push!(md.backups, conn.backup)

            num_dims = length(size(external_param(md, conn.backup).values))

            if ! (num_dims in (1, 2))
                error("Connector components for parameters with > 2 dimensions are not implemented.")
            end

            # Fetch the definition of the appropriate connector commponent
            conn_name = num_dims == 1 ? :ConnectorCompVector : :ConnectorCompMatrix
            conn_comp_def = compdef(conn_name)
            conn_comp_name = connector_comp_name(i)

            # Add the connector component before the user-defined component that required it
            # println("add_connector_comps: add_comp!(md, $(conn_comp_def.comp_id), $conn_comp_name, before=$comp_name)")
            add_comp!(md, conn_comp_def, conn_comp_name, before=comp_name)
           
            # add a connection between src_component and the ConnectorComp
            push!(conns, InternalParameterConnection(conn.src_comp_name, conn.src_var_name,
                                                     conn_comp_name, :input1, 
                                                     conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            push!(conns, InternalParameterConnection(conn_comp_name, :output, 
                                                     conn.dst_comp_name, conn.dst_par_name, 
                                                     conn.ignoreunits))

            # add a connection between ConnectorComp and the external backup data
            push!(md.external_param_conns, ExternalParameterConnection(conn_comp_name, :input2, conn.backup))

        end
    end

    # Save the sorted component order for processing
    md.sorted_comps = _topological_sort(md)

    return nothing
end


#
# Support for automatic ordering of components
#

"""
    dependencies(md::ModelDef, comp_name::Symbol)

Return the set of component names that `comp_name` in `md` depends one, i.e.,
sources for which `comp_name` is the destination of an internal connection.
"""
function dependencies(md::ModelDef, comp_name::Symbol)
    conns = internal_param_conns(md)
    # For the purposes of the DAG, we don't treat dependencies on [t-1] as an ordering constraint
    deps = Set(c.src_comp_name for c in conns if (c.dst_comp_name == comp_name && c.offset == 0))
    return deps
end

"""
    comp_graph(md::ModelDef)

Return a MetaGraph containing a directed (LightGraph) graph of the components of 
ModelDef `md`. Each vertex has a :name property with its component name.
"""
function comp_graph(md::ModelDef)
    comp_names = collect(compkeys(md))
    graph = MetaDiGraph()

    for comp_name in comp_names
        add_vertex!(graph, :name, comp_name)
    end

    set_indexing_prop!(graph, :name)
   
    for comp_name in comp_names
        for dep_name in dependencies(md, comp_name)
            src = graph[dep_name,  :name]
            dst = graph[comp_name, :name]
            add_edge!(graph, src, dst)
        end
    end

    if is_cyclic(graph)
        error("Component graph contains a cycle")
    end

    return graph
end

"""
    _topological_sort(md::ModelDef)

Build a directed acyclic graph referencing the positions of the components in 
the OrderedDict of model `md`, tracing dependencies to create the DAG.
Perform a topological sort on the graph for the given model and return a vector 
of component names in the order that will ensure dependencies are processed 
prior to dependent components.
"""
function _topological_sort(md::ModelDef)
    graph = comp_graph(md)
    ordered = topological_sort_by_dfs(graph)
    names = map(i -> graph[i, :name], ordered)
    return names
end
