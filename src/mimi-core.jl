abstract ComponentState

type ComponentInstanceInfo
    name::Symbol
    component_type::DataType
    offset::Int
    final::Int
end

abstract Parameter

type ScalarModelParameter <: Parameter
    dependentCompsAndParams2::Set{Tuple{Symbol, Symbol}}
    value

    function ScalarModelParameter(value)
        p = new()
        p.dependentCompsAndParams2 = Set{Tuple{Symbol,Symbol}}()
        p.value = value
        return p
    end
end

type InternalParameterConnection
    source_variable_name::Symbol
    source_component_name::Symbol
    target_parameter_name::Symbol
    target_component_name::Symbol
    ignoreunits::Bool
end

type ExternalParameterConnection
    component_name::Symbol
    param_name::Symbol #name of the parameter in the component
    external_parameter::Parameter
end

type ModelInstance
    components::OrderedDict{Symbol, ComponentState}
    internal_parameter_connections::Array{InternalParameterConnection, 1}
    offsets::Array{Int, 1} # in order corresponding with components
    final_times::Array{Int, 1}
end

type ArrayModelParameter <: Parameter
    values::AbstractArray
    dims::Vector{Symbol} #if empty, we don't have the dimensions' name information

    function ArrayModelParameter(values::AbstractArray, dims::Vector{Symbol})
        amp = new()
        amp.values = values
        amp.dims = dims
        return amp
    end
end

type Model
    indices_counts::Dict{Symbol,Int}
    indices_values::Dict{Symbol,Vector{Any}}
    external_parameters::Dict{Symbol,Parameter}
    numberType::DataType
    internal_parameter_connections::Array{InternalParameterConnection, 1}
    external_parameter_connections::Array{ExternalParameterConnection, 1}
    components2::OrderedDict{Symbol, ComponentInstanceInfo}
    mi::Nullable{ModelInstance}

    function Model(numberType::DataType=Float64)
        m = new()
        m.indices_counts = Dict{Symbol,Int}()
        m.indices_values = Dict{Symbol, Vector{Any}}()
        m.external_parameters = Dict{Symbol, Parameter}()
        m.numberType = numberType
        m.internal_parameter_connections = Array{InternalParameterConnection,1}()
        m.external_parameter_connections = Array{ExternalParameterConnection, 1}()
        m.components2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        m.mi = Nullable{ModelInstance}()
        return m
    end
end

"""
    components(m::Model)

List all the components in model `m`.
"""
function components(m::Model)
    collect(keys(m.components2))
end

# Return the MetaComponent for a given component
function getmetainfo(m::Model, componentname::Symbol)
    meta = metainfo.getallcomps()
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

"""
    setindex(m::Model, name::Symbol, count::Int)

Set the values of `Model`'s' index `name` to integers 1 through `count`.
"""
function setindex(m::Model, name::Symbol, count::Int)
    m.indices_counts[name] = count
    m.indices_values[name] = collect(1:count)
    nothing
end

"""
    setindex{T}(m::Model, name::Symbol, values::Vector{T})

Set the values of `Model`'s index `name` to `values`.
"""
function setindex{T}(m::Model, name::Symbol, values::Vector{T})
    m.indices_counts[name] = length(values)
    m.indices_values[name] = copy(values)
    nothing
end

"""
    setindex{T}(m::Model, name::Symbol, valuerange::Range{T})

Set the values of `Model`'s index `name` to the values in the given range `valuerange`.
"""
function setindex{T}(m::Model, name::Symbol, valuerange::Range{T})
    m.indices_counts[name] = length(valuerange)
    m.indices_values[name] = Vector{T}(valuerange)
    nothing
end

"""
    addcomponent(m::Model, t, name::Symbol=t.name.name; before=nothing,after=nothing)

Add a component of type t to a model.
"""
function addcomponent(m::Model, t, name::Symbol=t.name.name; start=nothing, final=nothing, before=nothing,after=nothing)
    if before!=nothing && after!=nothing
        error("Can only specify before or after parameter")
    end

    #checking if component being added already exists
    for i in keys(m.components2)
        if i==name
            error("You cannot add two components of the same name: ", i)
        end
    end

    if start == nothing
        start = m.indices_values[:time][1]
    end

    if final == nothing
        final = m.indices_values[:time][end]
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
    delete!(m::Model, component::Symbol)

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
    setparameter(m::Model, component::Symbol, name::Symbol, value)

Set the parameter of a component in a model to a given value.
"""
function setparameter(m::Model, component::Symbol, name::Symbol, value)
    set_external_parameter(m, name, value)
    connectparameter(m, component, name, name)
    m.mi = Nullable{ModelInstance}()
    nothing
end

function checklabels(m::Model, component::Symbol, name::Symbol, parametername::Symbol, p::ArrayModelParameter)
    if !(eltype(p.values) <: getmetainfo(m, component).parameters[parametername].datatype)
        error(string("Mismatched datatype of parameter connection. Component: ", component, ", Parameter: ", parametername))
    elseif !(size(p.dims) == size(getmetainfo(m, component).parameters[parametername].dimensions))
        if isa(p.values, NamedArray)
            error(string("Mismatched dimensions of parameter connection. Component: ", component, ", Parameter: ", parametername))
        end
    else
        comp_dims = getmetainfo(m, component).parameters[parametername].dimensions
        i=1
        for dim in comp_dims
            if !(length(m.indices_values[dim])==size(p.values)[i])
                error("Length of the labels and the provided data are not matching")
            end
            i+=1
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
    p = m.external_parameters[Symbol(lowercase(string(parametername)))]

    if isa(p, ArrayModelParameter)
        checklabels(m, component, name, parametername, p)
    end

    disconnect(m, component, name)

    x = ExternalParameterConnection(component, name, p)
    push!(m.external_parameter_connections, x)

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
    set_external_parameter(m::Model, name::Symbol, value::NamedArray)

Add an array type parameter to the model, perferm dimension checking on the given NamedArray.
"""
function set_external_parameter(m::Model, name::Symbol, value::NamedArray)
    #namedarray given, so we can perform label checks
    dims = dimnames(value)

    check_parameter_dimensions(m, value, dims, name)

    p = ArrayModelParameter(value.array, dims) #want to use convert(Array, value) but broken
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
    set_external_parameter(m::Model, name::Symbol, value::AbstractArray)

Add an array type parameter to the model.
"""
function set_external_parameter(m::Model, name::Symbol, value::AbstractArray)
    #cannot perform any parameter label checks in this case

    if !(typeof(value) <: Array{m.numberType})
        # E.g., if model takes Number and given Float64, convert it
        value = convert(Array{m.numberType}, value)
    end
    dims = Vector{Symbol}()
    p = ArrayModelParameter(value, dims)
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
    set_external_parameter(m::Model, name::Symbol, value::AbstractArray, dims::Vector{Symbol})

Takes as input a regular array and a vector of dimension symbol names. Performs dimension name checks. Adds array type parameter to the model.
"""
function set_external_parameter(m::Model, name::Symbol, value::AbstractArray, dims::Vector{Symbol})
    #instead of a NamedArray, user can pass in the names of the dimensions in the dims vector

    check_parameter_dimensions(m, value, dims, name) #best we can do is check that the dim names match

    p = ArrayModelParameter(value, dims)
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
    set_external_parameter(m::Model, name::Symbol, value::Any)

Add a scalar type parameter to the model.
"""
function set_external_parameter(m::Model, name::Symbol, value::Any)
    #function for adding scalar parameters ("Any" type)
    p = ScalarModelParameter(value)
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
    connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)

    # Check the units, if provided
    if !ignoreunits &&
        !unitcheck(getmetainfo(m, target_component).parameters[target_name].unit,
                   getmetainfo(m, source_component).variables[source_name].unit)
        error("Units of $source_component.$source_name do not match $target_component.$target_name.")
    end

    # remove any existing connections for this target component and parameter
    disconnect(m, target_component, target_name)

    curr = InternalParameterConnection(source_name, source_component, target_name, target_component, ignoreunits)
    push!(m.internal_parameter_connections, curr)

    nothing
end

# Default string, string unit check function
function unitcheck(one::AbstractString, two::AbstractString)
    # True if and only if they match
    return one == two
end


"""
    setleftoverparameters(m::Model, parameters::Dict{Any,Any})

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary.
"""
function setleftoverparameters(m::Model, parameters::Dict{Any,Any})
    for (name, value) in parameters
        set_external_parameter(m, Symbol(name), value)
    end

    for c in values(m.components2)
        params = get_parameters(m, c)
        set_params = get_set_parameters(m, c)
        for p in params
            if !in(p, set_params)
                connectparameter(m, c.name, p, p)
            end
        end
    end

    nothing
end

""" helper function for setleftoverparameters"""
function get_set_parameters(m::Model, c::ComponentInstanceInfo)
    ext_connections = filter(x->x.component_name==c.name, m.external_parameter_connections)
    ext_set_params = map(x->x.param_name, ext_connections)

    int_connections = filter(x->x.target_component_name==c.name, m.internal_parameter_connections)
    int_set_params = map(x->x.target_parameter_name, int_connections)

    return union(ext_set_params, int_set_params)
end

""" helper function for setleftoverparameters"""
function get_parameters(m::Model, component::ComponentInstanceInfo)
    _dict = Mimi.metainfo.getallcomps()
    _module = module_name(component.component_type.name.module)
    _metacomponent = _dict[(_module, component.component_type.name.name)]
    return keys(_metacomponent.parameters)
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getindex(get(m.mi), component, name)
end

function getindex(mi::ModelInstance, component::Symbol, name::Symbol)
    if !(component in keys(mi.components))
        error("Component does not exist in current model")
    end
    if name in fieldnames(mi.components[component].Variables)
        return getfield(mi.components[component].Variables, name)
    elseif name in fieldnames(mi.components[component].Parameters)
        return getfield(mi.components[component].Parameters, name)
    else
        error(string(name, " is not a paramter or a variable in component ", component, "."))
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

"""
    getdataframe(m::Model, componentname::Symbol, name::Symbol)

Return the values for variable `name` in `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, componentname::Symbol, name::Symbol)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    elseif !(name in variables(m, componentname))
        error("Cannot get dataframe; variable not in provided component")
    else
        return getdataframe(m, get(m.mi), componentname, name)
    end
end


function getdataframe(m::Model, mi::ModelInstance, componentname::Symbol, name::Symbol)
    comp_type = typeof(mi.components[componentname])

    meta_module_name = Symbol(supertype(comp_type).name.module)
    meta_component_name = Symbol(supertype(comp_type).name.name)

    vardiminfo = getdiminfoforvar((meta_module_name,meta_component_name), name)
    if length(vardiminfo)==0
        return mi[componentname, name]
    elseif length(vardiminfo)==1
        df = DataFrame()
        df[vardiminfo[1]] = m.indices_values[vardiminfo[1]]
        df[name] = mi[componentname, name]
        return df
    elseif length(vardiminfo)==2
        df = DataFrame()
        dim1 = length(m.indices_values[vardiminfo[1]])
        dim2 = length(m.indices_values[vardiminfo[2]])
        df[vardiminfo[1]] = repeat(m.indices_values[vardiminfo[1]],inner=[dim2])
        df[vardiminfo[2]] = repeat(m.indices_values[vardiminfo[2]],outer=[dim1])
        data = m[componentname, name]
        df[name] = cat(1,[vec(data[i,:]) for i=1:dim1]...)
        return df
    else
        error("Not yet implemented")
    end
end

"""
    getdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => name::Symbol)...)
    getdataframe(m::Model, comp_name_pairs::Pair(componentname::Symbol => (name::Symbol, name::Symbol...)...)

Return the values for each variable `name` in each corresponding `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, comp_name_pairs::Pair...)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    else
        return getdataframe(m, get(m.mi), comp_name_pairs)
    end
end


function getdataframe(m::Model, mi::ModelInstance, comp_name_pairs::Tuple)
    #Make sure tuple passed in is not empty
    if length(comp_name_pairs) == 0
        error("Cannot get data frame, did not specify any componentname(s) and variable(s)")
    end

    #Get the base value of the number of dimensions from the first
    # componentname and name pair association
    firstpair = comp_name_pairs[1]
    componentname = firstpair[1]
    name = firstpair[2]
    if isa(name, Tuple)
        name = name[1]
    end

    if !(name in variables(m, componentname))
        error("Cannot get dataframe; variable not in provided component")
    end

    vardiminfo = getvardiminfo(mi, componentname, name)
    num_dim = length(vardiminfo)

    #Initialize dataframe depending on num dimensions
    df = DataFrame()
    if num_dim == 1
        df[vardiminfo[1]] = m.indices_values[vardiminfo[1]]
    elseif num_dim == 2
        dim1 = length(m.indices_values[vardiminfo[1]])
        dim2 = length(m.indices_values[vardiminfo[2]])
        df[vardiminfo[1]] = repeat(m.indices_values[vardiminfo[1]],inner=[dim2])
        df[vardiminfo[2]] = repeat(m.indices_values[vardiminfo[2]],outer=[dim1])
    end

    #Iterate through all the pairs; always check for each variable
    # that the number of dimensions matcht that of the first
    for pair in comp_name_pairs
        componentname = pair[1]
        name = pair[2]

        if isa(name, Tuple)
            for comp_var in name
                if !(comp_var in variables(m, componentname))
                    error(string("Cannot get dataframe; variable, ", comp_var,  " not in provided component ", componentname))
                end

                vardiminfo = getvardiminfo(mi, componentname, comp_var)

                if !(length(vardiminfo) == num_dim)
                    error(string("Not all components have the same number of dimensions"))
                end

                if (num_dim==1)
                    df[comp_var] = mi[componentname, comp_var]
                elseif (num_dim == 2)
                    data = m[componentname, comp_var]
                    df[comp_var] = cat(1,[vec(data[i,:]) for i=1:dim1]...)
                end
            end

        elseif (isa(name, Symbol))
            if !(name in variables(m, componentname))
                error(string("Cannot get dataframe; variable, ", name,  " not in provided component ", componentname))
            end

            vardiminfo = getvardiminfo(mi, componentname, name)

            if !(length(vardiminfo) == num_dim)
                error(string("Not all components have the same number of dimensions"))
            end
            if (num_dim==1)
                df[name] = mi[componentname, name]
            elseif (num_dim == 2)
                data = m[componentname, name]
                df[name] = cat(1,[vec(data[i,:]) for i=1:dim1]...)
            end
        else
            error(string("Name value for variable(s) in a component, ", componentname, " was neither a tuple nor a Symbol."))
        end
    end

    return df
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

import Base.show
show(io::IO, a::ComponentState) = print(io, "ComponentState")

"""
    get_unconnected_parameters(m::Model)

Return a list of tuples (componentname, parametername) of parameters
that have not been connected to a value in the model.
"""
function get_unconnected_parameters(m::Model)
    unset_params = Array{Tuple{Symbol,Symbol}, 1}()
    for (name, c) in m.components2
        params = get_parameters(m, c)
        set_params = get_set_parameters(m, c)
        append!(unset_params, map(x->(name, x), setdiff(params, set_params)))
    end
    return unset_params
end

function makeclock(mi::ModelInstance, ntimesteps, indices_counts)
    # later will involve finding first offset in all components
    return Clock(1, min(indices_counts[:time],ntimesteps))
end

function build(m::Model)
    #check if all parameters are set
    unset = get_unconnected_parameters(m)
    if !isempty(unset)
        msg = "Cannot build model; the following parameters are unset: "
        for p in unset
            msg = string(msg, p, " ")
        end
        error(msg)
    end
    #instantiate the components
    builtComponents = OrderedDict{Symbol, ComponentState}()
    offsets = Array{Int, 1}()
    final_times = Array{Int, 1}()
    for c in values(m.components2)
        t = c.component_type
        comp = t(m.numberType, m.indices_counts)

        builtComponents[c.name] = comp

        push!(offsets, c.offset)
        push!(final_times, c.final)
    end

    #make the parameter connections
    for x in m.internal_parameter_connections
        c_target = builtComponents[x.target_component_name]
        c_source = builtComponents[x.source_component_name]
        setfield!(c_target.Parameters, x.target_parameter_name, getfield(c_source.Variables, x.source_variable_name))
    end

    for x in m.external_parameter_connections
        param = x.external_parameter
        if isa(param, ScalarModelParameter)
            setfield!(builtComponents[x.component_name].Parameters, x.param_name, param.value)
        else
            setfield!(builtComponents[x.component_name].Parameters, x.param_name, param.values)
        end
    end


    mi = ModelInstance(builtComponents, m.internal_parameter_connections, offsets, final_times)

    return mi
end

"""
    run(m::Model)

Run model `m` once.
"""
function run(m::Model;ntimesteps=typemax(Int))
    if isnull(m.mi)
        m.mi = Nullable{ModelInstance}(build(m))
    end
    run(get(m.mi), ntimesteps, m.indices_counts)
end

function run(mi::ModelInstance, ntimesteps, indices_counts)
    if length(mi.components) == 0
        error("You are trying to run a model with no components")
    end

    for (name,c) in mi.components
        resetvariables(c)
        update_scalar_parameters(mi, name)
        init(c)
    end

    components = [x for x in mi.components]
    newstyle = Array{Bool, 1}(length(components))
    offsets = mi.offsets
    final_times = mi.final_times

    for i in collect(1:length(components))
        c = components[i][2]
        newstyle[i] = method_exists(run_timestep, (typeof(c), Timestep))
    end

    clock = makeclock(mi, ntimesteps, indices_counts)

    while !finished(clock)
        for i in collect(1:length(components))
            name = components[i][1]
            c = components[i][2]
            if gettimeindex(clock) <= final_times[i] - offsets[i] + 1
                update_scalar_parameters(mi, name)
                if newstyle[i]
                    run_timestep(c, getnewtimestep(clock.ts, offsets[i])) #need to convert to component specific timestep?
                else
                    run_timestep(c, gettimeindex(clock)) #int version (old way)
                end
            end
        end
        move_forward(clock)
    end
end

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
    meta = metainfo.getallcomps()
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

"""
    @defcomp name begin

Define a new component.
"""
macro defcomp(name, ex)
    resetvarsdef = Expr(:block)

    metavardef = Expr(:block)
    metapardef = Expr(:block)
    metadimdef = Expr(:block)

    for line in ex.args
        if line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Index
            dimensionName = line.args[1]

            push!(metadimdef.args, :(metainfo.adddimension(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(dimensionName)) )))
        elseif line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Parameter
            if isa(line.args[1], Symbol)
                parameterName = line.args[1]
                parameterType = :Number
            elseif line.args[1].head==:(::)
                parameterName = line.args[1].args[1]
                parameterType = line.args[1].args[2]
            else
                error()
            end

            kws = collectkw(line.args[2].args)

            # Get description and unit, if provided
            description = get(kws, :description, "")
            unit = get(kws, :unit, "")

            if haskey(kws, :index)
                parameterIndex = kws[:index].args

                pardims = Array(Any, 0)
                for l in parameterIndex
                    push!(pardims, l)
                end

                push!(metapardef.args, :(metainfo.set_external_parameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), $(pardims), $(description), $(unit))))
            else
                push!(metapardef.args, :(metainfo.set_external_parameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), [], $(description), $(unit))))
            end
        elseif line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Variable
            if isa(line.args[1], Symbol)
                variableName = line.args[1]
                variableType = :Number
            elseif line.args[1].head==:(::)
                variableName = line.args[1].args[1]
                variableType = line.args[1].args[2]
            else
                error()
            end

            kws = collectkw(line.args[2].args)

            # Get description and unit, if provided
            description = get(kws, :description, "")
            unit = get(kws, :unit, "")

            if haskey(kws, :index)
                variableIndex = kws[:index].args

                vardims = Array(Any, 0)
                for l in variableIndex
                    push!(vardims, l)
                end

                push!(metavardef.args, :(metainfo.addvariable(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), $(vardims), $(description), $(unit))))

                if variableType==:Number
                    push!(resetvarsdef.args,:($(esc(Symbol("fill!")))(s.Variables.$(variableName),$(esc(Symbol("NaN"))))))
                end
            else
                push!(metavardef.args, :(metainfo.addvariable(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), [], $(description), $(unit))))

                if variableType==:Number
                    push!(resetvarsdef.args,:(s.Variables.$(variableName) = $(esc(Symbol("NaN")))))
                end
            end
        elseif line.head==:line
        else
            error("Unknown expression.")
        end
    end

    module_def = :(eval(current_module(), :(module temporary_name end)))
    module_def.args[3].args[1].args[2] = Symbol(string("_mimi_implementation_", name))

    call_expr = Expr(:call,
        Expr(:curly,
            Expr(:., Expr(:., Expr(:., :Main, QuoteNode(Symbol(current_module()))), QuoteNode(Symbol(string("_mimi_implementation_", name)))), QuoteNode(Symbol(string(name,"Impl")))) ,
            :T),
        :T,
        :indices
        )

    x = quote

        abstract $(esc(Symbol(name))) <: Mimi.ComponentState

        import Mimi.run_timestep
        import Mimi.init
        import Mimi.resetvariables

        function $(esc(Symbol("resetvariables")))(s::$(esc(Symbol(name))))
            $(resetvarsdef)
        end

        metainfo.addcomponent(module_name(current_module()), $(Expr(:quote,name)))
        $(metavardef)
        $(metapardef)
        $(metadimdef)

        $(module_def)

        eval($(esc(Symbol(string("_mimi_implementation_", name)))), metainfo.generate_comp_expressions(module_name(current_module()), $(Expr(:quote,name))))

        function $(esc(Symbol(name))){T}(::Type{T}, indices)
            $(call_expr)
        end

    end

    x
end

#Begin Graph Functionality section

function show(io::IO, m::Model)
    println(io, "showing model component connections:")
    for item in enumerate(keys(m.components2))
        c = item[2]
        i_connections = get_connections(m,c,:incoming)
        o_connections = get_connections(m,c,:outgoing)
        println(io, item[1], ". ", c, " component")
        println(io, "    incoming parameters:")
        if length(i_connections)==0
            println(io, "      none")
        else
            [println(io, "      - ",e.target_parameter_name," from ",e.source_component_name," component") for e in i_connections]
        end
        println(io, "    outgoing variables:")
        if length(o_connections)==0
            println(io, "      none")
        else
            [println(io, "      - ",e.source_variable_name," in ",e.target_component_name, " component") for e in o_connections]
        end
    end
end

function get_connections(m::Model, c::ComponentInstanceInfo, which::Symbol)
    return get_connections(m, c.name, which)
end

function get_connections(m::Model, component_name::Symbol, which::Symbol)
    if which==:all
        f = e -> e.source_component_name==component_name || e.target_component_name==component_name
    elseif which==:incoming
        f = e -> e.target_component_name==component_name
    elseif which==:outgoing
        f = e -> e.source_component_name==component_name
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end
    return filter(f, m.internal_parameter_connections)
end

function get_connections(mi::ModelInstance, component_name::Symbol, which::Symbol)
    if which==:all
        f = e -> e.source_component_name==component_name || e.target_component_name==component_name
    elseif which==:incoming
        f = e -> e.target_component_name==component_name
    elseif which==:outgoing
        f = e -> e.source_component_name==component_name
    else
        error("Invalid parameter for the 'which' argument; must be 'all' or 'incoming' or 'outgoing'.")
    end
    return filter(f, mi.internal_parameter_connections)
end

#End of graph section
