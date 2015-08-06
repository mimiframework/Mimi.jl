module metainfo

type MetaVariable
	name::Symbol
	datatype::DataType
	dimensions::Array{Any}
	description::String
	unit::String
end

type MetaComponent
	name::String
	variables::Dict{Symbol,MetaVariable}
end

const global _iamfmetainfo = Dict{Type,MetaComponent}()

function addcomponent(comp::DataType)
	c = MetaComponent(string(comp), Dict{Symbol, MetaVariable}())
	_iamfmetainfo[comp] = c
	nothing
end

function addvariable(comp::DataType, name, datatype, dimensions, description, unit)
	c = _iamfmetainfo[comp]

	v = MetaVariable(name, datatype, dimensions, description, unit)
	c.variables[name] = v
	nothing
end

function getallcomps()
	_iamfmetainfo
end

end
