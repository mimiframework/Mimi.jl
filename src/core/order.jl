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
