#
# N.B. Types have been moved to mimi_types.jl
#

# TBD: test this
"""
    function load_comps(dirname::String="./components")

Call include() on all the files in the indicated directory.
This avoids having modelers create a long list of include()
statements. Just put all the components in a directory.
"""
function load_comps(dirname::String="./components")
    files = readdir(dirname)
    for file in files
        if endswith(file, ".jl")
            pathname = joinpath(dirname, file)
            include(pathname)
        end
    end
end

"""
    components(m::Model)

List all the components in model `m`.
"""
function components(m::Model)
    collect(keys(m.components2))
end

# Return the ComponentDef for a given component
function getmetainfo(m::Model, componentname::Symbol)
    meta = get_compdefs()
    meta_module_name = Symbol(m.components2[componentname].component_type.name.module)
    meta_component_name = m.components2[componentname].component_type.name.name
    return meta[(meta_module_name, meta_component_name)]
end

"""
    variables(m::Model, componentname::Symbol)

List all the variables of `componentname` in model `m`.
"""
function variables(m::Model, componentname::Symbol)
    c = getmetainfo(m, componentname)
    collect(keys(c.variables))
end

"""
    variables(mi::ModelInstance, componentname::Symbol)

List all the variables of `componentname` in the ModelInstance 'mi'.
NOTE: this variables function does NOT take in Nullable instances
"""
function variables(mi::ModelInstance, componentname::Symbol)
    return fieldnames(mi.components[componentname].Variables)
end

# helper function for setindex; used to determine if the provided time values are a uniform range.
function isuniform(values::Vector)
    if length(values) in (1, 2)
        return true
    end

    stepsize = values[2]-values[1]
    for i in 3:length(values)
        if (values[i] - values[i-1]) != stepsize
            return false
        end
    end

    return true
end

"""
    setindex(m::Model, name::Symbol, count::Int)

Set the values of `Model`'s' index `name` to integers 1 through `count`.
"""
function setindex(m::Model, name::Symbol, count::Int)
    m.indices_counts[name] = count
    m.indices_values[name] = collect(1:count)
    m.time_labels = Vector()
    nothing
end

"""
    setindex{T}(m::Model, name::Symbol, values::Vector{T})

Set the values of `Model`'s index `name` to `values`.
"""
function setindex{T}(m::Model, name::Symbol, values::Vector{T})
    m.indices_counts[name] = length(values)
    if name==:time
        if !isuniform(values) # case where time values aren't uniform
            m.time_labels = values
            m.indices_values[name] = collect(1:length(values))
        else # case where time values are uniform
            m.indices_values[name] = copy(values)
            m.time_labels = Vector()
        end
    else
        m.indices_values[name] = copy(values)
    end
    nothing
end

"""
    setindex{T}(m::Model, name::Symbol, valuerange::Range{T})

Set the values of `Model`'s index `name` to the values in the given range `valuerange`.
"""
function setindex{T}(m::Model, name::Symbol, valuerange::Range{T})
    m.indices_counts[name] = length(valuerange)
    m.indices_values[name] = Vector{T}(valuerange)
    m.time_labels = Vector()
    nothing
end

"""
    addcomponent(m::Model, t, name::Symbol=t.name.name; before=nothing,after=nothing)

Add a component of type t to a model.
"""
function addcomponent(m::Model, t, name::Symbol=t.name.name; start=nothing, final=nothing, before=nothing,after=nothing)
    # check that start and final are within the model's time index range
    time_index = m.indices_values[:time]

    if start == nothing
        start = time_index[1]
    elseif start < time_index[1]
        error("Cannot add component ", name, " with start time before start of model's time index range.")
    end

    if final == nothing
        final = time_index[end]
    elseif final > time_index[end]
        error("Cannot add component ", name, " with final time after end of model's time index range.")
    end


    if before!=nothing && after!=nothing
        error("Can only specify before or after parameter")
    end

    #checking if component being added already exists
    for i in keys(m.components2)
        if i==name
            error("You cannot add two components of the same name: ", i)
        end
    end

    if before!=nothing
        newcomponents2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        before_exists = false
        for i in keys(m.components2)
            if i==before
                before_exists = true
                newcomponents2[name] = ComponentInstanceInfo(name, t, start, final)
            end
            newcomponents2[i] = m.components2[i]
        end
        if !before_exists
            error("Component to add before does not exist: ", before)
        end
        m.components2 = newcomponents2

    elseif after!=nothing
        newcomponents2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        after_exists = false
        for i in keys(m.components2)
            newcomponents2[i] = m.components2[i]
            if i==after
                after_exists = true
                newcomponents2[name] = ComponentInstanceInfo(name, t, start, final)
            end
        end
        if !after_exists
            error("Component to add after does not exist: ", after)
        end
        m.components2 = newcomponents2

    else
        m.components2[name] = ComponentInstanceInfo(name, t, start, final)
    end
    m.mi = Nullable{ModelInstance}()
    ComponentReference(m, name)
end

import Base.delete!

"""
    delete!(m::Model, component::Symbol

Delete a component from a model, by name.
"""
function delete!(m::Model, component::Symbol)
    if !(component in keys(m.components2))
        error("Cannot delete '$component' from model; component does not exist.")
    end

    delete!(m.components2, component)

    ipc_filter = x -> x.source_component_name!=component && x.target_component_name!=component
    filter!(ipc_filter, m.internal_parameter_connections)

    epc_filter = x -> x.component_name!=component
    filter!(epc_filter, m.external_parameter_connections)

    m.mi = Nullable{ModelInstance}()
end

"""
    setparameter(m::Model, component::Symbol, name::Symbol, value, dims)

Set the parameter of a component in a model to a given value. Value can by a scalar,
an array, or a NamedAray. Optional argument 'dims' is a list of the dimension names of
the provided data, and will be used to check that they match the model's index labels.
"""
function setparameter(m::Model, component::Symbol, name::Symbol, value, dims=nothing)
    # perform possible dimension and labels checks
    if isa(value, NamedArray)
        dims = dimnames(value)
    end
    if dims!=nothing
        check_parameter_dimensions(m, value, dims, name)
    end
    # now set the parameter
    comp_param_dims = getmetainfo(m, component).parameters[name].dimensions
    if length(comp_param_dims) > 0 # array parameter case
        value = convert(Array{m.numberType}, value) # converts the number type and also if it's a NamedArray it gets converted to Array
        if comp_param_dims[1] == :time
            offset = m.components2[component].offset
            duration = getduration(m.indices_values)
            T = eltype(value)
            if length(comp_param_dims)==1
                values = TimestepVector{T, offset, duration}(value)
            elseif length(comp_param_dims)==2
                values = TimestepMatrix{T, offset, duration}(value)
            else
                values = value
            end
        else
            values = value
        end
        set_external_array_parameter(m, name, values, dims)
    else # scalar parameter case
        set_external_scalar_parameter(m, name, value)
    end

    connectparameter(m, component, name, name)
    m.mi = Nullable{ModelInstance}()
    nothing
end

function check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol)
    for dim in dims
        if dim in keys(m.indices_values)
            if isa(value, NamedArray)
                labels = names(value, findnext(dims, dim, 1))
                for i in collect(1:1:length(labels))
                    if !(labels[i] == m.indices_values[dim][i])
                        error(string("Parameter labels for ", dim, " dimension in ", name," parameter do not match model's indices values"))
                    end
                end
            end
        else
            error(string("Dimension ", dim, " in parameter ", name, " not found in model's dimensions"))
        end
    end
end

"""
Removes any parameter connections for a given parameter in a given component.
"""
function disconnect(m::Model, component::Symbol, parameter::Symbol)
    filter!(x->!(x.target_component_name==component && x.target_parameter_name==parameter), m.internal_parameter_connections)
    filter!(x->!(x.component_name==component && x.param_name==parameter), m.external_parameter_connections)
end

"""
    connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)

Connect a parameter in a component to an external parameter.
"""
function connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)
    p = m.external_parameters[parametername]

    if isa(p, ArrayModelParameter)
        checklabels(m, component, name, p)
    end

    disconnect(m, component, name)

    x = ExternalParameterConnection(component, name, parametername)
    push!(m.external_parameter_connections, x)

    nothing
end

function checklabels(m::Model, component::Symbol, name::Symbol, p::ArrayModelParameter)
    metacomp = getmetainfo(m, component)
    if !(eltype(p.values) <: metacomp.parameters[name].datatype)
        error(string("Mismatched datatype of parameter connection. Component: ", component, ", Parameter: ", name))
    elseif !(isempty(p.dims))
        if !(size(p.dims) == size(metacomp.parameters[name].dimensions))
            error(string("Mismatched dimensions of parameter connection. Component: ", component, ", Parameter: ", name))
        end
    end

    # Return early if it's a ConnectorComp so that we don't check the sizes, because they will not match.
    if metacomp.component_name in (:ConnectorCompVector, :ConnectorCompMatrix)
        return nothing
    end

    comp_dims = metacomp.parameters[name].dimensions
    for (i, dim) in enumerate(comp_dims)
        if isa(dim, Symbol)
            if !(length(m.indices_values[dim])==size(p.values)[i])
                error(string("Mismatched data size for a parameter connection. Component: ", component, ", Parameter: ", name))
            end
        end
    end
end

"""
    set_external_array_parameter(m::Model, name::Symbol, value::TimestepVector, dims)

Adds a one dimensional time-indexed array parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::TimestepVector, dims)
    p = ArrayModelParameter(value, [:time])
    m.external_parameters[name] = p
end

"""
    set_external_array_parameter(m::Model, name::Symbol, value::TimestepMatrix, dims)

Adds a two dimensional time-indexed array parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::TimestepMatrix, dims)
    p = ArrayModelParameter(value, (dims!=nothing)?(dims):(Vector{Symbol}()))
    m.external_parameters[name] = p
end

"""
    set_external_array_parameter(m::Model, name::Symbol, value::AbstractArray, dims)

Add an array type parameter to the model.
"""
function set_external_array_parameter(m::Model, name::Symbol, value::AbstractArray, dims)
    if !(typeof(value) <: Array{m.numberType})
        # Need to force a conversion (simple convert may alias in v0.6)
        value = Array{m.numberType}(value)
    end
    p = ArrayModelParameter(value, (dims!=nothing)?(dims):(Vector{Symbol}()))
    m.external_parameters[name] = p
end

"""
    set_external_scalar_parameter(m::Model, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_scalar_parameter(m::Model, name::Symbol, value::Any)
    if typeof(value) <: AbstractArray
        value = convert(Array{m.numberType}, value)
    end
    p = ScalarModelParameter(value)
    m.external_parameters[name] = p
end

"""
    connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connectparameter(m::Model, target_component::Symbol, target_param::Symbol, source_component::Symbol, source_var::Symbol; ignoreunits::Bool=false)

    # Check the units, if provided
    if !ignoreunits &&
        !unitcheck(getmetainfo(m, target_component).parameters[target_param].unit,
                   getmetainfo(m, source_component).variables[source_var].unit)
        error("Units of $source_component.$source_var do not match $target_component.$target_param.")
    end

    # remove any existing connections for this target component and parameter
    disconnect(m, target_component, target_param)

    curr = InternalParameterConnection(source_var, source_component, target_param, target_component, ignoreunits)
    push!(m.internal_parameter_connections, curr)

    nothing
end

"""
    connectparameter(m::Model, target::Pair{Symbol, Symbol}, source::Pair{Symbol, Symbol}; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connectparameter(m::Model, target::Pair{Symbol, Symbol}, source::Pair{Symbol, Symbol}; ignoreunits::Bool=false)
    connectparameter(m, target[1], target[2], source[1], source[2]; ignoreunits=ignoreunits)
end

function connectparameter(m::Model, target::Pair{Symbol, Symbol}, source::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)
    connectparameter(m, target[1], target[2], source[1], source[2], backup; ignoreunits=ignoreunits)
end

function connectparameter(m::Model, target_component::Symbol, target_param::Symbol, source_component::Symbol, source_var::Symbol, backup::Array; ignoreunits::Bool=false)
    # If value is a NamedArray, we can check if the labels match
    if isa(backup, NamedArray)
        dims = dimnames(backup)
        check_parameter_dimensions(m, backup, dims, name)
    else
        dims = nothing
    end

    # Check that the backup value is the right size
    if getspan(m, target_component) != size(backup)[1]
        error("Backup data must span the whole length of the component.")
    end

    # some other check for second dimension??

    comp_param_dims = getmetainfo(m, target_component).parameters[target_param].dimensions
    backup = convert(Array{m.numberType}, backup) # converts the number type, and also if it's a NamedArray it gets converted to Array
    offset = m.components2[target_component].offset
    duration = getduration(m.indices_values)
    T = eltype(backup)
    if length(comp_param_dims)==1
        values = TimestepVector{T, offset, duration}(backup)
    elseif length(comp_param_dims)==2
        values = TimestepMatrix{T, offset, duration}(backup)
    else
        values = backup
    end
    set_external_array_parameter(m, target_param, values, dims)

    if !ignoreunits &&
        !unitcheck(getmetainfo(m, target_component).parameters[target_param].unit,
                   getmetainfo(m, source_component).variables[source_var].unit)
        error("Units of $source_component.$source_name do not match $target_component.$target_name.")
    end

    # remove any existing connections for this target component and parameter
    disconnect(m, target_component, target_param)

    curr = InternalParameterConnection(source_var, source_component, target_param, target_component, ignoreunits, target_param)
    push!(m.internal_parameter_connections, curr)

    nothing
end

# Default string, string unit check function
function unitcheck(one::AbstractString, two::AbstractString)
    # True if and only if they match
    return one == two
end

# Return the number of timesteps a given component in a model will run for.
function getspan(m::Model, comp::Symbol)
    duration = getduration(m.indices_values)
    start = m.components2[comp].offset
    final = m.components2[comp].final
    return Int((final - start) / duration + 1)
end

"""
    update_external_parameter(m::Model, name::Symbol, value)

Update the value of an external model parameter, referenced by name.
"""
function update_external_parameter(m::Model, name::Symbol, value)
    if !(name in keys(m.external_parameters))
        error("Cannot update parameter; $name not found in model's external parameters.")
    end

    param = m.external_parameters[name]

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

"""
    set_leftover_parameters(m::Model, parameters::Dict{Any,Any})

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary. This method assumes the dictionary
keys are strings that match the names of unset parameters in the model.
"""
function set_leftover_parameters(m::Model, parameters::Dict{String,Any})
    parameters = Dict(lowercase(k)=>v for (k, v) in parameters)
    leftovers = get_unconnected_parameters(m)
    for (comp, p) in leftovers
        if !(p in keys(m.external_parameters)) # then we need to set the external parameter
            value = parameters[lowercase(string(p))]
            comp_param_dims = getmetainfo(m, comp).parameters[p].dimensions
            if length(comp_param_dims)==0 #scalar case
                set_external_scalar_parameter(m, p, value)
            else #array case
                value = convert(Array{m.numberType}, value)
                offset = m.indices_values[:time][1]
                duration = getduration(m.indices_values)
                T = eltype(value)
                if length(comp_param_dims)==1 && comp_param_dims[1]==:time
                    values = TimestepVector{T, offset, duration}(value)
                elseif length(comp_param_dims)==2 && comp_param_dims[1]==:time
                    values = TimestepMatrix{T, offset, duration}(value)
                else
                    values = value
                end
                set_external_array_parameter(m, p, values, nothing)
            end
        end
        connectparameter(m, comp, p, p)
    end
    nothing
end

"""
Return list of parameters that have been set for component c in model m.
"""
function get_set_parameters(m::Model, c::ComponentInstanceInfo)
    ext_connections = Iterators.filter(x->x.component_name==c.name, m.external_parameter_connections)
    ext_set_params = map(x->x.param_name, ext_connections)

    int_connections = Iterators.filter(x->x.target_component_name==c.name, m.internal_parameter_connections)
    int_set_params = map(x->x.target_parameter_name, int_connections)

    return union(ext_set_params, int_set_params)
end

"""
Return a list of all parameter names for a given component in a model m.
"""
function get_parameter_names(m::Model, component::ComponentInstanceInfo)
    _dict = get_compdefs()
    _module = module_name(component.component_type.name.module)
    _metacomponent = _dict[(_module, component.component_type.name.name)]
    return keys(_metacomponent.parameters)
end

# returns the {name:parameter} dictionary
function get_parameters(m::Model, component::ComponentInstanceInfo)
    _dict = get_compdefs()
    _module = module_name(component.component_type.name.module)
    _metacomponent = _dict[(_module, component.component_type.name.name)]
    return _metacomponent.parameters
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getindex(get(m.mi), component, name)
end

function getindex(mi::ModelInstance, component::Symbol, name::Symbol)
    if !(component in keys(mi.components))
        error("Component does not exist in current model")
    end
    if name in fieldnames(mi.components[component].Variables)
        v = getfield(mi.components[component].Variables, name)
        if isa(v, PklVector) || isa(v, TimestepMatrix)
            return v.data
        else
            return v
        end
    elseif name in fieldnames(mi.components[component].Parameters)
        p = getfield(mi.components[component].Parameters, name)
        if isa(p, TimestepVector) || isa(p, TimestepMatrix)
            return p.data
        else
            return p
        end
    else
        error(string(name, " is not a parameter or a variable in component ", component, "."))
    end
end

"""
    getindexcount(m::Model, i::Symbol)

Returns the size of index i in model m.
"""
function getindexcount(m::Model, i::Symbol)
    return m.indices_counts[i]
end

"""
    getindexvalues(m::Model, i::Symbol)

Return the values of index i in model m.
"""
function getindexvalues(m::Model, i::Symbol)
    return m.indices_values[i]
end

"""
    getindexlabels(m::Model, component::Symbol, x::Symbol)

Return the index labels of the variable or parameter in the given component.
"""
function getindexlabels(m::Model, component::Symbol, x::Symbol)
    metacomp = getmetainfo(m,component)
    if x in keys(metacomp.variables)
        return metacomp.variables[x].dimensions
    elseif x in keys(metacomp.parameters)
        return metacomp.parameters[x].dimensions
    else
        error(string("Cannot access dimensions; ", x, " is not a variable or a parameter in component ", component, "."))
    end
end


function getvardiminfo(mi::ModelInstance, componentname::Symbol, name::Symbol)
    if !(componentname in keys(mi.components))
        error("Component not found model components")
    end
    comp_type = typeof(mi.components[componentname])

    meta_module_name = Symbol(supertype(comp_type).name.module)
    meta_component_name = Symbol(supertype(comp_type).name.name)

    vardiminfo = getdiminfoforvar((meta_module_name,meta_component_name), name)
    return vardiminfo
end


"""
    get_unconnected_parameters(m::Model)

Return a list of tuples (componentname, parametername) of parameters
that have not been connected to a value in the model.
"""
function get_unconnected_parameters(m::Model)
    unset_params = Array{Tuple{Symbol,Symbol}, 1}()
    for (name, c) in m.components2
        params = get_parameter_names(m, c)
        set_params = get_set_parameters(m, c)
        append!(unset_params, map(x->(name, x), setdiff(params, set_params)))
    end
    return unset_params
end

#
# N.B. build() moved to modelinstance/build.jl
#

function getduration(indices_values)
    if length(indices_values[:time])>1
        return indices_values[:time][2]-indices_values[:time][1] #assumes that all timesteps of the model are the same length
    else
        return 1
    end
end

"""
    run(m::Model)

Run model `m` once.
"""
function run(m::Model; ntimesteps=typemax(Int))
    if length(m.components2) == 0
        error("Cannot run a model with no components.")
    end

    if isnull(m.mi)
        m.mi = Nullable{ModelInstance}(build(m))
    end
    run(get(m.mi), ntimesteps, m.indices_values)
end

#
# N.B. run moved to modelinstance/run.jl
#

function update_scalar_parameters(mi::ModelInstance, c::Symbol)
    for x in get_connections(mi, c, :incoming)
        c_target = mi.components[x.target_component_name]
        c_source = mi.components[x.source_component_name]
        setfield!(c_target.Parameters, x.target_parameter_name, getfield(c_source.Variables, x.source_variable_name))
    end
end


# function update_scalar_parameters(mi::ModelInstance)
#     #this function is bad!! doesn't necessarilly update scalars in the correct order
#     for x in mi.internal_parameter_connections
#         c_target = mi.components[x.target_component_name]
#         c_source = mi.components[x.source_component_name]
#         setfield!(c_target.Parameters, x.target_parameter_name, getfield(c_source.Variables, x.source_variable_name))
#     end
# end

# function run_timestep(s, t)
#     typeofs = typeof(s)
#     println("Generic run_timestep called for $typeofs.")
# end

function init(s)
end

function resetvariables(s)
    typeofs = typeof(s)
    println("Generic resetvariables called for $typeofs.")
end

function getdiminfoforvar(s, name)
    meta = get_compdefs()
    meta[s].variables[name].dimensions
end

function getvpd(s)
    return s.Variables, s.Parameters, s.Dimensions
end

# Helper function for macro: collects all the keyword arguments in a function call to a dictionary.
function collectkw(args::Vector{Any})
    kws = Dict{Symbol, Any}()
    for arg in args
        if isa(arg, Expr) && arg.head == :kw
            kws[arg.args[1]] = arg.args[2]
        end
    end

    kws
end


# N.B. graphing support moved to utils/graph.jl
