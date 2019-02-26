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
                println(io, "      - $(conn.src_comp_path).$(conn.dst_par_name)")
            else
                println(io, "      - $(conn.dst_comp_path).$(conn.src_var_name)")
            end
        end
    end
end

show_conns(m::Model) = show_conns(stdout, m)

function show_conns(io::IO, m::Model)
    println(io, "Model component connections:")

    for (i, comp_name) in enumerate(compkeys(m.md))
        comp_def = compdef(m.md, comp_name)
        println(io, "$i. $(comp_def.comp_id) as :$(nameof(comp_def))")
        _show_conns(io, m, comp_name, :incoming)
        _show_conns(io, m, comp_name, :outgoing)
    end
end

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

function get_connections(m::Model, ci::ComponentInstance, which::Symbol)
    if is_leaf(ci)
        return get_connections(m, pathof(ci), which)
    end

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
