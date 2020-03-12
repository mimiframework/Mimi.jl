"""
    set_param!(ref::ComponentReference, name::Symbol, value)

Set a component parameter as `set_param!(reference, name, value)`.
"""
function set_param!(ref::ComponentReference, name::Symbol, value)
    set_param!(parent(ref), pathof(ref), name, value)
end

"""
    Base.setindex!(ref::ComponentReference, value, name::Symbol)

Set a component parameter as `reference[symbol] = value`.
"""
function Base.setindex!(ref::ComponentReference, value, name::Symbol)
    set_param!(parent(ref), pathof(ref), name, value)
end

"""
    connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)

Connect two components as `connect_param!(dst, dst_name, src, src_name)`.
"""
function connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)
    connect_param!(parent(dst), pathof(dst), dst_name, pathof(src), src_name)
end

"""
    connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)

Connect two components with the same name as `connect_param!(dst, src, name)`.
"""
function connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)
    connect_param!(parent(dst), pathof(dst), name, pathof(src), name)
end

"""
    Base.getindex(ref::ComponentReference, name::Symbol)

Get a sub-comp, parameter, or variable reference as `ref[name]`.
"""
function Base.getindex(ref::ComponentReference, name::Symbol)
    VariableReference(ref, name)
end

# Methods to convert components, params, and vars to references
# for use with getproperty() chaining.
function _make_reference(obj::AbstractComponentDef, comp_ref::ComponentReference)
    return ComponentReference(parent(obj), nameof(obj))
end

function _make_reference(obj::VariableDef, comp_ref::ComponentReference)
    return VariableReference(comp_ref, obj.name)
end

function _make_reference(obj::ParameterDef, comp_ref::ComponentReference)
    return ParameterReference(comp_ref, obj.name)
end

function Base.getproperty(ref::ComponentReference, name::Symbol)
    comp = find_comp(ref)
    return _make_reference(getfield(comp, name), ref) # might be ref to comp, var, or param
end

function _same_composite(ref1::AbstractComponentReference, ref2::AbstractComponentReference)
    # @info "same_composite($(ref1.comp_path), $(ref2.comp_path))"
    return head(pathof(ref1)) == head(pathof(ref2))
end

"""
    Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)

Connect two components as `comp_ref[var_name] = var_ref`.
"""
function Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, vname::Symbol)
    _same_composite(comp_ref, var_ref) || error("Can't connect variables defined in different composite trees")

    connect_param!(parent(comp_ref), pathof(comp_ref), vname, pathof(var_ref), var_name(var_ref))
end
