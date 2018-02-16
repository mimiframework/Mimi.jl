# Component definitions are global
const global _compdefs = Dict{ComponentId, ComponentDef}()

# From global component registry
compdefs() = collect(values(_compdefs))

compdef(comp_id::ComponentId) = _compdefs[comp_id]

# Just renamed for clarity
@deprecate getallcomps() compdefs()

# From ModelDef
compdefs(md::ModelDef) = values(md.comp_defs)

compdef(md::ModelDef, comp_name::Symbol) = md.comp_defs[comp_name]

reset_compdefs() = empty!(_compdefs)

# Return the module object for the component was defined in
comp_module(comp_id::ComponentId) = typeof(comp_id).name.module

# Return the symbol name of the module the component was defined in
comp_module_name(comp_id::ComponentId) = Symbol(typeof(comp_id).name.module)

# Gets the name of all NamedDefs: VariableDef, ParameterDef, ComponentDef, DimensionDef
name(def::NamedDef) = def.name

#
# TBD: this needs work
#
# Get the Symbol for the component ID (a type) rather than the symbol
# the user assigned to this component. This handles "ConnectorComp$i"
# components which are of type ConnectorCompMatrix or ...Vector.
function comp_id_name(md::ModelDef, comp_name::Symbol) 
    comp_def = compdef(md, comp_name)
    return name(comp_def.comp_id)
end

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
    newcomponent(comp_id::ComponentId)

Create an empty `ComponentDef`` to the global component registry using the given `comp_id`,
which is a singleton instance of the class defined by @defcomp for this component. The
empty `ComponentDef` must be populated with calls to `addvariable`, `addparameter`, etc.
"""
function newcomponent(comp_id::ComponentId)
    println("new component $comp_id")
    if haskey(_compdefs, comp_id)
        module_name = comp_module(comp_id)
        warn("Redefining component :$comp_id in module $module_name")
    end

    comp = ComponentDef(comp_id)
    _compdefs[comp_id] = comp
    return comp
end

newcomponent(::Type{T}) where {T <: ComponentId} = newcomponent(T())


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

    ipc_filter = x -> x.source_component_name != comp_name && x.target_component_name != comp_name
    filter!(ipc_filter, m.internal_parameter_connections)

    epc_filter = x -> x.component_name != comp_name
    filter!(epc_filter, m.external_parameter_connections)

   
end

components(md::ModelDef) = values(md.components)

#
# Dimensions
#
function adddimension(comp::ComponentDef, name)
    d = DimensionDef(name)
    comp.dimensions[name] = d
    return d
end

adddimension(comp_id::ComponentId, name) = adddimension(compdef(comp_id), name)

dimensions(comp_def::ComponentDef) = values(comp_def.dimensions)

# getexpr(comp::ComponentDef, tag::Symbol) = comp.expressions[tag]

function check_parameter_dimensions(md::ModelDef, value::AbstractArray, dims::Vector, name::Symbol)
    for dim in dims
        if dim in keys(indexvalues(md))
            if isa(value, NamedArray)
                labels = names(value, findnext(dims, dim, 1))
                dim_values = indexvalues(md, dim)
                for i in 1:length(labels)
                    if labels[i] != dim_values[i]
                        error("Parameter labels for $dim dimension in $name, parameter do not match model's indices values")
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

indexvalue(md::ModelDef, idx::Symbol) = md.index_value[idx]

timelabels(md::ModelDef) = md.time_labels

# function setindex(md::ModelDef, name::Symbol, range::Range{T}) where {T}
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
# function setindex(md::ModelDef, name::Symbol, values::Vector{T}) where {T}  
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
function addparameter(comp::ComponentDef, name, datatype, dimensions, description, unit)
    p = ParameterDef(name, datatype, dimensions, description, unit)
    comp.parameters[name] = p
    return p
end

function addparameter(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addparameter(compdef(comp_id), name, datatype, dimensions, description, unit)
end

parameters(comp_def::ComponentDef) = values(comp_def.parameters)

parameter(comp_def::ComponentDef, name::Symbol) = comp_def.parameters[name]

parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

parameter(md::ModelDef, comp_id::ComponentId, param_name::Symbol) = parameter(compdef(md, comp_id), param_name)

function parameter_unit(md::ModelDef, comp_id::ComponentId, param_name::Symbol)
    param = parameter(md, comp_id, param_name)
    return param.unit
end

function parameter_dimensions(md::ModelDef, comp_id::ComponentId, param_name::Symbol)
    param = parameter(md, comp_id, param_name)
    return param.dimensions
end

# TBD: might need to move more guts of ModelInstance to ModelDef
"""
    setparameter(m::ModelDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter of a component in a model to a given value. Value can by a scalar,
an array, or a NamedAray. Optional argument 'dims' is a list of the dimension names of
the provided data, and will be used to check that they match the model's index labels.
"""
function setparameter(md::ModelDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
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
            comp_def = compdef(md, comp_name)
            offset = comp_def.offset                    # TBD: this exists in ModelInstance currently
            duration = getduration(indexvalues(md))

            T = eltype(value)
            num_dims = length(comp_param_dims)

            values = num_dims == 1 ? TimestepVector{T, offset, duration}(value) :
                    (num_dims == 2 ? TimestepMatrix{T, offset, duration}(value) : value)
        else
            values = value
        end

        set_external_array_parameter(md, param_name, values, dims)

    else # scalar parameter case
        set_external_scalar_parameter(md, param_name, value)
    end

    connectparameter(md, comp_name, param_name, param_name)
    nothing
end

#
# Variables
#
variables(comp_def::ComponentDef) = values(comp_def.variables)

variables(comp_id::ComponentId) = variables(compdef(comp_id))

variable(md::ModelDef, comp_id::ComponentId, param_name::Symbol) = variable(compdef(md, comp_id), param_name)

function variable_unit(md::ModelDef, comp_id::ComponentId, var_name::Symbol)
    var = variable(md, comp_id, var_name)
    return var.unit
end

function variable_dimensions(md::ModelDef, comp_id::ComponentId, var_name::Symbol)
    var = variable(md, comp_id, var_name)
    return var.dimensions
end


function addvariable(comp::ComponentDef, name, datatype, dimensions, description, unit)
    v = VariableDef(name, datatype, dimensions, description, unit)
    comp.variables[name] = v
    return v
end

function addvariable(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addvariable(compdef(comp_id), name, datatype, dimensions, description, unit)
end

#
# Other
#

# Save the expression defining the run_timestep function. (It's eval'd at build-time.)
function set_run_expr(comp_def::ComponentDef, expr::Expr)
    comp_def.run_expr = expr
    nothing
end

run_expr(comp_def::ComponentDef) = comp_def.run_expr

#
# Model
#

#
# TBD: might reinstate this if the subsequent function is moved to ModelInstance
#
# function addcomponent(md::ModelDef, comp::ComponentDef)
#     md.comp_defs[comp.comp_id] = comp
#     nothing
# end

"""
    addcomponent(m::Model, comp::Component; start=nothing, final=nothing, before=nothing, after=nothing)

Add the component indicated by `key` to the model. The component is added at the end of the list unless
one of the keywords, `start`, `final`, `before`, `after`
"""
function addcomponent(md::ModelDef, comp_def::ComponentDef;
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
        error("Can only specify before or after parameter")
    end

    comp_name = name(comp_def)

    # Check if component being added already exists
    if comp_name in keys(components(md))
        error("You cannot add two components of the same abstract type ($comp_name)")
    end

    if before == nothing && after == nothing
        # just add it to the end
        md.comp_defs[comp_name] = ComponentInstance(comp_name, start, final)
        return nothing
    end

    newcomponents = OrderedDict{Symbol, ComponentInstance}()    # TBD: make CompDef

    if before != nothing
        if ! haskey(md.comp_defs, before)
            error("Component to add before ($before) does not exist")
        end

        for i in keys(md.components)
            if i == before
                newcomponents[comp_name] = ComponentInstance(comp_name, start, final)   # TBD: make CompDef
            end
            newcomponents[i] = md.components[i]
        end

    else    # after != nothing, since we've handled all other possibilities above
        if ! haskey(md.comp_defs, after)
            error("Component to add before ($before) does not exist")
        end

        for i in keys(m.components)
            newcomponents[i] = md.components[i]
            if i == after
                newcomponents[comp_name] = ComponentInstance(comp_name, start, final)   # TBD: make CompDef
            end
        end
    end

    md.comp_defs = newcomponents
    return nothing
end

function addcomponent(md::ModelDef, comp_id::ComponentId;
                      start=nothing, final=nothing, before=nothing, after=nothing)
    addcomponent(md, compdef(md, comp_id), start=start, final=final, before=before, after=after)
end