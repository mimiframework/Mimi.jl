using Mimi

include("/Users/lisarennels/.julia/dev/Mimi/wip/create_composite.jl")

import Mimi: components, ComponentPath, ComponentInstance, LeafComponentInstance,
    CompositeComponentInstance, find_comp, dim_names

## Step 1. COMPONENT MENU LIST: Get the Component Structure of the Model
# Create a lightweight structure holding the ComponentPaths of all components,
# which we can then use to look things up on-click. 

# Note that this traversal could in essence pull out everything we need at once,
# but this file will break it out into the steps we need to (1) create the hierarchy
# of components and their props (2) on click find all variable and parameter names and
# (3) on that click get the dimensions and values used for VegaLite

# primary function to return a dictionary with keys being the component names and
# values being the ComponentPaths
function _get_all_paths(m::Model)
    all_paths = Dict{Symbol, ComponentPath}()
    for comp in components(m) # iterate over top level components
        _add_paths(m, comp, all_paths)
    end
    return all_paths
end

# a helper function to perform a preorder traversal of a given top-level component
# in model m and add that path, and all sub-component paths, to the paths array
function _add_paths(m::Model, comp::Union{CompositeComponentInstance, LeafComponentInstance}, paths::Dict{Symbol, ComponentPath})
    if isa(comp, CompositeComponentInstance)
        paths[comp.comp_name] = comp.comp_path     
        for subcomp in values(comp.comps_dict)
            _add_paths(m, subcomp, paths)
        end
    else # LeafComponentInstance
        paths[comp.comp_name] = comp.comp_path          
    end
    return paths
end

## Step 2. ON CLICK OF A COMPONENT DISPLAY VARIABLE AND PARAMETER NAMES
# For any given component, using the information above, which is just the 
# component name and path, grab the names of bariables and parameters
# bubbled into that component

paths = _get_all_paths(m)
comp_name = :Comp1
comp_path = paths[comp_name]
comp_def = find_comp(m, comp_path)
vars_names = variable_names(comp_def)
par_names = parameter_names(comp_def)


## Step 3. For each Variable and Parameter get the data and dim names

datum_name = vars_names[1]
dims = dim_names(comp_def, datum_name) # only needs the ComponentDefinition
values = m[comp_path, datum_name] # uses the comp_path to access the ComponentInstance
