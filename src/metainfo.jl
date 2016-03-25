module metainfo

type MetaVariable
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::UTF8String
    unit::UTF8String
end

type MetaComponent
    name::Symbol

    variables::Dict{Symbol,MetaVariable}

    function MetaComponent(name::Symbol)
        v = new(name, Dict{Symbol, MetaVariable}())
        return v
    end
end

const global _mimi_metainfo = Dict{Symbol,MetaComponent}()

function addcomponent(comp::DataType)
    component_name = symbol(comp)
    c = MetaComponent(component_name)
    _mimi_metainfo[component_name] = c
    nothing
end

function addvariable(comp::DataType, name, datatype, dimensions, description, unit)
    component_name = symbol(comp)
    c = _mimi_metainfo[component_name]

    v = MetaVariable(name, datatype, dimensions, description, unit)
    c.variables[name] = v
    nothing
end

function getallcomps()
    _mimi_metainfo
end

end
