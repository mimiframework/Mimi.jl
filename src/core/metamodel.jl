# Convert a list of args with optional type specs to just the arg symbols
_arg_names(args::Vector) = [a isa Symbol ? a : a.args[1] for a in args]

macro delegate(ex)
    if @capture(ex, fname_(varname_::T_, args__) => rhs_)
        argnames = _arg_names(args)
        result = esc(:($fname($varname::$T, $(args...)) = $fname($varname.$rhs, $(argnames...))))
        return result
    end
    error("Calls to @delegate must be of the form 'func(obj, args...) => X', where X is a field of obj to delegate to'. Expression was: $ex")
end

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
    
    function LeafComponentInstance{TV, TP}(
        comp_def::ComponentDef, vars::TV, pars::TP, 
        name::Symbol=name(comp_def)) where {TV <: ComponentInstanceVariables, 
                                            TP <: ComponentInstanceParameters}

        self = new{TV, TP}()
        self.comp_id = comp_id = comp_def.comp_id
        self.comp_name = name
        self.dim_dict = Dict{Symbol, Vector{Int}}()     # set in "build" stage
        self.variables = vars
        self.parameters = pars
        self.first = comp_def.first
        self.last = comp_def.last        

        comp_module = eval(Main, comp_id.module_name)

        # the try/catch allows components with no run_timestep function (as in some of our test cases)
        self.run_timestep = func = try eval(comp_module, Symbol("run_timestep_$(comp_id.module_name)_$(comp_id.comp_name)")) end
           
        return self
    end
end

struct MetaComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: AbstractComponentInstance

    # TV, TP, and dim_dict are computed by aggregating all the vars and params from the MetaComponent's 
    # sub-components. Might be simplest to implement using a LeafComponentInstance that holds all the 
    # "summary" values and references, the init and run_timestep funcs, and a vector of sub-components.
    leaf::LeafComponentInstance{TV, TP}
    comps::Vector{AbstractComponentInstance}
    firsts::Vector{Int}        # in order corresponding with components
    lasts::Vector{Int}
    clocks::Union{Void, Vector{Clock{T}}}

    function MetaComponentInstance{TV, TP}(
        comp_def::MetaComponentDef, vars::TV, pars::TP,
        name::Symbol=name(comp_def)) where {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

        self = new{TV, TP}()
        self.leaf = LeafComponentInstance{TV, TP}(comp_def, vars, pars, name)
        self.firsts = Vector{Int}()
        self.lasts  = Vector{Int}()
        self.clocks = nothing
    end
end

components(obj::MetaComponentInstance) = obj.comps

mutable struct ModelInstance
    md::ModelDef
    comp::Union{Void, MetaComponentInstance}

    function ModelInstance(md::ModelDef)
        self = new()
        self.md = md
        self.comp = nothing
        return self
    end
end

# If using composition with LeafComponentInstance, we just delegate from 
# MetaComponentInstance to the internal (summary) LeafComponentInstance.
compid(ci::LeafComponentInstance) = ci.comp_id
name(ci::LeafComponentInstance) = ci.comp_name
dims(ci::LeafComponentInstance) = ci.dim_dict
variables(ci::LeafComponentInstance) = ci.variables
parameters(ci::LeafComponentInstance) = ci.parameters
init_func(ci::LeafComponentInstance) = ci.init
timestep_func(ci::LeafComponentInstance) = ci.run_timestep

@delegate compid(ci::MetaComponentInstance) => leaf
@delegate name(ci::MetaComponentInstance) => leaf
@delegate dims(ci::MetaComponentInstance) => leaf
@delegate variables(ci::MetaComponentInstance) => leaf
@delegate parameters(ci::MetaComponentInstance) => leaf
@delegate init_func(ci::LeafComponentInstance) => leaf
@delegate timestep_func(ci::MetaComponentInstance) => leaf

@delegate variables(mi::ModelInstance) => comp
@delegate parameters(mi::ModelInstance) => comp
@delegate components(mi::ModelInstance) => comp
@delegate firsts(mi::ModelInstance) => comp
@delegate lasts(mi::ModelInstance) => comp
@delegate clocks(mi::ModelInstance) => comp

function reset(mci::MetaComponentInstance)
    for c in components(mci)
        reset(c)
    end
    return nothing
end

function run_timestep(ci::AbstractComponentInstance, t::AbstractTimestep)
    fn = timestep_func(ci)
    if fn != nothing
        fn(parameters(ci), variables(ci), dims(ci), t)
    end
    return nothing
end

# This function is called by the default run_timestep defined by @defcomp when 
# the user defines sub-components and doesn't define an explicit run_timestep.
function _meta_run_timestep(p, v, d, t)
    for ci in components(mci)
        run_timestep(ci, t)
    end
    return nothing
end