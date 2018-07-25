"""
Removes any parameter connections for a given parameter in a given component.
"""
function disconnect!(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    # println("disconnect!($comp_name, $param_name)")
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

    if !(eltype(ext_param.values) <: datatype(param_def))
        t1 = eltype(ext_param.values)
        t2 = datatype(param_def)
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
            # if length(index_values[dim]) != size(ext_param.values)[i]
            if dim_count(md, dim) != size(ext_param.values)[i]
                n1 = dim_count(md, dim)
                n2 = size(ext_param.values)[i]
                error("Mismatched data size for a parameter connection: $(comp_def.comp_id): dim :$dim has $n1 elements; parameter :$param_name has $n2 elements.")
            end
        end
    end
end

"""
    connect_parameter(md::ModelDef, component::Symbol, name::Symbol, parametername::Symbol)

Connect a parameter in a component to an external parameter.
"""
function connect_parameter(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)
    comp_def = compdef(md, comp_name)
    ext_param = external_param(md, ext_param_name)

    if isa(ext_param, ArrayModelParameter)
        _check_labels(md, comp_def, param_name, ext_param)
    end

    disconnect!(md, comp_name, param_name)

    conn = ExternalParameterConnection(comp_name, param_name, ext_param_name)
    add_external_param_conn(md, conn)

    return nothing
end

"""
    connect_parameter(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, src_var_name::Symbol backup::Union{Void, Array}=nothing; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connect_parameter(md::ModelDef, 
                           dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol,
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)

    # remove any existing connections for this dst parameter
    disconnect!(md, dst_comp_name, dst_par_name)

    if backup != nothing
        # If value is a NamedArray, we can check if the labels match
        if isa(backup, NamedArray)
            dims = dimnames(backup)
            check_parameter_dimensions(md, backup, dims, dst_par_name)
        else
            dims = nothing
        end

        # Check that the backup value is the right size
        if getspan(md, dst_comp_name) != size(backup)[1]
            error("Backup data must span the whole length of the component.")
        end

        dst_comp_def = compdef(md, dst_comp_name)
        src_comp_def = compdef(md, src_comp_name)

        # some other check for second dimension??
        dst_param = parameter(dst_comp_def, dst_par_name)
        dst_dims  = dimensions(dst_param)

        backup = convert(Array{number_type(md)}, backup) # converts number type and, if it's a NamedArray, it's converted to Array
        first = first_period(dst_comp_def)
        T = eltype(backup)        
        
        dim_count = length(dst_dims)

        if dim_count == 0
            values = backup
        else
            
            if isuniform(md)
                #use the first from the comp_def not the ModelDef
                _, stepsize = first_and_step(md)
                values = TimestepArray{FixedTimestep{first, stepsize}, T, dim_count}(backup)
            else
                times = time_labels(md)
                #use the first from the comp_def 
                first_index = findfirst(times, first)
                values = TimestepArray{VariableTimestep{(times[first_index:end]...)}, T, dim_count}(backup)
            end
            
        end

        set_external_array_param!(md, dst_par_name, values, dst_dims)
    end

    # Check the units, if provided
    if ! ignoreunits && ! verify_units(variable_unit(md, src_comp_name, src_var_name), 
                                       parameter_unit(md, dst_comp_name, dst_par_name))
        error("Units of $src_comp_name.$src_var_name do not match $dst_comp_name.$dst_par_name.")
    end

    # println("connect($src_comp_name.$src_var_name => $dst_comp_name.$dst_par_name)")
    conn = InternalParameterConnection(src_comp_name, src_var_name, dst_comp_name, dst_par_name, ignoreunits, offset=offset)
    add_internal_param_conn(md, conn)

    return nothing
end

"""
    connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Union{Void, Array}=nothing; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component, using `backup` to provide default values.
"""
function connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Union{Void, Array}=nothing; ignoreunits::Bool=false, offset::Int=0)
    connect_parameter(md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, offset=offset)
end

"""
Return list of parameters that have been set for component c in model m.
"""
function connected_params(md::ModelDef, comp_name::Symbol)
    ext_set_params = map(x->x.param_name,   external_param_conns(md, comp_name))
    int_set_params = map(x->x.dst_par_name, internal_param_conns(md, comp_name))

    return union(ext_set_params, int_set_params)
end

"""
    unconnected_params(md::ModelDef)

Return a list of tuples (componentname, parametername) of parameters
that have not been connected to a value in the model.
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
    set_leftover_params!(m::Model, parameters::Dict{Any,Any})

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary. This method assumes the dictionary
keys are strings that match the names of unset parameters in the model.
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
        connect_parameter(md, comp_name, param_name, param_name)
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

external_param_values(md::ModelDef, name::Symbol) = md.external_params[name].values

function add_external_param_conn(md::ModelDef, conn::ExternalParameterConnection)
    push!(md.external_param_conns, conn)
end

function set_external_param!(md::ModelDef, name::Symbol, value::ModelParameter)
    md.external_params[name] = value
end

function set_external_param!(md::ModelDef, name::Symbol, value::Number; param_dims::Union{Void,Array{Symbol}} = nothing)
    set_external_scalar_param!(md, name, value)
end

function set_external_param!(md::ModelDef, name::Symbol, value::Union{AbstractArray, Range, Tuple}; param_dims::Union{Void,Array{Symbol}} = nothing)
    
    num_dims = length(param_dims)

    if num_dims in (1, 2) && param_dims[1] == :time   
        value = convert(Array{md.number_type}, value)

        values = get_timestep_instance(md, eltype(value), num_dims, value)
                 
    else
         values = value
    end

    set_external_array_param!(md, name, values, param_dims)
end

"""
    set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepVector, dims)

Adds a one dimensional time-indexed array parameter to the model.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepVector, dims)
    # println("set_external_array_param!: dims=$dims, setting dims to [:time]")
    param = ArrayModelParameter(value, [:time])  # must be :time
    set_external_param!(md, name, param)
end

"""
    set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepMatrix, dims)

Adds a multi-dimensional time-indexed array parameter to the model.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::TimestepArray, dims)
    param = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_param!(md, name, param)
end

"""
    set_external_array_param!(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter to the model.
"""
function set_external_array_param!(md::ModelDef, name::Symbol, value::AbstractArray, dims)
    numtype = md.number_type
    
    if !(typeof(value) <: Array{numtype})
        numtype = number_type(md)
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{numtype}(value)
    end
    param = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_param!(md, name, param)
end

"""
    set_external_scalar_param!(md::ModelDef, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_param!(md::ModelDef, name::Symbol, value::Any)
    p = ScalarModelParameter(value)
    set_external_param!(md, name, p)
end


function add_connector_comps(md::ModelDef)
     conns = md.internal_param_conns        # we modify this, so we don't use functional API

    for comp_def in compdefs(md)
        comp_name = name(comp_def)

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_name == comp_name, conns)
        need_conn_comps = filter(x -> x.backup != nothing, internal_conns)

        # println("Need connectors comps: $need_conn_comps")

        for (i, conn) in enumerate(need_conn_comps)
            push!(md.backups, conn.backup)

            num_dims = length(size(external_param(md, conn.backup)))

            if ! (num_dims in (1, 2))
                error("Connector components for parameters with > 2 dimensions are not implemented.")
            end

            # Fetch the definition of the appropriate connector commponent
            conn_name = num_dims == 1 ? :ConnectorCompVector : :ConnectorCompMatrix
            conn_comp_def = compdef(conn_name)
            conn_comp_name = connector_comp_name(i)

            # Add the connector component before the user-defined component that required it
            # println("add_connector_comps: addcomponent(md, $(conn_comp_def.comp_id), $conn_comp_name, before=$comp_name)")
            addcomponent(md, conn_comp_def, conn_comp_name, before=comp_name)
           
            # add a connection between src_component and the ConnectorComp
            push!(conns, InternalParameterConnection(conn.src_comp_name, conn.src_var_name,
                                                     conn_comp_name, :input1, 
                                                     conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            push!(conns, InternalParameterConnection(conn_comp_name, :output, 
                                                     conn.dst_comp_name, conn.dst_par_name, 
                                                     conn.ignoreunits))
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

Return the set of component names that `comp_name` depends one, i.e.,
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

Build a directed acyclic graph referencing the positions of the 
components in the OrderedDict, tracing dependencies to create the DAG.
Perform a topological sort on the graph for the given model and
return a vector of component names in the order that will ensure
dependencies are processed prior to dependent components.
"""
function _topological_sort(md::ModelDef)
    graph = comp_graph(md)
    ordered = topological_sort_by_dfs(graph)
    names = map(i -> graph[i, :name], ordered)
    return names
end
