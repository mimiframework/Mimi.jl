"""
Removes any parameter connections for a given parameter in a given component.
"""
function disconnect(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    filter!(x -> !(x.dst_comp_name == comp_name && x.dst_par_name == param_name), internal_param_conns(md))
    filter!(x -> !(x.comp_name == comp_name && x.param_name == param_name), external_param_conns(md))
end

# Default string, string unit check function
function _verify_units(one::AbstractString, two::AbstractString)
    # True if and only if they match
    return one == two
end

function _check_labels(md::ModelDef, comp_def::ComponentDef, param_name::Symbol, ext_param::ArrayModelParameter)
    param_def = parameter(comp_def, param_name)

    if !(eltype(ext_param.values) <: datatype(param_def))
        error("Mismatched datatype of parameter connection. Component: $comp_name, Parameter: $param_name")
    end

    comp_dims  = dimensions(param_def)
    param_dims = dimensions(ext_param)

    if ! isempty(param_dims) && size(param_dims) != size(comp_dims)
        error("Mismatched dimensions of parameter connection. Component: $comp_name, Parameter: $param_name")
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
                error("Mismatched data size for a parameter connection. Component: $component, Parameter: $param_name")
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

    disconnect(md, comp_name, param_name)

    conn = ExternalParameterConnection(comp_name, param_name, ext_param_name)
    add_external_param_conn(md, conn)

    return nothing
end

"""
    connect_parameter(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, src_comp_name::Symbol, src_var::Symbol; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connect_parameter(md::ModelDef, dst_comp_name::Symbol, dst_par_name::Symbol, 
                                         src_comp_name::Symbol, src_var_name::Symbol; 
                                         ignoreunits::Bool = false)
    # Check the units, if provided
    if ! ignoreunits && ! _verify_units(variable_unit(md, src_comp_name, src_var_name), 
                                       parameter_unit(md, dst_comp_name, dst_par_name))
        error("Units of $src_component.$src_var_name do not match $dst_component.$dst_par_name.")
    end

    # remove any existing connections for this dst component and parameter
    disconnect(md, src_comp_name, src_var_name)

    curr = InternalParameterConnection(src_comp_name, src_var_name, dst_comp_name, dst_par_name, ignoreunits)
    add_internal_param_conn(md, curr)

    return nothing
end

function connect_parameter(md::ModelDef, 
                           dst_comp_name::Symbol, dst_par_name::Symbol, 
                           src_comp_name::Symbol, src_var_name::Symbol, 
                           backup::Array; ignoreunits::Bool = false)
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
    start = start(dst_comp_def)
    step = step_size(md)
    T = eltype(backup)

    dim_count = length(dst_dims)

    if dim_count in (1, 2)
        ts_type = dim_count == 1 ? TimestepVector : TimestepMatrix
        values = ts_type{T, start, step}(backup)
    else
        values = backup
    end

    set_external_array_param(md, dst_par_name, values, dst_dims)

    # Use the non-backup method to handle the rest
    connect_parameter(md, dst_comp_name, dst_par_name, src_comp_name, src_var_name, ignoreunits)

    return nothing
end

"""
    connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}; 
                           ignoreunits::Bool = false)
    connect_parameter(md, dst[1], dst[2], src[1], src[2]; ignoreunits = ignoreunits)
end

"""
    connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component, using `backup` to provide default values.
"""
function connect_parameter(md::ModelDef, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, 
                           backup::Array; ignoreunits::Bool = false)
    connect_parameter(md, dst[1], dst[2], src[1], src[2], backup; ignoreunits = ignoreunits)
end

"""
Return list of parameters that have been set for component c in model m.
"""
function connected_params(md::ModelDef, comp_name::Symbol)
    ext_connections = Iterators.filter(x -> x.comp_name == comp_name, external_param_conns(md))
    ext_set_params = map(x->x.param_name, ext_connections)

    int_connections = Iterators.filter(x -> x.dst_comp_name == comp_name, internal_param_conns(md))
    int_set_params = map(x->x.dst_par_name, int_connections)

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
    set_leftover_params(m::Model, parameters::Dict{Any,Any})

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary. This method assumes the dictionary
keys are strings that match the names of unset parameters in the model.
"""
function set_leftover_params(md::ModelDef, parameters::Dict{String,Any})
    parameters = Dict(lowercase(k) => v for (k, v) in parameters)
    leftovers = unconnected_params(md)
    external_params = md.external_params

    for (comp_name, param_name) in leftovers
        # check whether we need to set the external parameter
        if ! haskey(md.external_params, param_name)
            value = parameters[lowercase(string(param_name))]
            param_dims = parameter_dimensions(md, comp_name, param_name)
            num_dims = length(param_dims)

            if num_dims == 0    # scalar case
                set_external_scalar_param(md, param_name, value)

            else
                if num_dims in (1, 2) && param_dims[1] == :time   # array case
                    value = convert(Array{md.numberType}, value)
                    # start = indexvalues(md, :time)[1]
                    start = dim_values(md, :time)[1]
                    step = step_size(md)
                    T = eltype(value)
                    values = get_timestep_instance(T, start, step, num_dims, value)
                else
                    values = value
                end
                set_external_array_param(md, param_name, values, param_dims)
            end
        end
        connect_parameter(md, comp_name, param_name, param_name)
    end
    nothing
end

internal_param_conns(md::ModelDef) = md.internal_param_conns

external_param_conns(md::ModelDef) = md.external_param_conns

function external_param(md::ModelDef, name::Symbol)
    try
        return md.external_params[name]
    catch
        error("$name not found in external parameter list")
    end
end

function add_internal_param_conn(md::ModelDef, conn::InternalParameterConnection)
    push!(md.internal_param_conns, conn)
end

external_param_values(md::ModelDef, name::Symbol) = md.external_params[name].values

function add_external_param_conn(md::ModelDef, conn::ExternalParameterConnection)
    push!(md.external_param_conns, conn)
end

function set_external_param(md::ModelDef, name::Symbol, value::ModelParameter)
    md.external_params[name] = value
end

"""
    set_external_array_param(md::ModelDef, name::Symbol, value::TimestepVector, dims)

Adds a one dimensional time-indexed array parameter to the model.
"""
function set_external_array_param(md::ModelDef, name::Symbol, value::TimestepVector, dims)
    # println("set_external_array_param: dims=$dims, setting dims to [:time]")
    param = ArrayModelParameter(value, [:time])
    set_external_param(md, name, param)
end

"""
    set_external_array_param(md::ModelDef, name::Symbol, value::TimestepMatrix, dims)

Adds a two dimensional time-indexed array parameter to the model.
"""
function set_external_array_param(md::ModelDef, name::Symbol, value::TimestepMatrix, dims)
    param = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_param(md, name, param)
end

"""
    set_external_array_param(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter to the model.
"""
function set_external_array_param(md::ModelDef, name::Symbol, value::AbstractArray, dims)
    numtype = md.number_type
    
    if !(typeof(value) <: Array{numtype})
        numtype = number_type(md)
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{numtype}(value)
    end
    param = ArrayModelParameter(value, dims == nothing ? Vector{Symbol}() : dims)
    set_external_param(md, name, param)
end

"""
    set_external_scalar_param(md::ModelDef, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_param(md::ModelDef, name::Symbol, value::Any)
    if typeof(value) <: AbstractArray
        numtype = number_type(md)
        value = convert(Array{numtype}, value)
    end
    p = ScalarModelParameter(value)
    set_external_param(md, name, p)
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
    deps = Set(c.src_comp_name for c in conns if c.dst_comp_name == comp_name)
    return deps
end

# Psuedo-node to ensure that all components have at
# least one dependency so we can walk the graph.
global const START = :__START__

"""
    _topological_sort(md::ModelDef)

Build a directed acyclic graph referencing the positions of the 
components in the OrderedDict, tracing dependencies to create the DAG.
Perform a topological sort on the graph for the given model and
return a vector of component names in the order that will ensure
dependencies are processed prior to dependent components.
"""
function _topological_sort(md::ModelDef)
    comp_names = collect(compkeys(md))
    
    # insert the "start" pseudo component at the front
    insert!(comp_names, 1, :__START__)
    graph = DiGraph(length(comp_names))

    comp_dict = Dict(name => num for (num, name) in enumerate(comp_names))

    for (comp_name, comp_num) in comp_dict
        for dep_name in dependencies(md, comp_name)
            add_edge!(graph, comp_dict[dep_name], comp_num)
        end
    end

    if (! is_directed(graph))
        error("Component graph contains a cycle")
    end

    count = length(comp_names)
    visited = Vector{Bool}(count)
    visited[:] = false
    visited[1] = true

    result = Vector{Symbol}()

    # recursive function to visit nodes in order of dependence
    function visit(i)
        if visited[i]
            outs = outneighbors(graph, i)
            if all(visited[outs])
                return
            end
            # println("outs: $outs")
            if length(outs) > 0
                map(visit, outs)
            end
        else
            ins = inneighbors(graph, i)
            # println("ins: $ins")
            
            if all(visited[ins])
                push!(result, comp_names[i])
                visited[i] = true
            else
                # println("visiting ins $ins")
                # work backwards to visit dependencies
                map(visit, ins)
            end
        end
    end

    map(visit, 2:count)
    return result
end