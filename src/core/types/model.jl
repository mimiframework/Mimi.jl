#
# User-facing Model types providing a simplified API to model definitions and instances.
#

abstract type AbstractModel <: MimiStruct end

"""
    Model

A user-facing API containing a `ModelInstance` (`mi`) and a `ModelDef` (`md`).
This `Model` can be created with the optional keyword argument `number_type` indicating
the default type of number used for the `ModelDef`.  If not specified the `Model` assumes
a `number_type` of `Float64`.
"""
mutable struct Model <: AbstractModel
    md::ModelDef
    mi::Union{Nothing, ModelInstance}

    function Model(number_type::DataType=Float64)
        return new(ModelDef(number_type), nothing)
    end

    # Create a copy of a model, e.g., to create marginal models
    function Model(m::Model)
        return new(deepcopy(m.md), nothing)
    end

    # Create a model from a ModelInstance (temporary for explore call)
    function Model(mi::ModelInstance)
        return new(deepcopy(mi.md), deepcopy(mi))
    end
end

"""
    MarginalModel

A Mimi `Model` whose results are obtained by subtracting results of one `base` Model
from those of another `marginal` Model that has a difference of `delta`.
"""
struct MarginalModel <: AbstractModel
    base::Model
    modified::Model
    delta::Float64
end

function MarginalModel(base::Model, delta::Float64=1.0)
    return MarginalModel(base, Model(base), delta)
end

function Base.getindex(mm::MarginalModel, comp_name::Symbol, name::Symbol)
    return (mm.modified[comp_name, name] .- mm.base[comp_name, name]) ./ mm.delta
end

function Base.getindex(mm::MarginalModel, comp_path::ComponentPath, name::Symbol)
    return (mm.modified.mi[comp_path, name] .- mm.base.mi[comp_path, name]) ./ mm.delta
end

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

# -- throw errors --

# -- throw warnings --

function Base.getproperty(base::MarginalModel, s::Symbol)
    if (s == :marginal)
        error("Use of `MarginalModel.marginal` is deprecated in favor of `MarginalModel.modified`.")
    end
    return getfield(base, s);
end
