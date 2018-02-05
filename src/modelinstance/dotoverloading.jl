@generated function get_property(v::ModelInstanceComponentVariables{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = findfirst(NAMES, PROPERTYNAME)
    index_pos==0 && error("Unknown variable name $PROPERTYNAME.")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][])
    else
        return :(v.vals[$index_pos])
    end
end

@generated function set_property!(v::ModelInstanceComponentVariables{NAMES,TYPES}, 
                                  ::Val{PROPERTYNAME}, value) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = findfirst(NAMES, PROPERTYNAME)
    index_pos==0 && error("Unknown variable name $PROPERTYNAME.")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][] = value)
    else
        error("You cannot override indexed variable $PROPERTYNAME.")
    end
end

@generated function get_property(v::ModelInstanceComponentParameters{NAMES,TYPES}, 
                                 ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = findfirst(NAMES, PROPERTYNAME)
    index_pos==0 && error("Unknown variable name $PROPERTYNAME.")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][])
    else
        return :(v.vals[$index_pos])
    end
end
