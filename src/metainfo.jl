module metainfo

type MetaVariable
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

    function MetaComponent(module_name::Symbol, component_name::Symbol)
        v = new(module_name, component_name, Dict{Symbol, MetaVariable}())
        return v
    end
end

const global _mimi_metainfo = Dict{Tuple{Symbol,Symbol},MetaComponent}()

function addcomponent(comp::DataType)
    component_name = symbol(comp)
    module_name = symbol(comp.name.module)
    c = MetaComponent(module_name, component_name)
    _mimi_metainfo[(module_name, component_name)] = c
    nothing
end

function addvariable(comp::DataType, name, datatype, dimensions, description, unit)
    component_name = symbol(comp)
    module_name = symbol(comp.name.module)
    c = _mimi_metainfo[(module_name, component_name)]

    v = MetaVariable(name, datatype, dimensions, description, unit)
    c.variables[name] = v
    nothing
end

function getallcomps()
    _mimi_metainfo
end

end
