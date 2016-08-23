module Mimi

include("metainfo.jl")
include("clock.jl")

using DataStructures
using DataFrames
using Distributions
using Compat

export
    ComponentState, run_timestep, run, @defcomp, Model, setindex, addcomponent, setparameter,
    connectparameter, setleftoverparameters, getvariable, adder, MarginalModel, getindex,
    getdataframe, components, variables, setbestguess, setrandom, getvpd, unitcheck

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

abstract Parameter

type CertainScalarParameter <: Parameter
    dependentCompsAndParams::Set{Tuple{ComponentState, Symbol}}
    value

    function CertainScalarParameter(value)
        p = new()
        p.dependentCompsAndParams = Set{Tuple{ComponentState,Symbol}}()
        p.value = value
        return p
    end
end

function setbestguess(p::CertainScalarParameter)
    for (c, name) in p.dependentCompsAndParams
        bg_value = p.value
        setfield!(c.Parameters,name,bg_value)
    end
end

function setrandom(p::CertainScalarParameter)
    for (c, name) in p.dependentCompsAndParams
        bg_value = p.value
        setfield!(c.Parameters,name,bg_value)
    end
end

type UncertainScalarParameter <: Parameter
    dependentCompsAndParams::Set{Tuple{ComponentState,Symbol}}
    value::Distribution

    function UncertainScalarParameter(value)
        p = new()
        p.dependentCompsAndParams = Set{Tuple{ComponentState,Symbol}}()
        p.value = value
        return p
    end
end

function setbestguess(p::UncertainScalarParameter)
    bg_value = mode(p.value)
    for (c, name) in p.dependentCompsAndParams
        setfield!(c.Parameters,name,bg_value)
    end
end

function setrandom(p::UncertainScalarParameter)
    sample = rand(p.value)
    for (c, name) in p.dependentCompsAndParams
        setfield!(c.Parameters,name,sample)
    end
end


type UncertainArrayParameter <: Parameter
    distributions::Array{Distribution, 1}
    values::Array{Float64,1}

    function UncertainArrayParameter(distributions)
        uap = new()
        uap.distributions = distributions
        uap.values = Array(Float64, size(distributions))
        return uap
    end
end

function setbestguess(p::UncertainArrayParameter)
    for i in 1:length(p.distributions)
        p.values[i] = mode(p.distributions[i])
    end
end

function setrandom(p::UncertainArrayParameter)
    for i in 1:length(p.distributions)
        p.values[i] = rand(p.distributions[i])
    end
end

type CertainArrayParameter <: Parameter
    values

    function CertainArrayParameter(values::Array)
        uap = new()
        uap.values = values
        return uap
    end
end

function setbestguess(p::CertainArrayParameter)
end

function setrandom(p::CertainArrayParameter)
end

type ComponentInstanceInfo
    name::Symbol
    component_type::DataType
end

type ParameterVariableConnection
    source_variable_name::Symbol
    source_component_name::Symbol
    target_parameter_name::Symbol
    target_component_name::Symbol
end

type Model
    indices_counts::Dict{Symbol,Int}
    indices_values::Dict{Symbol,Vector{Any}}
    components::OrderedDict{Symbol,ComponentState}
    parameters_that_are_set::Set{Compat.UTF8String}
    parameters::Dict{Symbol,Parameter}
    numberType::DataType
    connections::Array{ParameterVariableConnection, 1}
    components2::OrderedDict{Symbol, ComponentInstanceInfo}

    function Model(numberType::DataType=Float64)
        m = new()
        m.indices_counts = Dict{Symbol,Int}()
        m.indices_values = Dict{Symbol, Vector{Any}}()
        m.components = OrderedDict{Symbol,ComponentState}()
        m.parameters_that_are_set = Set{Compat.UTF8String}()
        m.parameters = Dict{Symbol, Parameter}()
        m.numberType = numberType
        m.connections = Array(ParameterVariableConnection, 0)
        m.components2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        return m
    end
end

type MarginalModel
    base::Model
    marginal::Model
    delta::Float64
end

function setbestguess(m::Model)
    for p in values(m.parameters)
        setbestguess(p)
    end
end

function setrandom(m::Model)
    for p in values(m.parameters)
        setrandom(p)
    end
end

"""
    components(m::Model)

List all the components in model `m`.
"""
function components(m::Model)
    collect(keys(m.components))
end

# Return the MetaComponent for a given component
function getmetainfo(m::Model, componentname::Symbol)
    meta = metainfo.getallcomps()
    meta_module_name = Symbol(supertype(typeof(m.components[componentname])).name.module)
    meta_component_name = Symbol(supertype(typeof(m.components[componentname])).name.name)
    meta[(meta_module_name, meta_component_name)]
end

"""
    variables(m::Model, componentname::Symbol)

List all the variables of `componentname` in model `m`.
"""
function variables(m::Model, componentname::Symbol)
    c = getmetainfo(m, componentname)
    collect(keys(c.variables))
end

function getindex(m::MarginalModel, component::Symbol, name::Symbol)
    return (m.marginal[component,name].-m.base[component,name])./m.delta
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
function addcomponent(m::Model, t, name::Symbol=Symbol(string(t)); before=nothing,after=nothing)
    if before!=nothing && after!=nothing
        error("Can only specify before or after parameter")
    end

    comp = t(m.numberType, m.indices_counts)

    if before!=nothing
        newcomponents = OrderedDict{Symbol,ComponentState}()
        newcomponents2 = OrderedDict{Symbol, ComponentInstanceInfo}()
        for i in keys(m.components)
            if i==before
                newcomponents[name] = comp
                curr = ComponentInstanceInfo(name, t)
                newcomponents2[name] = curr
            end
            newcomponents[i] = m.components[i]
            newcomponents2[i] = m.components2[i]
        end
        m.components = newcomponents
        m.components2 = newcomponents2
    elseif after!=nothing
        error("Not yet implemented")
    else
        m.components[name] = comp
        this = ComponentInstanceInfo(name, t)
        m.components2[name] = this
    end

    ComponentReference(m, name)
end

"""
Set the parameter of a component in a model to a given value.
"""
function setparameter(m::Model, component::Symbol, name::Symbol, value)
    addparameter(m, name, value)
    connectparameter(m, component, name, name)

    setbestguess(m.parameters[Symbol(lowercase(string(name)))])
    nothing
end

function connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)
    c = m.components[component]
    p = m.parameters[Symbol(lowercase(string(parametername)))]

    if isa(p, CertainScalarParameter) || isa(p, UncertainScalarParameter)
        push!(p.dependentCompsAndParams, (c, name))
    else
        try
            setfield!(c.Parameters,name,p.values)
        catch
            error("Failed to setfield for $name with setted size $(size(p.values)).")
        end
    end
    push!(m.parameters_that_are_set, string(component) * string(name))

    nothing
end

function updateparameter(m::Model, name::Symbol, value)
       p = m.parameters[Symbol(lowercase(string(name)))]

       p.value = value

       setbestguess(p)
end


function addparameter(m::Model, name::Symbol, value)
    if isa(value, Distribution)
        p = UncertainScalarParameter(value)
        m.parameters[Symbol(lowercase(string(name)))] = p
    elseif isa(value, AbstractArray)
        if any(x->isa(x, Distribution), value)
            p = UncertainArrayParameter(value)
            m.parameters[Symbol(lowercase(string(name)))] = p
        else
            if !(typeof(value) <: Array{m.numberType})
                # E.g., if model takes Number and given Float64, convert it
                value = convert(Array{m.numberType}, value)
            end

            p = CertainArrayParameter(value)
            m.parameters[Symbol(lowercase(string(name)))] = p
        end
    else
        p = CertainScalarParameter(value)
        m.parameters[Symbol(lowercase(string(name)))] = p
    end
end

function connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)
    c_target = m.components[target_component]
    c_source = m.components[source_component]

    # Check the units, if provided
    if !ignoreunits &&
        !unitcheck(getmetainfo(m, target_component).parameters[target_name].unit,
                   getmetainfo(m, source_component).variables[source_name].unit)
        throw(ErrorException("Units of $source_component.$source_name do not match $target_component.$target_name."))
    end

    setfield!(c_target.Parameters, target_name, getfield(c_source.Variables, source_name))
    push!(m.parameters_that_are_set, string(target_component) * string(target_name))

    this = ParameterVariableConnection(source_name, source_component, target_name, target_component)
    push!(m.connections, this)

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
function setleftoverparameters(m::Model,parameters::Dict{Any,Any})
    for (name, value) in parameters
        addparameter(m, Symbol(name), value)
    end

    for c in m.components
        for name in fieldnames(c[2].Parameters)
            if !in(string(c[1])*string(name), m.parameters_that_are_set)
                connectparameter(m, c[1], name, name)
            end
        end
    end
    nothing
end

function getindex(m::Model, component::Symbol, name::Symbol)
    return getfield(m.components[component].Variables, name)
end

"""
    getdataframe(m::Model, componentname::Symbol, name::Symbol)

Return the values for variable `name` in `componentname` of model `m` as a DataFrame.
"""
function getdataframe(m::Model, componentname::Symbol, name::Symbol)
    comp_type = typeof(m.components[componentname])

    meta_module_name = Symbol(supertype(typeof(m.components[componentname])).name.module)
    meta_component_name = Symbol(supertype(typeof(m.components[componentname])).name.name)

    vardiminfo = getdiminfoforvar((meta_module_name,meta_component_name), name)
    if length(vardiminfo)==0
        return m[componentname, name]
    elseif length(vardiminfo)==1
        df = DataFrame()
        df[vardiminfo[1]] = m.indices_values[vardiminfo[1]]
        df[name] = m[componentname, name]
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

"""
    run(m::Model)

Run model `m` once.
"""
function run(m::Model;ntimesteps=typemax(Int))
    clock = Clock(1,min(m.indices_counts[:time],ntimesteps))

    for c in values(m.components)
        resetvariables(c)
        init(c)
    end

    while !finished(clock)
        for c in values(m.components)
            run_timestep(c,gettimestep(clock))
        end
        move_forward(clock)
    end
end

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

@defcomp adder begin
    add = Parameter(index=[time])
    input = Parameter(index=[time])
    output = Variable(index=[time])
end

function run_timestep(s::adder, t::Int)
    v = s.Variables
    p = s.Parameters

    v.output[t] = p.input[t] + p.add[t]
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
    return filter(f, m.connections)
end

#End of graph section

include("references.jl")

end # module
