type MarginalModel
    base::Model
    marginal::Model
    delta::Float64
end

function getindex(m::MarginalModel, component::Symbol, name::Symbol)
    return (m.marginal[component,name].-m.base[component,name])./m.delta
end
