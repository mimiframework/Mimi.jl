module metainfo

type MetaVariable
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::UTF8String
    unit::UTF8String
end

type MetaComponent
    name::UTF8String
    variables::Dict{Symbol,MetaVariable}
end

const global _mimi_metainfo = Dict{Type,MetaComponent}()

function addcomponent(comp::DataType)
    c = MetaComponent(string(comp), Dict{Symbol, MetaVariable}())
    _mimi_metainfo[comp] = c
    nothing
end

function addvariable(comp::DataType, name, datatype, dimensions, description, unit)
    c = _mimi_metainfo[comp]

    v = MetaVariable(name, datatype, dimensions, description, unit)
    c.variables[name] = v
    nothing
end

function getallcomps()
    _mimi_metainfo
end

end
