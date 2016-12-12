module Mimi

include("metainfo.jl")
include("clock.jl")

using DataStructures
using DataFrames
using Distributions
using NamedArrays

export
    ComponentState, run_timestep, run, @defcomp, Model, setindex, addcomponent, setparameter,
    connectparameter, setleftoverparameters, getvariable, adder, MarginalModel, getindex,
    getdataframe, components, variables, getvpd, unitcheck, addparameter, plot

import
    Base.getindex, Base.run, Base.show

function lint_helper(ex::Expr, ctx)
    if ex.head == :macrocall
        if ex.args[1] == Symbol("@defcomp")
            push!(ctx.callstack[end].types, ex.args[2])
            return true
        end
    end
    return false
end

abstract ComponentState

type ComponentInstanceInfo
    name::Symbol
    component_type::DataType
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

include("marginalmodel.jl")

function setrandom(m::Model)
    if isnull(m.mi)
        m.mi = Nullable{ModelInstance}(build(m))
    end

    for p in values(m.external_parameters)
        setrandom(get(m.mi), p)
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

function setindex(m::Model, name::Symbol, count::Int)
    m.indices_counts[name] = count
    m.indices_values[name] = collect(1:count)
    nothing
end

function setindex{T}(m::Model, name::Symbol, values::Vector{T})
    m.indices_counts[name] = length(values)
    m.indices_values[name] = copy(values)
    nothing
end

"""
Add a component to a model.
"""
function addcomponent(m::Model, t, name::Symbol=t.name.name; before=nothing,after=nothing)
    if before!=nothing && after!=nothing
        error("Can only specify before or after parameter")
    end

    if before!=nothing
        newcomponents2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        for i in keys(m.components2)
            if i==before
                newcomponents2[name] = ComponentInstanceInfo(name, t)
            end
            newcomponents2[i] = m.components2[i]
        end
        m.components2 = newcomponents2
    elseif after!=nothing
        newcomponents2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        for i in keys(m.components2)
            newcomponents2[i] = m.components2[i]
            if i==after
                newcomponents2[name] = ComponentInstanceInfo(name, t)
            end
        end
        m.components2 = newcomponents2

    else
        m.components2[name] = ComponentInstanceInfo(name, t)
    end
    m.mi = Nullable{ModelInstance}()
    ComponentReference(m, name)
end

"""
Set the parameter of a component in a model to a given value.
"""
function setparameter(m::Model, component::Symbol, name::Symbol, value)
    addparameter(m, name, value)
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


function connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)
    p = m.external_parameters[Symbol(lowercase(string(parametername)))]

    if isa(p, ArrayModelParameter)
        checklabels(m, component, name, parametername, p)
    end

    x = ExternalParameterConnection(component, name, p)
    push!(m.external_parameter_connections, x)

    nothing
end

function updateparameter(m::Model, name::Symbol, value)
       p = m.parameters[Symbol(lowercase(string(name)))]

       p.value = value

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
Parameter dimension checks are performed on the NamedArray. Adds an array type parameter to the model.
"""
function addparameter(m::Model, name::Symbol, value::NamedArray)
    #namedarray given, so we can perform label checks
    dims = dimnames(value)

    check_parameter_dimensions(m, value, dims, name)

    p = ArrayModelParameter(value.array, dims) #want to use convert(Array, value) but broken
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
Adds an array type parameter to the model.
"""
function addparameter(m::Model, name::Symbol, value::AbstractArray)
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
Takes as input a regular array and a vector of dimension symbol names. Performs dimension name checks. Adds array type parameter to the model.
"""
function addparameter(m::Model, name::Symbol, value::AbstractArray, dims::Vector{Symbol})
    #instead of a NamedArray, user can pass in the names of the dimensions in the dims vector

    check_parameter_dimensions(m, value, dims, name) #best we can do is check that the dim names match

    p = ArrayModelParameter(value, dims)
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

"""
Adds a scalar type parameter to the model.
"""
function addparameter(m::Model, name::Symbol, value::Any)
    #function for adding scalar parameters ("Any" type)
    p = ScalarModelParameter(value)
    m.external_parameters[Symbol(lowercase(string(name)))] = p
end

function connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)

    # Check the units, if provided
    if !ignoreunits &&
        !unitcheck(getmetainfo(m, target_component).parameters[target_name].unit,
                   getmetainfo(m, source_component).variables[source_name].unit)
        error("Units of $source_component.$source_name do not match $target_component.$target_name.")
    end

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
Bind the parameter of one component to a variable in another component.

"""
connectparameter

"""
Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary.
"""

function setleftoverparameters(m::Model, parameters::Dict{Any,Any})
    for (name, value) in parameters
        addparameter(m, Symbol(name), value)
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
    return getfield(mi.components[component].Variables, name)
end

"""
    getdataframe(m::Model, componentname::Symbol, name::Symbol)

Return the values for variable `name` in `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, componentname::Symbol, name::Symbol)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    else
        return getdataframe(m, get(m.mi), componentname, name)
    end
end

function getdataframe(m::Model, mi::ModelInstance, componentname::Symbol, name::Symbol)
    comp_type = typeof(mi.components[componentname])

    meta_module_name = Symbol(supertype(typeof(mi.components[componentname])).name.module)
    meta_component_name = Symbol(supertype(typeof(mi.components[componentname])).name.name)

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

import Base.show
show(io::IO, a::ComponentState) = print(io, "ComponentState")

function build(m::Model)
    #instantiate the components
    builtComponents = OrderedDict{Symbol, ComponentState}()
    for c in values(m.components2)
        t = c.component_type
        comp = t(m.numberType, m.indices_counts)

        builtComponents[c.name] = comp
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


    mi = ModelInstance(builtComponents, m.internal_parameter_connections)

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
    for c in values(mi.components)
        resetvariables(c)
        init(c)
    end

    clock = Clock(1,min(indices_counts[:time],ntimesteps))

    while !finished(clock)
        #update_scalar_parameters(mi)
        for i in mi.components
            name = i[1]
            c = i[2]
            update_scalar_parameters(mi, name)
            run_timestep(c,gettimestep(clock))
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


function run_timestep(s, t)
    typeofs = typeof(s)
    println("Generic run_timestep called for $typeofs.")
end

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

                push!(metapardef.args, :(metainfo.addparameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), $(pardims), $(description), $(unit))))
            else
                push!(metapardef.args, :(metainfo.addparameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), [], $(description), $(unit))))
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

include("adder.jl")

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

include("references.jl")
include("plotting.jl")
end # module
