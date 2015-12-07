export ComponentReference

import Base.setindex!, Base.getindex

"""
A container for a component, for interacting with it within a model.
"""
type ComponentReference
    m::Model
    component::Symbol
end

"""
Set a component parameter as `setparameter(reference, name, value)`.
"""
function setparameter(c::ComponentReference, name::Symbol, value)
    setparameter(c.m, c.component, name, value)
end

"""
Set a component parameter as `reference[symbol] = value`.
"""
function setindex!(c::ComponentReference, value, name::Symbol)
    setparameter(c.m, c.component, name, value)
end

"""
Connect two components as `connectparameter(reference1, name1, reference2, name2)`.
"""
function connectparameter(target::ComponentReference, target_name::Symbol, source::ComponentReference, source_name::Symbol)
    connectparameter(target.m, target.component, target_name, source.component, source_name)
end

"""
Connect two components as `connectparameter(reference1, reference2, name)`.
"""
function connectparameter(target::ComponentReference, source::ComponentReference, name::Symbol)
    connectparameter(target.m, target.component, name, source.component, name)
end

"""
A container for a name within a component, to improve connectparameter aesthetics.
"""
type VariableReference
    m::Model
    component::Symbol
    name::Symbol
end

"""
Get a variable reference as `reference[name]`.
"""
function getindex(c::ComponentReference, name::Symbol)
    VariableReference(c.m, c.component, name)
end

"""
Connect two components as `reference1[name1] = reference2[name2]`.
"""
function setindex!(target::ComponentReference, source::VariableReference, name::Symbol)
    connectparameter(target.m, target.component, name, source.component, source.name)
end
