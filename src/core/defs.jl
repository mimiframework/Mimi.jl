# Global component registry: @defcomp stores component definitions here
global const _compdefs = Dict{ComponentId, ComponentDef}()

compdefs() = collect(values(_compdefs))

compdef(comp_id::ComponentId) = _compdefs[comp_id]

function compdef(comp_name::Symbol)
    matches = collect(filter(obj -> name(obj) == comp_name, values(_compdefs)))
    count = length(matches)

    if count == 1
        return matches[1]
    elseif count == 0
        error("Component $comp_name was not found in the global registry")
    else
        error("Multiple components named $comp_name were found in the global registry")
    end
end

compdefs(md::ModelDef) = values(md.comp_defs)

compkeys(md::ModelDef) = keys(md.comp_defs)

hascomp(md::ModelDef, comp_name::Symbol) = haskey(md.comp_defs, comp_name)

compdef(md::ModelDef, comp_name::Symbol) = md.comp_defs[comp_name]

reset_compdefs() = empty!(_compdefs)

# Return the module object for the component was defined in
compmodule(comp_id::ComponentId) = comp_id.module_name

compname(comp_id::ComponentId) = comp_id.comp_name

# Gets the name of all NamedDefs: VariableDef, whereDef, ComponentDef, DimensionDef
name(def::NamedDef) = def.name

number_type(md::ModelDef) = md.number_type

numcomponents(md::ModelDef) = length(md.comp_defs)


function dump_components()
    for comp in compdefs()
        println("\n$(name(comp))")
        for (tag, objs) in ((:Variables, variables(comp)), (:Parameters, parameters(comp)), (:Dimensions, dimensions(comp)))
            println("  $tag")
            for obj in objs
                println("    $(obj.name) = $obj")
            end
        end
    end
end

"""
    newcomponent(module_name::Symbol, comp_name::Symbol)

Create an empty `ComponentDef`` to the global component registry with a comp_id created
from `module_name` and `comp_name`. The empty `ComponentDef` must be populated with 
calls to `addvariable`, `addparameter`, etc.
"""
function newcomponent(module_name::Symbol, comp_name::Symbol)
    full_name = "$(module_name).$(comp_name)"
    comp_id = ComponentId(module_name, comp_name)

    if haskey(_compdefs, comp_id)
        warn("Redefining component $full_name")
    else
        println("new component $full_name")
    end

    comp_def = ComponentDef(comp_id)
    _compdefs[comp_id] = comp_def
    return comp_def
end


import Base.delete!

"""
    delete!(m::ModelDef, component::Symbol

Delete a component by name from a model definition.
"""
function delete!(md::ModelDef, comp_name::Symbol)
    if ! haskey(md.comp_defs, comp_name)
        error("Cannot delete '$comp_name' from model; component does not exist.")
    end

    delete!(md.comp_defs, comp_name)

    ipc_filter = x -> x.src_comp_name != comp_name && x.dst_comp_name != comp_name
    filter!(ipc_filter, md.internal_param_conns)

    epc_filter = x -> x.comp_name != comp_name
    filter!(epc_filter, md.external_param_conns)  
end

#
# Dimensions
#
function add_dimension(comp::ComponentDef, name)
    d = DimensionDef(name)
    comp.dimensions[name] = d
    return d
end

add_dimension(comp_id::ComponentId, name) = add_dimension(compdef(comp_id), name)

dimensions(comp_def::ComponentDef) = values(comp_def.dimensions)

# Functions shared by VariableDef and ParameterDef (both <: DatumDef)
dimensions(def::DatumDef) = def.dimensions

dimensions(param::ArrayModelParameter) = param.dimensions

datatype(def::DatumDef) = def.datatype

datatype(md::ModelDef, def::DatumDef) = def.datatype == Number ? number_type(md) : def.datatype

description(def::DatumDef) = def.description

unit(def::DatumDef) = def.unit


duration(md::ModelDef) = duration(indexvalues(md))

function duration(index_values::Dict{Symbol, Vector{Any}})
    values = index_values[:time]
    # N.B. assumes that all timesteps of the model are the same length
    return length(values) > 1 ? values[2] - values[1] : 1
end


function check_parameter_dimensions(md::ModelDef, value::AbstractArray, dims::Vector, name::Symbol)
    for dim in dims
        if dim in keys(indexvalues(md))
            if isa(value, NamedArray)
                labels = names(value, findnext(dims, dim, 1))
                dim_values = indexvalues(md, dim)
                for i in 1:length(labels)
                    if labels[i] != dim_values[i]
                        error("Labels for dimension $dim in parameter $name do not match model's index values")
                    end
                end
            end
        else
            error("Dimension $dim in parameter $name not found in model's dimensions")
        end
    end
end

indexcounts(md::ModelDef) = md.index_counts

indexcount(md::ModelDef, idx::Symbol) = md.index_counts[idx]

indexvalues(md::ModelDef) = md.index_values

indexvalues(md::ModelDef, idx::Symbol) = md.index_values[idx]

timelabels(md::ModelDef) = md.time_labels

function setindex(md::ModelDef, name::Symbol, range::Range)
    md.index_counts[name] = length(range)
    md.index_values[name] = Vector(range)
    md.time_labels = Vector()
    nothing
end

function setindex(md::ModelDef, name::Symbol, count::Int)
    md.index_counts[name] = count
    md.index_values[name] = collect(1:count)
    md.time_labels = Vector()
    nothing
end

# helper function for setindex; used to determine if the provided time values are a uniform range.
function isuniform(values::Vector)
    # TBD: handle zero-length here or in setindex?

    if length(values) in (1, 2)
        return true
    end

    stepsize = values[2] - values[1]
    for i in 3:length(values)
        if (values[i] - values[i - 1]) != stepsize
            return false
        end
    end

    return true
end

"""
    setindex{T}(m::Model, name::Symbol, values::Vector{T})

Set the values of `Model`'s index `name` to `values`.
"""
function setindex(md::ModelDef, name::Symbol, values::Vector)
    md.index_counts[name] = length(values)
    if name == :time
        if ! isuniform(values) # case where time values aren't uniform
            md.time_labels = values
            md.index_values[name] = collect(1:length(values))
        else # case where time values are uniform
            md.index_values[name] = copy(values)
            md.time_labels = Vector()
        end
    else
        md.index_values[name] = copy(values)
    end
    nothing
end

#
# Parameters
#
function addparameter(comp_def::ComponentDef, name, datatype, dimensions, description, unit)
    p = ParameterDef(name, datatype, dimensions, description, unit)
    comp_def.parameters[name] = p
    return p
end

function addparameter(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addparameter(compdef(comp_id), name, datatype, dimensions, description, unit)
end

parameters(comp_def::ComponentDef) = values(comp_def.parameters)

parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

parameter_names(comp_def::ComponentDef) = [name(param) for param in parameters(comp_def)]

parameter(comp_def::ComponentDef, name::Symbol) = comp_def.parameters[name]

parameter(md::ModelDef, comp_name::Symbol, param_name::Symbol) = parameter(compdef(md, comp_name), param_name)

"""
Return a list of all parameter names for a given component in a model def.
"""
parameter_names(md::ModelDef, comp_name::Symbol) = parameter_names(compdef(md, comp_name))

function parameter_unit(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(md, comp_name, param_name)
    return param.unit
end

function parameter_dimensions(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(md, comp_name, param_name)
    return param.dimensions
end

"""
    set_parameter(m::ModelDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter of a component in a model to a given value. Value can by a scalar,
an array, or a NamedAray. Optional argument 'dims' is a list of the dimension names of
the provided data, and will be used to check that they match the model's index labels.
"""
function set_parameter(md::ModelDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    comp_def = compdef(md, comp_name)

    # perform possible dimension and labels checks
    if isa(value, NamedArray)
        dims = dimnames(value)
    end

    if dims != nothing
        check_parameter_dimensions(md, value, dims, param_name)
    end

    # now set the parameter
    comp_param_dims = parameter_dimensions(md, comp_name, param_name)
    
    # array parameter case
    if length(comp_param_dims) > 0 
        # convert the number type and, if NamedArray, convert to Array
        value = convert(Array{number_type(md)}, value) 
    
        if comp_param_dims[1] == :time
            offset = comp_def.start                    # TBD: check that this is correct
            dur = duration(md)

            T = eltype(value)
            num_dims = length(comp_param_dims)

            values = num_dims == 1 ? TimestepVector{T, offset, dur}(value) :
                    (num_dims == 2 ? TimestepMatrix{T, offset, dur}(value) : value)
        else
            values = value
        end

        set_external_array_param(md, param_name, values, dims)

    else # scalar parameter case
        set_external_scalar_param(md, param_name, value)
    end

    connect_parameter(md, comp_name, param_name, param_name)
    nothing
end

#
# Variables
#
variables(comp_def::ComponentDef) = values(comp_def.variables)

variable(comp_def::ComponentDef, name::Symbol) = comp_def.variables[name]

variables(comp_id::ComponentId) = variables(compdef(comp_id))

variable(md::ModelDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(md, comp_name), var_name)

function variable_unit(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
    return var.unit
end

function variable_dimensions(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
    return var.dimensions
end

# Add a variable to a ComponentDef
function addvariable(comp_def::ComponentDef, name, datatype, dimensions, description, unit)
    v = VariableDef(name, datatype, dimensions, description, unit)
    comp_def.variables[name] = v
    return v
end

# Add a variable to a ComponentDef referenced by ComponentId
function addvariable(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addvariable(compdef(comp_id), name, datatype, dimensions, description, unit)
end

#
# Other
#

# Return the number of timesteps a given component in a model will run for.
function getspan(md::ModelDef, comp_name::Symbol)
    duration = duration(md)
    comp_def = comp_def(md, comp_name)
    start = comp_def.offset
    final = comp_def.final
    return Int((final - start) / duration + 1)
end

# Could be deprecated if expression is just emitted as part of @defcomp.
# Save the expression defining the run_timestep function. (It's eval'd at build-time.)
function set_run_expr(comp_def::ComponentDef, expr::Expr)
    comp_def.run_expr = expr
    nothing
end

# Could be deprecated as above.
run_expr(comp_def::ComponentDef) = comp_def.run_expr

function set_run_period!(comp_def::ComponentDef, start, final)
    comp_def.start = start
    comp_def.final = final
    return nothing
end

#
# Model
#
"""
    addcomponent(md::ModelDef, comp_def::ComponentDef; start=nothing, final=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the model. The component is added at the end of the list unless
one of the keywords, `start`, `final`, `before`, `after`
"""
function addcomponent(md::ModelDef, comp_def::ComponentDef, comp_name::Symbol;
                      start=nothing, final=nothing, before=nothing, after=nothing)
    # check that start and final are within the model's time index range
    time_index = indexvalues(md, :time)

    if start == nothing
        start = time_index[1]
    elseif start < time_index[1]
        error("Cannot add component $name with start time before start of model's time index range.")
    end

    if final == nothing
        final = time_index[end]
    elseif final > time_index[end]
        error("Cannot add component $name with final time after end of model's time index range.")
    end

    if before != nothing && after != nothing
        error("Cannot specify both 'before' and 'after' parameters")
    end

    # Check if component being added already exists
    if hascomp(md, comp_name)
        error("Cannot add two components of the same name ($comp_name)")
    end

    if before == nothing && after == nothing
        set_run_period!(comp_def, start, final)
        md.comp_defs[comp_name] = comp_def   # just add it to the end
        return nothing
    end

    newcomponents = OrderedDict{Symbol, ComponentDef}

    if before != nothing
        if ! hascomp(md, before)
            error("Component to add before ($before) does not exist")
        end

        for i in compkeys(md)
            if i == before
                set_run_period!(comp_def, start, final)
                newcomponents[comp_name] = comp_def
            end
            newcomponents[i] = md.comp_defs[i]
        end

    else    # after != nothing, since we've handled all other possibilities above
        if ! hascomp(md, after)
            error("Component to add before ($before) does not exist")
        end

        for i in compkeys(md)
            newcomponents[i] = md.comp_defs[i]
            if i == after
                set_run_period!(comp_def, start, final)
                newcomponents[comp_name] = comp_def
            end
        end
    end

    md.comp_defs = newcomponents
    println("md.comp_defs: $(md.comp_defs)")
    return nothing
end

function addcomponent(md::ModelDef, comp_id::ComponentId, comp_name::Symbol;
                      start=nothing, final=nothing, before=nothing, after=nothing)
    println("Adding component $(comp_id.module_name).$(comp_id.comp_name) as :$comp_name")
    addcomponent(md, compdef(comp_id), comp_name, start=start, final=final, before=before, after=after)
end
