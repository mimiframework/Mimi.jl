#
# TBD: All of these should become methods of either ModelInstance or ModelDef, with delegation function on m::Model in model.jl
#


"""
    update_external_param(m::Model, name::Symbol, value)

Update the value of an external model parameter, referenced by name.
"""
function update_external_param(m::Model, name::Symbol, value)
    if !(name in keys(m.external_params))
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = m.external_params[name]

    if isa(param, ScalarModelParameter)
        if !(typeof(value) <: typeof(param.value))
            try
                value = convert(typeof(param.value), value)
            catch e
                error("Cannot update parameter $name; expected type $(typeof(param.value)) but got $(typeof(value)).")
            end
        elseif size(value) != size(param.value)
            error("Cannot update parameter $name; expected array of size $(size(param.value)) but got array of size $(size(value)).")
        else
            param.value = value
        end

    else # ArrayModelParameter
        if !(typeof(value) <: AbstractArray)
            error("Cannot update an array parameter $name with a scalar value.")
        elseif size(value) != size(param.values)
            error("Cannot update parameter $name; expected array of size $(size(param.values)) but got array of size $(size(value)).")
        elseif !(eltype(value) <: eltype(param.values))
            try
                value = convert(Array{eltype(param.values)}, value)
            catch e
                error("Cannot update parameter $name; expected array of type $(eltype(param.values)) but got $(eltype(value)).")
            end
        else # perform the update
            if isa(param.values, TimestepVector) || isa(param.values, TimestepMatrix)
                param.values.data = value
            else
                param.values = value
            end
        end
    end
    m.mi = Nullable{ModelInstance}()
end

# TBD: revise
# returns the {name:parameter} dictionary
function get_parameters(m::Model, component::ComponentInstance)
    return parameters(component.comp_def)
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getindex(get(m.mi), component, name)
end

"""
    getdatum(m::Model, comp_def::ComponentDef, item::Symbol)

Return a VariableDef or ParameterDef for `item` in the given component.
"""
function getdatum(m::Model, comp_def::ComponentDef, item::Symbol)
    if haskey(comp_def.variables, item)
        return comp_def.variables[item]

    elseif haskey(comp_def.parameters, item)
        return comp_def.parameters[item]
    else
        error("Cannot access data item; $name is not a variable or a parameter in component $component.")
    end
end

getdatum(m::Model, comp_name::Symbol, item::Symbol) = getdatum(compdef(m, comp_name), item)

getdatum(m::Model, comp_id::ComponentId, item::Symbol) = getdatum(m, compdef(comp_id), item)


"""
    indexlabels(m::Model, component::Symbol, name::Symbol)

Return the index labels of the variable or parameter in the given component.
"""
function indexlabels(m::Model, comp_name::Symbol, datum_name::Symbol)
    datum = getdatum(m, comp_name, datum_name)
    return datum.dimensions
end

# Deprecated
#indexlabels(m::Model, comp_id::ComponentId, name::Symbol) = indexlabels(m, compdef(comp_id), name)

# Maybe deprecated; maybe not.
#
# TBD: this seems redundant with, less useful than, and more complicated than indexlabels.
# It also seems to be used only by getdataframe, as is the getdiminfoforvar(), below.
#
# function getvardiminfo(mi::ModelInstance, comp_name::Symbol, var_name::Symbol)
#     if ! haskey(mi.components, comp_name)
#         error("Component $comp_name not found in model")
#     end
#     comp_type = typeof(mi.components[comp_name])

#     meta_module_name    = Symbol(supertype(comp_type).name.module)
#     meta_comp_name = Symbol(supertype(comp_type).name.name)

#     vardiminfo = getdiminfoforvar((meta_module_name,meta_compo_name), var_name)
#     return vardiminfo
# end

# function getdiminfoforvar(s, name)
#     defs = compdefs()
#     defs[s].variables[name].dimensions
# end


# Deprecated
# Helper function for macro: collects all the keyword arguments in a function call to a dictionary.
# function collectkw(args::Vector{Any})
#     kws = Dict{Symbol, Any}()
#     for arg in args
#         if isa(arg, Expr) && arg.head == :kw
#             kws[arg.args[1]] = arg.args[2]
#         end
#     end

#     kws
# end
