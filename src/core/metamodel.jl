# Create variants for *Instance and *Def

abstract struct AbstractComponentDef <: NamedDef end

mutable struct LeafComponentDef <: AbstractComponentDef
    name::Symbol
    comp_id::ComponentId
    variables::OrderedDict{Symbol, DatumDef}
    parameters::OrderedDict{Symbol, DatumDef}
    dimensions::OrderedDict{Symbol, DimensionDef}
    first::Int
    last::Int
end

# *Def implementation doesn't need to be performance-optimized since these
# are used only to create *Instance objects that are used at run-time. With
# this in mind, we don't create dictionaries of vars, params, or dims in the
# MetaComponentDef since this would complicate matters if a user decides to
# add/modify/remove a component. Instead of maintaining a secondary dict, we
# just iterate over sub-components at run-time as needed.

struct MetaComponentDef <: AbstractComponentDef
    name::Symbol
    comp_id::ComponentId
    comps::Vector{AbstractComponent}
end

struct Model
    metacomp::MetaComponent
    mi::union{ModelInstance, Void}
    md::ModelDef

    function new(md::ModelDef)
        m = Model(md)
        m.mi = nothing
        m.comps = Vector{AbstractComponent}()          # compute these when the model is built
        m.pars  = Vector{ParameterInstance}()
        m.vars  = Vector{VariableInstance}()
        m.vars  = Vector{VariableInstance}()
        return m
    end
end


abstract struct AbstractComponentInstance end

mutable struct LeafComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: AbstractComponentInstance
    comp_name::Symbol
    comp_id::ComponentId
    variables::TV
    parameters::TP
    dim_dict::Dict{Symbol, Vector{Int}}

    first::Int
    last::Int

    init::Union{Void, Function}  # use same implementation here?
    run_timestep::Union{Void, Function}
end

struct MetaComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: AbstractComponentInstance

    # TV, TP, and dim_dict are computed by aggregating all the vars and params from the MetaComponent's 
    # sub-components. Might be simplest to implement using a LeafComponentInstance that holds all the 
    # "summary" values and references, the init and run_timestep funcs, and a vector of sub-components.
    leaf::LeafComponentInstance{TV, TP}
    comps::Vector{AbstractComponentInstance}
end

components(obj::MetaComponentInstance) = obj.comps

mutable struct ModelInstance
    md::ModelDef

    comp::Union{Void, MetaComponentInstance}

    # Push these down to comp?
    firsts::Vector{Int}        # in order corresponding with components
    lasts::Vector{Int}

    function ModelInstance(md::ModelDef)
        self = new()
        self.md = md
        self.comp = nothing
        self.firsts = Vector{Int}()
        self.lasts = Vector{Int}()
        return self
    end
end

# If using composition with LeafComponentInstance, we just delegate from 
# MetaComponentInstance to the internal (summary) LeafComponentInstance.
compid(c::LeafComponentInstance) = c.comp_id
name(c::LeafComponentInstance) = c.comp_name
dims(c::LeafComponentInstance) = c.dim_dict
variables(c::LeafComponentInstance) = c.variables
parameters(c::LeafComponentInstance) = c.parameters

macro delegate(ex)
    if @capture(ex, fname_(varname_::MetaComponentInstance, args__) => rhs_)
        result = esc(:($fname($varname::Model, $(args...)) = $fname($varname.$rhs, $(args...))))
        println(result)
        return result
    end

    error("Calls to @delegate must be of the form 'func(m::Model, args...) => X', where X is a field of X to delegate to'. Expression was: $ex")
end

@delegate compid(c::MetaComponentInstance) => leaf
@delegate name(c::MetaComponentInstance) => leaf
@delegate dims(c::MetaComponentInstance) => leaf
@delegate variables(c::LeafComponentInstance) => leaf
@delegate parameters(c::LeafComponentInstance) => leaf

@delegate variables(mi::ModelInstance) => comp
@delegate parameters(mi::ModelInstance) => comp
@delegate components(mi::ModelInstance) => comp


build(c::Component) = nothing

function build(m::Model)
    for c in components(m)
        (vars, pars, dims) = build(c)

        # Add vars, pars, dims to our list
    end

    m.mi = build(m.md)

    return # vars, pars, dims
end


reset(c::Component) = reset(c.ci)

function reset(mci::MetaComponentInstance)
    for c in components(mci)
        reset(c)
    end    
end

function run_timestep(ci::AbstractComponentInstance, t::AbstractTimestep)
    if ci.run_timestep != nothing
        ci.run_timestep(parameters(ci), variables(ci), dims(ci), t)
    end
    
    nothing
end

# This function is called by the default run_timestep defined by @defcomp when 
# the user defines sub-components and doesn't define an explicit run_timestep.
function _meta_run_timestep(p, v, d, t)
    for ci in components(mci)
        ci.run_timestep(ci, t)
    end

    nothing
end