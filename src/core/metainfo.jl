# module metainfo
using DataStructures

# export
#     get_componentdef_variables, # deprecated
#     ComponentDef,
#     ComponentKey,
#     ModelDef,
#     addcomponent,
#     addvariable,
#     addparameter,
#     adddimension,
#     getvariables,
#     getparameters,
#     getdimensions,
#     getcompdef,
#     getcompdefs  

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

# convenience methods
ComponentDef(mod_name::Symbol, comp_name::Symbol) = ComponentDef(ComponentKey(mod_name, comp_name))

ComponentDef(comp_name::Symbol) = ComponentDef(ComponentKey(comp_name))

# Component definitions are global, keyed by module and component name
const global _compdefs = Dict{ComponentKey, ComponentDef}()

getcompdefs() = _compdefs

getcompdef(key) = _compdefs[key]

getcompdef(mod_name::Symbol, comp_name::Symbol) = getcompdef(ComponentKey(mod_name, comp_name))

# Just renamed for clarity
@deprecate getallcomps() getcompdefs()

function dump_components()
    for comp in _compdefs
        println("\n$(comp.key)")
        for (tag, d) in ((:Variables, comp.getvariables()), (:Parameters, comp.getparameters()), (:Dimensions, comp.getdimensions()))
            println("  $tag")
            for (name, def) in d
                println("    $name = $def")
            end
        end
    end
end

function addcomponent(key::ComponentKey)
    println("addcomponent($(key))")
    if haskey(_compdefs, key)
        warn("Redefining component :$(key.comp_name) in module :$(key.module_name)")
    end

    comp = ComponentDef(key)
    _compdefs[key] = comp
    return comp
end

# Might be useful
addcomponent(comp_name::Symbol) = addcomponent(ComponentKey(comp_name))

@deprecate addcomponent(mod::Symbol, comp::Symbol) addcomponent(ComponentKey(mod, comp))

#
# Model
#

# Declarative definition of a model used to create a ModelInstance
mutable struct ModelDef
    name::Symbol
    comps::Vector{ComponentDef}

    conns::Any # TBD: should be a DAG of components

    function ModelDef(name::Symbol)
        ModelDef(name, Vector{ComponentDef}())
    end
end

function addcomponent(model::ModelDef, comp::ComponentDef)
    push!(model.comps, comp)
    nothing
end

getcompdefs(model::ModelDef) = model.comps

#
# Variables
#
function addvariable(comp::ComponentDef, name, datatype, dimensions, description, unit)
    v = VariableDef(name, datatype, dimensions, description, unit)
    comp.variables[name] = v
    return v
end

function addvariable(key::ComponentKey, name, datatype, dimensions, description, unit)
    addvariable(getcompdef(key), name, datatype, dimensions, description, unit)
end

@deprecate addvariable(mod::Symbol, comp::Symbol, name, datatype, dims, desc, unit) addvariable(ComponentKey(mod, comp), name, datatype, dims, desc, unit)

getvariables(comp::ComponentDef) = values(comp.variables)

getvariables(key::ComponentKey) = getvariables(getcompdef(key))

@deprecate get_componentdef_variables(mod::Symbol, comp::Symbol) getvariables(ComponentKey(mod, comp))

@deprecate get_componentdef_variables(comp_type::Type) getvariables(ComponentKey(Symbol(name.module), name.name))

# RP: needed to add this. Unclear if method above is necessary, but I doubt it.
@deprecate get_componentdef_variables(name::Any) getvariables(ComponentKey(Symbol(name.module), name.name))

#
# Parameters
#
function addparameter(comp::ComponentDef, name, datatype, dimensions, description, unit)
    p = ParameterDef(name, datatype, dimensions, description, unit)
    comp.parameters[name] = p
    return p
end

function addparameter(key::ComponentKey, name, datatype, dimensions, description, unit)
    addparameter(getcompdef(key), name, datatype, dimensions, description, unit)
end

@deprecate set_external_parameter(mod::Symbol, comp::Symbol, name, datatype, dims, desc, unit) addparameter(getcompdef(ComponentKey(mod, comp)), name, datatype, dims, desc, unit)

getparameters(comp::ComponentDef) = values(comp.parameters)

#
# Dimensions
#
function adddimension(comp::ComponentDef, name)
    d = DimensionDef(name)
    comp.dimensions[name] = d
    return d
end

adddimension(key::ComponentKey, name) = adddimension(getcompdef(key), name)

@deprecate adddimension(mod::Symbol, comp::Symbol, name) adddimension(ComponentKey(mod, comp), name)

getdimensions(comp::ComponentDef) = values(comp.dimensions)

#
# run_timestep function
#

# Save the expression defining the run_timestep function. (It's created at build-time.)
function set_run_expr(comp::ComponentDef, expr::Expr)
    comp.run_expr = expr
    nothing
end

get_run_expr(comp::ComponentDef) = comp.run_expr

#
# Type expressions
#
function addexpr(comp::ComponentDef, tag::Symbol, expr::Expr)
    comp.expressions[tag] = expr
    nothing
end

getexpr(comp::ComponentDef, tag::Symbol) = comp.expressions[tag]

#
# Code generation from ComponentDef
#
@deprecate generate_comp_expressions(mod::Symbol, comp::Symbol) genexpressions(getcompdef(ComponentKey(mod, comp)))

@deprecate generate_comp_expressions(key::ComponentKey) genexpressions(getcompdef(key))

# TBD: Rewrite to accommodate dot-overloading approach.
# Generate type expressions for variables, parameters, and dimensions
# function genexpressions(comp::ComponentDef)
#     parameters = getparameters(comp)
#     variables  = getvariables(comp)
#     dimensions = getdimensions(comp)

#     comp_name = comp.key.comp_name
#     pname = Symbol(string(comp_name, "Parameters"))
#     vname = Symbol(string(comp_name, "Variables"))
#     dname = Symbol(string(comp_name, "Dimensions"))

#     # TBD: note dependence on :time being first dimensions
#     arrayparameters = collect(Iterators.filter(p->(0 < length(p.dimensions) <= 2 && p.dimensions[1] == :time), parameters))
    
#     param_names = length(arrayparameters) == 0 ? [] : 
#                   collect(Iterators.flatten([(Symbol("OFFSET$i"), Symbol("DURATION$i")) for i in 1:length(arrayparameters)]))
             
#     ptype_signature = :($(pname){T, $(param_names...)})

#     std_args = (:T, :OFFSET, :DURATION, :FINAL)
#     impl_name = Symbol(string(comp_name, "Impl"))

#     impl_signature = :($impl_name{$(std_args...), $(param_names...)})
#     impl_constructor = :($impl_signature(indices) where {$(std_args...), $(param_names...)})

#     println("\nptype: $ptype_signature")
#     println("\nctor: $impl_constructor")
#     println("\nsig: $impl_signature")

#     # Timestep types indexed by number of dimensions indicting their respective use
#     timestep_types = (:TimestepVector, :TimestepMatrix)

#     # Define types for parameters
#     ex = Expr(:block)
#     i = 1
#     for p in parameters
#         concreteParameterType = p.datatype == Number ? :T : p.datatype
#         dims = length(p.dimensions)

#         if dims == 0
#             push!(ex.args, :($(p.name)::$concreteParameterType))

#         # TBD: note dependence on :time being first dimensions
#         elseif (dims in (1, 2) && p.dimensions[1] == :time)
#             offset   = Symbol("OFFSET$i")
#             duration = Symbol("DURATION$i")          
#             ttype = timestep_types[dims] # TimestepVector or TimestepMatrix
#             push!(ex.args, :($(p.name)::$ttype{$concreteParameterType, $offset, $duration}))
#             i += 1

#         else
#             push!(ex.args, :($(p.name)::Array{$concreteParameterType, $dims}) )
#         end
#     end

#     addexpr(comp, :whatever, ex)


#     # Define type for variables
#     ex = Expr(:block)
#     for v in variables
#         varname = v.name
#         concreteVariableType = v.datatype == Number ? :T : v.datatype
#         dims = length(v.dimensions)

#         if dims == 0
#             push!(ex.args, :($varname::$(concreteVariableType)))
            
#         # TBD: note dependence on :time being first dimensions
#         elseif dims in (1, 2) && v.dimensions[1] == :time
#             ttype = timestep_types[dims] # TimestepVector or TimestepMatrix
#             push!(ex.args, :($varname::$ttype{$(concreteVariableType), OFFSET, DURATION}))

#         else
#             push!(ex.args, :($varname::Array{$(concreteVariableType), $dims}))
#         end
#     end

#     # Define type for dimensions
#     mutable struct $(Symbol(string(comp_name,"Dimensions")))
#         $(begin
#             x = Expr(:block)
#             for d in dimensions
#                 push!(x.args, :($(d.name)::UnitRange{Int}) )
#             end
#             x
#         end)

#         function $(Symbol(string(comp_name,"Dimensions")))(indices)
#             s = new()
#             $(begin
#                 ep = Expr(:block)
#                 for d in dimensions
#                     push!(ep.args,:(s.$(d.name) = UnitRange{Int}(1,indices[$(QuoteNode(d.name))])))
#                 end
#                 ep
#             end)
#             return s
#         end
#     end

#     # Define implementation typeof
#     mutable struct $(impl_signature) <: Main.$(Symbol(module_name)).$(Symbol(comp_name))
#         nsteps::Int
#         Parameters::$(ptype_signature)
#         Variables::$(Symbol(string(comp_name,"Variables"))){T, OFFSET, DURATION, FINAL}
#         Dimensions::$(Symbol(string(comp_name,"Dimensions")))

#         $(Expr(:function, impl_constructor,
#             :(return new{$([[:T, :OFFSET, :DURATION, :FINAL]; (length(arrayparameters) == 0 ? [] : collect(Iterators.flatten([(Symbol("OFFSET$i"),Symbol("DURATION$i")) for i in 1:length(arrayparameters)])))]...)}(
#                 indices[:time],
#                 $(ptype_signature)(),
#                 $(Symbol(string(comp_name,"Variables"))){T, OFFSET, DURATION, FINAL}(indices),
#                 $(Symbol(string(comp_name,"Dimensions")))(indices)
#             ))
#         ))
#     end

#     # println(compexpr)
#     return compexpr
# end

# end # module
