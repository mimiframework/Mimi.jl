#
# Graph Functionality
#


function _show_conns(io, m, comp_name, which::Symbol)
    datumtype = which == :incoming ? "parameters" : "variables"
    println(io, "   $which $datumtype:")

    conns = get_connections(m, comp_name, which)

    if length(conns) == 0
        println(io, "      none")
    else
        for conn in conns
            if which == :incoming
                println(io, "      - $(conn.src_comp_name).$(conn.dst_par_name)")
            else
                println(io, "      - $(conn.dst_comp_name).$(conn.src_var_name)")
            end
        end
    end
end

function show(io::IO, m::Model)
    println(io, "Model component connections:")

    for (i, comp_name) in enumerate(compkeys(m.md))
        comp_def = compdef(m.md, comp_name)
        println(io, "$i. $(comp_def.comp_id) as :$(comp_def.name)")
        _show_conns(io, m, comp_name, :incoming)
        _show_conns(io, m, comp_name, :outgoing)
    end
end

function _filter_connections(conns::Vector{InternalParameterConnection}, comp_name::Symbol, which::Symbol)
    if which == :all
        f = obj -> (obj.src_comp_name == comp_name || obj.dst_comp_name == comp_name)
    elseif which == :incoming
        f = obj -> obj.dst_comp_name == comp_name
    elseif which == :outgoing
        f = obj -> obj.src_comp_name == comp_name
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end

    return collect(Iterators.filter(f, conns))
end

function get_connections(m::Model, ci::LeafComponentInstance, which::Symbol)
    return get_connections(m, name(ci.comp), which)
end

function get_connections(m::Model, cci::CompositeComponentInstance, which::Symbol)
    conns = []
    for ci in components(cci)
        append!(conns, get_connections(m, ci, which))
    end
    return conns
end

function get_connections(m::Model, comp_name::Symbol, which::Symbol)
    return _filter_connections(internal_param_conns(m.md), comp_name, which)
end

function get_connections(mi::ModelInstance, comp_name::Symbol, which::Symbol)
    return _filter_connections(internal_param_conns(mi.md), comp_name, which)
end
