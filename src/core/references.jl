"""
    set_param!(ref::ComponentReference, name::Symbol, value)

Set a component parameter as `set_param!(reference, name, value)`.
"""
function set_param!(ref::ComponentReference, name::Symbol, value)
    set_param!(ref.parent, ref.comp_path, name, value)
end

"""
    set_param!(ref.parent, ref.comp_name, name, value)

Set a component parameter as `reference[symbol] = value`.
"""
function Base.setindex!(ref::ComponentReference, value, name::Symbol)
    set_param!(ref.parent, ref.comp_path, name, value)
end

"""
    connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)

Connect two components as `connect_param!(dst, dst_name, src, src_name)`.
"""
function connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)
    connect_param!(dst.parent, dst.comp_path, dst_name, src.comp_path, src_name)
end

"""
    connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)

Connect two components with the same name as `connect_param!(dst, src, name)`.
"""
function connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)
    connect_param!(dst.parent, dst.comp_path, name, src.comp_path, name)
end

"""
    Base.getindex(ref::ComponentReference, name::Symbol)

Get a sub-comp, parameter, or variable reference as `ref[name]`.
"""
function Base.getindex(ref::ComponentReference, name::Symbol)
    VariableReference(ref, var_name)
end

# Methods to convert components, params, and vars to references
# for use with getproperty() chaining.
function make_reference(obj::AbstractComponentDef)
    return ComponentReference(parent(obj), nameof(obj))
end

function make_reference(obj::VariableDef)
    comp_def = find_comp(obj)
    return VariableReference(pathof(comp_def), nameof(obj))
end

function make_reference(obj::ParameterDef)
    comp_def = find_comp(obj)
    return ParameterReference(pathof(comp_def), nameof(obj))
end

function Base.getproperty(ref::ComponentReference, name::Symbol)
    comp_def = find_comp(ref)
    return make_reference(comp_def[name]) # might be ref to comp, var, or param
end

function _same_composite(ref1::AbstractComponentReference, ref2::AbstractComponentReference)
    # @info "same_composite($(ref1.comp_path), $(ref2.comp_path))"
    return ref1.comp_path.names[1] == ref2.comp_path.names[1]
end

"""
    Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)

Connect two components as `comp_ref[var_name] = var_ref`.
"""
function Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)
    _same_composite(comp_ref, var_ref)|| error("Can't connect variables defined in different composite trees")

    connect_param!(comp_ref.parent, comp_ref.comp_path, var_name, var_ref.comp_path, var_ref.var_name)
end
