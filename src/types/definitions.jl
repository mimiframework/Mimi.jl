using DataStructures

struct ComponentKey
    module_name::Symbol
    comp_name::Symbol
end

struct ModelKey
    name::Symbol
end

ComponentKey(comp_name::Symbol) = ComponentKey(Base.module_name(current_module()), comp_name)

#
# Do we need separate equivalent types for vars and params? Just defined one as, say, DatumDef?
#
mutable struct VariableDef
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::String
    unit::String
end

mutable struct ParameterDef
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::String
    unit::String
end

mutable struct DimensionDef
    name::Symbol
end

mutable struct ComponentDef
    key::ComponentKey
    variables::OrderedDict{Symbol, VariableDef}
    parameters::OrderedDict{Symbol, ParameterDef}
    dimensions::OrderedDict{Symbol, DimensionDef}

    expressions::Dict{Symbol, Expr} # saved expressions for types, constructors, etc.

    run_expr::Expr # the expression that will create the run function

    # ComponentDefs are created "empty"; elements are subsequently added to them
    # via addvariable, adddimension, etc.
    function ComponentDef(key::ComponentKey)
        self = new(key, 
                   OrderedDict{Symbol, VariableDef}(), 
                   OrderedDict{Symbol, ParameterDef}(), 
                   OrderedDict{Symbol, DimensionDef}(),
                   Dict{Symbol, Expr}())
        return self
    end
end

# Declarative definition of a model used to create a ModelInstance
mutable struct ModelDef
    name::Symbol
    comps::Vector{ComponentDef}

    conns::Any # TBD: should be a DAG of components

    function ModelDef(name::Symbol)
        ModelDef(name, Vector{ComponentDef}())
    end
end
