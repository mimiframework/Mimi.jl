#
# Graph Functionality
#
function show(io::IO, m::Model)
    println(io, "showing model component connections:")
    for item in enumerate(keys(m.components2))
        c = item[2]
        i_connections = get_connections(m,c,:incoming)
        o_connections = get_connections(m,c,:outgoing)
        println(io, item[1], ". ", c, " component")
        println(io, "    incoming parameters:")
        if length(i_connections) == 0
            println(io, "      none")
        else
            [println(io, "      - ",e.target_parameter_name," from ",e.source_component_name," component") for e in i_connections]
        end
        println(io, "    outgoing variables:")
        if length(o_connections) == 0
            println(io, "      none")
        else
            [println(io, "      - ",e.source_variable_name," in ",e.target_component_name, " component") for e in o_connections]
        end
    end
end

function get_connections(m::Model, c::ComponentInstance, which::Symbol)
    return get_connections(m, c.comp_def.key.comp_name, which)
end

function _filter_connections(conns::Vector{InternalParameterConnection}, comp_name::Symbol, which::Symbol)
    if which == :all
        f = e -> e.source_component_name == comp_name || e.target_component_name == comp_name
    elseif which == :incoming
        f = e -> e.target_component_name == comp_name
    elseif which == :outgoing
        f = e -> e.source_component_name == comp_name
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end

    return collect(Iterators.filter(f, conns))
end

function get_connections(m::Model, component_name::Symbol, which::Symbol)
    return _filter_connections(m.internal_parameter_connections, component_name, which)
end

function get_connections(mi::ModelInstance, component_name::Symbol, which::Symbol)
    return _filter_connections(mi.internal_parameter_connections, component_name, which)
end
