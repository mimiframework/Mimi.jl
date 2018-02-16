import Base: setindex!, getindex

"""
Set a component parameter as `setparameter(reference, name, value)`.
"""
function setparameter(ref::ComponentReference, name::Symbol, value)
    setparameter(ref.model, ref.comp_id, name, value)
end

"""
Set a component parameter as `reference[symbol] = value`.
"""
function setindex!(ref::ComponentReference, value, name::Symbol)
    setparameter(ref.model, ref.comp_id, name, value)
end

"""
Connect two components as `connectparameter(reference1, name1, reference2, name2)`.
"""
function connectparameter(target::ComponentReference, target_name::Symbol, source::ComponentReference, source_name::Symbol)
    connectparameter(target.model, target.comp_id, target_name, source.comp_id, source_name)
end

"""
Connect two components as `connectparameter(reference1, reference2, name)`.
"""
function connectparameter(target::ComponentReference, source::ComponentReference, name::Symbol)
    connectparameter(target.model, target.comp_id, name, source.comp_id, name)
end


"""
Get a variable reference as `reference[name]`.
"""
function getindex(ref::ComponentReference, name::Symbol)
    VariableReference(ref.model, ref.comp_id, name)
end

"""
Connect two components as `reference1[name1] = reference2[name2]`.
"""
function setindex!(target::ComponentReference, source::VariableReference, name::Symbol)
    connectparameter(target.model, target.comp_id, name, source.comp_id, source.name)
end
