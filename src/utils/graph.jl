#
# Graph Functionality
#

function _filter_connections(conns::Vector{InternalParameterConnection}, comp_path::ComponentPath, which::Symbol)
    if which == :all
        f = obj -> (obj.src_comp_path == comp_path || obj.dst_comp_path == comp_path)
    elseif which == :incoming
        f = obj -> obj.dst_comp_path == comp_path
    elseif which == :outgoing
        f = obj -> obj.src_comp_path == comp_path
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end

    return collect(Iterators.filter(f, conns))
end

get_connections(m::Model, ci::LeafComponentInstance, which::Symbol) = get_connections(m, pathof(ci), which)

function get_connections(m::Model, cci::CompositeComponentInstance, which::Symbol)
    conns = []
    for ci in components(cci)
        append!(conns, get_connections(m, pathof(ci), which))
    end
    return conns
end

function get_connections(m::Model, comp_path::ComponentPath, which::Symbol)
    md = modeldef(m)
    return _filter_connections(internal_param_conns(md), comp_path, which)
end

function get_connections(m::Model, comp_name::Symbol, which::Symbol)
    comp = compdef(m, comp_name)
    get_connections(m, comp.comp_path, which)
end

function get_connections(mi::ModelInstance, comp_path::ComponentPath, which::Symbol)
    md = modeldef(mi)
    return _filter_connections(internal_param_conns(md), comp_path, which)
end
