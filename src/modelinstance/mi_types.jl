using DataStructures

abstract type ComponentInstanceData end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `p` argument. The main role of this type
# is to provide the convenient `p.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the parameters
struct ComponentInstanceParameters{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each parameter. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ComponentInstanceParameters{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `v` argument. The main role of this type
# is to provide the convenient `v.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the variables
struct ComponentInstanceVariables{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each variable. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ComponentInstanceVariables{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# This type just bundles the values that are passed to `run_timestep` in
# one structure. We don't strictly need it, but it makes things cleaner.
struct ComponentInstance{TVARS <: ComponentInstanceVariables, 
                         TPARS <: ComponentInstanceParameters}
    comp_def::ComponentDef
    vars::TVARS
    pars::TPARS
    indices
end

# This type holds the values of a built model and can actually be run.
mutable struct ModelInstance
    # m::ModelDef
    components::OrderedDict{Symbol, ComponentInstance}
    offsets::Array{Int, 1} # in order corresponding with components
    final_times::Array{Int, 1}
end

function _get_index_pos(names, propname, var_or_par)
    index_pos = findfirst(names, propname)
    index_pos == 0 && error("Unknown $var_or_par name $propname.")
    return index_pos
end

# This is shared by parameters' and variables' get_property method
function _get_property_expr(obj::ComponentInstanceData, types, index_pos)
    if types.parameters[index_pos] <: Ref
        return :(obj.vals[$index_pos][])
    else
        return :(obj.vals[$index_pos])
    end
end

@generated function get_property(p::ComponentInstanceParameters{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _get_index_pos(NAMES, PROPERTYNAME, "parameter")
    return _get_property_expr(p, TYPES, index_pos)
end

@generated function get_property(v::ComponentInstanceVariables{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _get_index_pos(NAMES, PROPERTYNAME, "variable")
    return _get_property_expr(v, TYPES, index_pos)
end

@generated function set_property!(v::ComponentInstanceVariables{NAMES,TYPES}, 
                                  ::Val{PROPERTYNAME}, value) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = _get_index_pos(NAMES, PROPERTYNAME, "variable")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][] = value)
    else
        error("You cannot override indexed variable $PROPERTYNAME.")
    end
end

