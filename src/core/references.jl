export ComponentReference

import Base.setindex!, Base.getindex

# TBD: this isn't as useful as it could be, since model definition remains tedious.
# How about this to connect parameters between components where names are the same.
# Could even find these using set intersection.
#
# Instead of this:
#   CO2cycle[:rt_g0_baseglobaltemp]   = climatetemperature[:rt_g0_baseglobaltemp]
#   CO2cycle[:rt_g_globaltemperature] = climatetemperature[:rt_g_globaltemperature]
#
# We'd do:
#   connectparameters(m, climatetemperature, CO2cycle, :rt_g0_baseglobaltemp, :rt_g_globaltemperature)
# Might not be enough cases like this to warrant it though...
# 
# function connectparameters(m::Model, src_comp::Symbol, dst_comp::Symbol, names...)
#     for name in names
#         connectparameter(m, dst_comp, name, src_comp, name)
#     end
# end

"""
A container for a component, for interacting with it within a model.
"""
struct ComponentReference
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
struct VariableReference
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
