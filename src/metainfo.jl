module metainfo

type MetaVariable
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::UTF8String
    unit::UTF8String
end

type MetaParameter
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::UTF8String
    unit::UTF8String
end

type MetaComponent
    module_name::Symbol
    component_name::Symbol

    variables::Dict{Symbol,MetaVariable}
    parameters::Dict{Symbol,MetaParameter}

    function MetaComponent(module_name::Symbol, component_name::Symbol)
        v = new(module_name, component_name, Dict{Symbol, MetaVariable}(), Dict{Symbol, MetaVariable}())
        return v
    end
end

const global _mimi_metainfo = Dict{Tuple{Symbol,Symbol},MetaComponent}()

function addcomponent(module_name::Symbol, component_name::Symbol)
    c = MetaComponent(module_name, component_name)
    _mimi_metainfo[(module_name, component_name)] = c
    nothing
end

function addvariable(module_name::Symbol, component_name::Symbol, name, datatype, dimensions, description, unit)
    c = _mimi_metainfo[(module_name, component_name)]

    v = MetaVariable(name, datatype, dimensions, description, unit)
    c.variables[name] = v
    nothing
end

function addparameter(module_name::Symbol, component_name::Symbol, name, datatype, dimensions, description, unit)
    c = _mimi_metainfo[(module_name, component_name)]

    p = MetaParameter(name, datatype, dimensions, description, unit)
    c.parameters[name] = p
    nothing
end

function getallcomps()
    _mimi_metainfo
end

end
