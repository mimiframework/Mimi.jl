type edge
  # param_node: the "in" node (listed first in connectparameter)
  # var_node: the "out" node (listed second in connectparameter)
  name::Symbol
  param_node::Symbol #name of component
  var_node::Symbol #name of component
end

type ModelGraph
  edges
  nodes
  size
end
ModelGraph(e,n) = ModelGraph(e, n, length(n))
ModelGraph() = ModelGraph([],[],0)

function add_edge(g::ModelGraph, e::edge)
  @assert e.param_node in g.nodes && e.var_node in g.nodes ["Tried to add an edge between vertices not in the graph"]
  append!(g.edges, [e])
end

function add_node(g::ModelGraph, n::Symbol)
  append!(g.nodes, [n])
  g.size += 1
end

function get_all_edges(g::ModelGraph)
  return g.edges
end

function get_all_nodes(g::ModelGraph)
  return g.nodes
end

function print_graph(g::ModelGraph)
  for c in get_all_nodes(g)
    i_edges = get_edges(g,c,"incoming")
    o_edges = get_edges(g,c,"outgoing")
    println(c)
    println("  incoming parameters:")
    [println("    - ",e.name," from ",e.var_node) for e in i_edges]
    println("  outgoing variables:")
    [println("    - ",e.name," from ",e.param_node) for e in o_edges]
  end
end

function string_representation(g::ModelGraph)
  rep = ""
  for c in get_all_nodes(g)
    i_edges = get_edges(g,c,"incoming")
    o_edges = get_edges(g,c,"outgoing")
    rep = string(rep, c, "\n")
    rep = string(rep, "  incoming parameters:", "\n")
    for e in i_edges
      rep = string(rep, "    - ",e.name," from ",e.var_node,"\n")
    end
    rep = string(rep, "  outgoing variables:", "\n")
    for e in o_edges
      rep = string(rep, "    - ",e.name," from ",e.var_node,"\n")
    end
  end
  return rep
end

function get_edges(g::ModelGraph, component::Symbol, which::String)
  which = uppercase(which)
  lst=[]
  if which=="ALL"
    for e in get_all_edges(g)
      if e.param_node==component || e.var_node==component
        append!(lst, [e])
      end
    end
  elseif which=="INCOMING"
    for e in get_all_edges(g)
      if e.param_node==component
        append!(lst, [e])
      end
    end
  elseif which=="OUTGOING"
    for e in get_all_edges(g)
      if e.var_node==component
        append!(lst, [e])
      end
    end
  else
    @assert false ["Invalid parameter to the 'which' argument; must be 'all' or 'incoming' or 'outgoing'."]
  end
  return(lst)
end
