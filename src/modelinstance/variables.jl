struct Variables{NAMES,TYPES}
    vals::TYPES

    function Variables{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

@generated function get_property(v::Variables{NAMES,TYPES}, ::Val{PROPERTYNAME}) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = findfirst(NAMES, PROPERTYNAME)
    index_pos==0 && error("Unknown variable name $PROPERTYNAME.")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][])
    else
        return :(v.vals[$index_pos])
    end
end

@generated function set_property(v::Variables{NAMES,TYPES}, ::Val{PROPERTYNAME}, value) where {NAMES,TYPES,PROPERTYNAME}
    index_pos = findfirst(NAMES, PROPERTYNAME)
    index_pos==0 && error("Unknown variable name $PROPERTYNAME.")

    if TYPES.parameters[index_pos] <: Ref
        return :(v.vals[$index_pos][] = value)
    else
        error("You cannot override indexed variable $PROPERTYNAME.")
    end
end

x = Variables{(:a,:b), Tuple{Ref{Float64}, Vector{Float64}}}((4., [2.,5.]))

get_property(x, Val(:a))

