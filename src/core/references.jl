"""
Set a component parameter as `set_parameter!(reference, name, value)`.
"""
function set_parameter!(ref::ComponentReference, name::Symbol, value)
    set_parameter!(ref.model, ref.comp_name, name, value)
end

"""
Set a component parameter as `reference[symbol] = value`.
"""
function Base.setindex!(ref::ComponentReference, value, name::Symbol)
    set_parameter!(ref.model, ref.comp_name, name, value)
end

"""
Connect two components as `connect_parameter(reference1, name1, reference2, name2)`.
"""
function connect_parameter(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)
    connect_parameter(dst.model, dst.comp_id, dst_name, src.comp_id, src_name)
end

"""
Connect two components with the same name as `connect_parameter(reference1, reference2, name)`.
"""
function connect_parameter(dst::ComponentReference, src::ComponentReference, name::Symbol)
    connect_parameter(dst.model, dst.comp_id, name, src.comp_id, name)
end


"""
Get a variable reference as `comp_ref[var_name]`.
"""
function Base.getindex(comp_ref::ComponentReference, var_name::Symbol)
    VariableReference(comp_ref.model, comp_ref.comp_name, var_name)
end

"""
Connect two components as `comp_ref[var_name] = var_ref`.
"""
function Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)
    comp_ref.model == var_ref.model || error("Can't connect variables defined in different models")

    connect_parameter(comp_ref.model, comp_ref.comp_name, var_name, var_ref.comp_name, var_ref.var_name)
end
