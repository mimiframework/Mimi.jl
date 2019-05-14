#
# User-facing Model types providing a simplified API to model definitions and instances.
#
"""
    Model

A user-facing API containing a `ModelInstance` (`mi`) and a `ModelDef` (`md`).
This `Model` can be created with the optional keyword argument `number_type` indicating
the default type of number used for the `ModelDef`.  If not specified the `Model` assumes
a `number_type` of `Float64`.
"""
mutable struct Model <: MimiStruct
    md::ModelDef
    mi::Union{Nothing, ModelInstance}

    function Model(number_type::DataType=Float64)
        return new(ModelDef(number_type), nothing)
    end

    # Create a copy of a model, e.g., to create marginal models
    function Model(m::Model)
        return new(deepcopy(m.md), nothing)
    end
end

"""
    MarginalModel

A Mimi `Model` whose results are obtained by subtracting results of one `base` Model
from those of another `marginal` Model` that has a difference of `delta`.
"""
struct MarginalModel <: MimiStruct
    base::Model
    marginal::Model
    delta::Float64

    function MarginalModel(base::Model, delta::Float64=1.0)
        return new(base, Model(base), delta)
    end
end

function Base.getindex(mm::MarginalModel, comp_name::Symbol, name::Symbol)
    return (mm.marginal[comp_name, name] .- mm.base[comp_name, name]) ./ mm.delta
end
