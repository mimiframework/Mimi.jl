#
# Support for dot-overloading in run_timestep functions
#

function _get_index_pos(names, propname, var_or_par)
    index_pos = findfirst(names, propname)
    index_pos == 0 && error("Unknown $var_or_par name $propname.")
    return index_pos
end

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

