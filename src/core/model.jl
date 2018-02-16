import Base: delete!

#
# User facing struct that unifies a ModelDef and a ModelInstance and delegates
# function calls to one or the other as appropriate.
#

model_def(m::Model) = m.md

model_instance(m::Model) = m.mi

number_type(m::Model) = m.number_type

@modelegate comp_instance(m::Model, id::ComponentId) => mi

@modelegate external_parameter_connections(m::Model) => mi

@modelegate internal_parameter_connections(m::Model) => mi

@modelegate external_parameter(m::Model, name::Symbol) => mi

@modelegate external_parameter_values(m::Model, name::Symbol) => mi

@modelegate set_external_parameter(m::Model, name::Symbol, value::ModelParameter) => mi

@modelegate add_internal_parameter_conn(m::Model, conn::InternalParameterConnection) => mi

@modelegate get_unconnected_parameters(m::Model) => mi

@modelegate set_leftover_parameters(m::Model, parameters::Dict{String,Any}) => mi

"""
    components(m::Model)

List all the components in model `m`.
"""
@modelegate compdefs(m::Model) => md

@modelegate compdef(m::Model, comp_name::Symbol) => md

@modelegate numcomponents(m::Model) => md

@modelegate timelabels(m::Model) => md

@modelegate indexcounts(m::Model) => md

@modelegate indexcount(m::Model, idx::Symbol) => md

@modelegate indexvalues(m::Model) => md

@modelegate indexvalue(m::Model, idx::Symbol) => md

function addcomponent(m::Model, comp_def::ComponentDef;
                      start=nothing, final=nothing, before=nothing, after=nothing)
    addcomponent(m.md, comp_def, start=start, final=final, before=before, after=after)
    m.mi = Nullable{ModelInstance}()
    ComponentReference(m, name(comp_def))
end

"""
    setindex(m::Model, name::Symbol, valuerange::Range)

Set the values of `Model`'s index `name` to the values in the given `range`.
"""
@modelegate setindex(m::Model, name::Symbol, range::Range) => md

"""
    setindex(m::Model, name::Symbol, count::Int)

Set the values of `Model`'s' index `name` to integers 1 through `count`.
"""
@modelegate setindex(m::Model, name::Symbol, count::Int) => md

@modelegate setindex{T}(m::Model, name::Symbol, values::Vector{T}) => md

@modelegate check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol) => md

@modelegate parameter_dimensions(m::Model, comp_id::ComponentId, param_name::Symbol) => md

@modelegate parameter_unit(m::Model, comp_id::ComponentId, param_name::Symbol) => md
#
# TBD: this might not be right...
#
parameter(m::Model, comp_def::ComponentDef, param_name::Symbol) = parameter(comp_def, param_name)

parameter(m::Model, comp_name::Symbol, param_name::Symbol) = parameter(m, compdef(m, comp_name), param_name)

function parameters(m::Model, comp_name::Symbol)
    comp_def = compdef(m, comp_name)
    return collect(keys(comp_def.parameters))
end

function variable(m::Model, comp_id::ComponentId, param_name::Symbol)
    comp_def = compdef(m, comp_id)
    return comp_def.variables[param_name]
end

function variable_unit(m::Model, comp_id::ComponentId, param_name::Symbol)
    var = variable(m, comp_id, param_name)
    return var.unit
end

function variable_dimensions(m::Model, comp_id::ComponentId, param_name::Symbol)
    var = variable(m, comp_id, param_name)
    return var.dimensions
end

"""
    variables(m::Model, comp_name::Symbol)

List all the variables of `comp_name` in model `m`.
"""
function variables(m::Model, comp_name::Symbol)
    comp_def = compdef(m, comp_name)
    return collect(keys(comp_def.variables))
end

getduration(m::Model) = getduration(indexvalues(m))

"""
    delete!(m::ModelDef, component::Symbol

Delete a component by name from a models' ModelDef, and nullify the ModelInstance.
"""
function delete!(m::Model, comp_name::Symbol)
    delete!(m.md, comp_name)
    m.mi = Nullable{ModelInstance}()
end

function setparameter(m::Model, comp_name::Symbol, param_name::Symbol, value, dims)
    setparameter(m.md, comp_name, param_name, value, dims)    
    m.mi = Nullable{ModelInstance}()
end

"""
    run(m::Model)

Run model `m` once.
"""
function run(m::Model; ntimesteps=typemax(Int))
    if numcomponents(m) == 0
        error("Cannot run a model with no components.")
    end

    if isnull(m.mi)
        m.mi = Nullable{ModelInstance}(build(m))
    end

    run(get(m.mi), ntimesteps, indexvalues(m))
end
