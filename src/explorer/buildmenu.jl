## Build menu tree structure for explorer

function tree_view_values(model::Model)
    all_subcomps = []
    for comp_def in compdefs(model)
        subcomp = tree_view_values(model, nameof(comp_def), comp_def)
        push!(all_subcomps, subcomp)
    end

    # Return sorted list so that the UI list of items will be in lexicographic order 
    return sort(all_subcomps, by = x -> lowercase(x["name"]))
end

function tree_view_values(model::Model, comp_name::Symbol, comp_def::AbstractComponentDef)
    sub_comp_item = _tree_view_node(comp_name)
    for subcomp in compdefs(comp_def)
        push!(sub_comp_item["children"], tree_view_values(model, nameof(subcomp), subcomp));
    end
    return sub_comp_item
end

function _tree_view_node(comp_name::Symbol)
    return Dict("name" => "$comp_name", "children" => Dict[])
end

# Create the list of variables and parameters
function menu_item_list(model::Model)
    var_menuitems = []
    par_menuitems = []

    for comp_def in compdefs(model)
        all_subcomp_values = menu_item_list(model, nameof(comp_def), comp_def)
        append!(var_menuitems, all_subcomp_values["vars"])
        append!(par_menuitems, all_subcomp_values["pars"])
    end

    # Return sorted list so that the UI list of items will be in lexicographic order 
    return Dict("vars" => sort(var_menuitems, by = x -> lowercase(x["name"])),"pars" => sort(par_menuitems, by = x -> lowercase(x["name"])))
end

# Create the list of variables and parameters
function menu_item_list(m::Model, comp_name::Symbol, comp_def::AbstractComponentDef)
    var_menu_items = map(var_name -> _menu_item(m, Symbol(comp_name), var_name), variable_names(comp_def));
    par_menu_items = map(par_name -> _menu_item(m, Symbol(comp_name), par_name), parameter_names(comp_def));
    
    # Return sorted list so that the UI list of items will be in lexicographic order 
    return Dict("vars" => sort(var_menu_items, by = x -> lowercase(x["name"])),"pars" => sort(par_menu_items, by = x -> lowercase(x["name"])))
end

function menu_item_list(sim_inst::SimulationInstance)
    all_menuitems = []
    for datum_key in sim_inst.sim_def.savelist
        menu_item = _menu_item(sim_inst, datum_key)
        if menu_item !== nothing
            push!(all_menuitems, menu_item) 
        end
    end

    # Return sorted list so that the UI list of items will be in lexicographic order 
    return sort(all_menuitems, by = x -> lowercase(x["name"]))
end

function _menu_item(m::Model, comp_name::Symbol, item_name::Symbol)
    dims = dim_names(m, comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end

    if length(dims) == 0
        paths = _get_all_paths(m)
        comp_path = paths[comp_name];
        value = m[comp_path, item_name]
        name = "$comp_name : $item_name = $value"
    elseif length(dims) > 2
        @warn("$comp_name.$item_name has > 2 indexed dimensions, not yet implemented in explorer")
        name = "$comp_name : $item_name (CANNOT DISPLAY)"
    else
        name = "$comp_name : $item_name"          # the name is needed for the list label
    end

    menu_item = Dict("name" => name, "comp_name" => comp_name, "item_name" => item_name)
    return menu_item
end

function _menu_item(sim_inst::SimulationInstance, datum_key::Tuple{Symbol, Symbol})
    (comp_name, item_name) = datum_key
    dims = dim_names(sim_inst.models[1], comp_name, item_name)
    if length(dims) > 2
        # Drop references to singleton dimensions
        dims = tuple([dim for dim in dims if dim_count(m, dim) != 1]...)
    end

    if length(dims) > 2
        @warn("$comp_name.$item_name has >2 graphing dims, not yet implemented in explorer")
        name = "$comp_name : $item_name (CANNOT DISPLAY)"
    else
        name = "$comp_name : $item_name"          # the name is needed for the list label
    end

    menu_item = Dict("name" => "$item_name", "comp_name" => comp_name, "item_name" => item_name)
    return menu_item
end
