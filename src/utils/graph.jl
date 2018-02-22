#
# Graph Functionality
#
function show(io::IO, m::Model)
    println(io, "showing model component connections:")
    for (i, c) in enumerate(compkeys(m.md))
        in_conns  = get_connections(m, c, :incoming)
        out_conns = get_connections(m, c, :outgoing)

        println(io, "$i.$c component")
        println(io, "    incoming parameters:")

        if length(in_conns) == 0
            println(io, "      none")
        else
            for conn in in_conns
                println(io, "      - $(conn.dst_param_name) from $(conn.src_comp_name) component")
            end
        end

        println(io, "    outgoing variables:")

        if length(out_conns) == 0
            println(io, "      none")
        else
            for conn in out_conns
                println(io, "      - $(conn.src_var_name) in $(conn.dst_comp_name) component")
            end
        end
    end
end

function get_connections(m::Model, c::ComponentInstance, which::Symbol)
    return get_connections(m, name(c.comp), which)
end

function _filter_connections(conns::Vector{InternalParameterConnection}, comp_name::Symbol, which::Symbol)
    if which == :all
        f = obj -> obj.src_comp_name == comp_name || obj.dst_comp_name == comp_name
    elseif which == :incoming
        f = obj -> obj.dst_comp_name == comp_name
    elseif which == :outgoing
        f = obj -> obj.src_comp_name == comp_name
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end

    return collect(Iterators.filter(f, conns))
end

function get_connections(m::Model, comp_name::Symbol, which::Symbol)
    return _filter_connections(internal_param_conns(m.md), comp_name, which)
end

function get_connections(mi::ModelInstance, comp_name::Symbol, which::Symbol)
    return _filter_connections(internal_param_conns(m.md), comp_name, which)
end
