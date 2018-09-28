# Convert a list of args with optional type specs to just the arg symbols
_arg_names(args::Vector) = [a isa Symbol ? a : a.args[1] for a in args]

# TBD: move this to a more central location
"""
Macro to define a method that simply delegate to a method with the same signature
but using the specified field name of the original first argument as the first arg
in the delegated call. That is,

    `@delegate compid(ci::MetaComponentInstance, i::Int, f::Float64) => leaf`

expands to:

    `compid(ci::MetaComponentInstance, i::Int, f::Float64) = compid(ci.leaf, i, f)`
"""
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

global const BindingTypes = Union{Int, Float64, Tuple{ComponentId, Symbol}}

struct CompositeComponentDef <: AbstractComponentDef
    comp_id::ComponentId
    name::Symbol
    comps::Vector{AbstractComponent}
    bindings::Vector{Pair{Symbol, BindingTypes}}
    exports::Vector{Pair{Symbol, Tuple{ComponentId, Symbol}}}
end


# This function is called by the default run_timestep defined by @defcomp when 
# the user defines sub-components and doesn't define an explicit run_timestep.
# Can it also be called by the user's run_timestep?
function _composite_run_timestep(p, v, d, t)
    for ci in components(mci)
        run_timestep(ci, t)
    end
    return nothing
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
    
    function LeafComponentInstance{TV, TP}(comp_def::ComponentDef, vars::TV, pars::TP, name::Symbol=name(comp_def);
                                           is_composite::Bool=false) where {TV <: ComponentInstanceVariables, 
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
        if is_composite
            self.run_timestep = _composite_run_timestep
        else
            self.run_timestep = try eval(comp_module, Symbol("run_timestep_$(comp_id.module_name)_$(comp_id.comp_name)")) end
        end
           
        return self
    end
end

struct CompositeComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: AbstractComponentInstance

    # TV, TP, and dim_dict are computed by aggregating all the vars and params from the CompositeComponent's 
    # sub-components. Might be simplest to implement using a LeafComponentInstance that holds all the 
    # "summary" values and references, the init and run_timestep funcs, and a vector of sub-components.
    leaf::LeafComponentInstance{TV, TP}
    comps::Vector{AbstractComponentInstance}
    firsts::Vector{Int}        # in order corresponding with components
    lasts::Vector{Int}
    clocks::Union{Void, Vector{Clock{T}}}

    function CompositeComponentInstance{TV, TP}(
        comp_def::CompositeComponentDef, vars::TV, pars::TP,
        name::Symbol=name(comp_def)) where {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

        self = new{TV, TP}()
        self.leaf = LeafComponentInstance{TV, TP}(comp_def, vars, pars, name)
        self.firsts = Vector{Int}()
        self.lasts  = Vector{Int}()
        self.clocks = nothing
    end
end

components(obj::CompositeComponentInstance) = obj.comps

struct Model
    ccd::CompositeComponentDef
    cci::union{Void, CompositeComponentInstance}

    function Model(cc::CompositeComponentDef)
        return new(cc, nothing)
    end
end

# If using composition with LeafComponentInstance, we just delegate from 
# CompositeComponentInstance to the internal (summary) LeafComponentInstance.
compid(ci::LeafComponentInstance) = ci.comp_id
name(ci::LeafComponentInstance) = ci.comp_name
dims(ci::LeafComponentInstance) = ci.dim_dict
variables(ci::LeafComponentInstance) = ci.variables
parameters(ci::LeafComponentInstance) = ci.parameters
init_func(ci::LeafComponentInstance) = ci.init
timestep_func(ci::LeafComponentInstance) = ci.run_timestep

@delegate compid(ci::CompositeComponentInstance) => leaf
@delegate name(ci::CompositeComponentInstance) => leaf
@delegate dims(ci::CompositeComponentInstance) => leaf
@delegate variables(ci::CompositeComponentInstance) => leaf
@delegate parameters(ci::CompositeComponentInstance) => leaf
@delegate init_func(ci::LeafComponentInstance) => leaf
@delegate timestep_func(ci::CompositeComponentInstance) => leaf

@delegate variables(m::Model) => cci
@delegate parameters(m::Model) => cci
@delegate components(m::Model) => cci
@delegate firsts(m::Model) => cci
@delegate lasts(m::Model) => cci
@delegate clocks(m::Model) => cci

function reset(cci::CompositeComponentInstance)
    for c in components(mci)
        reset(c)
    end
    return nothing
end

function run_timestep(ci::C, t::T) where {C <: AbstractComponentInstance, T <: AbstractTimestep}
    fn = timestep_func(ci)
    if fn != nothing
        fn(parameters(ci), variables(ci), dims(ci), t)
    end
    return nothing
end


"""
    defcomposite(cc_name::Symbol, ex::Expr)

Define a Mimi CompositeComponent `ccc_name` with the expressions in `ex`.  Expressions
are all variations on `component(...)`, which adds a component to the composite. The
calling signature for `component` is:

    `component(comp_id::ComponentId, name::Symbol=comp_id.comp_name; 
               export::Union{Void,Vector}, bind::Union{Void,Vector{Pair}})`

In this macro, the vector of symbols to export is expressed without the `:`, e.g.,
`export=[var_1, var_2, param_1])`. The names must be variable or parameter names in
the component being added.

Bindings are expressed as a vector of `Pair` objects, where the first element of the
pair is a symbol (without the `:` prefix) representing a parameter in the component
being added, and the second element is either a numeric constant, a matrix of the
appropriate shape, or the name of a variable in another component. The variable name
is expressed as the component id (which may be prefixed by a module, e.g., `Mimi.adder`)
followed by a `.` and the variable name in that component. So the form is either
`modname.compname.varname` or `compname.varname`, which must be known in the current module.

Unlike LeafComponents, CompositeComponents do not have user-defined `init` and `run_timestep`
functions; these are defined internally to simply iterate over constituent components and
call the associated method on each.
"""
macro defcomposite(cc_name, ex)
    @capture(ex, elements__)

    result = :(
        # @__MODULE__ is evaluated in calling module when macro is interpreted
        let calling_module = @__MODULE__ #, comp_mod_name = nothing
            global $cc_name = CompositeComponentDef()
        end
    )
    
    # helper function used in loop below
    function addexpr(expr)
        let_block = result.args[end].args
        push!(let_block, expr)
    end

    for elt in elements
        offset = 0

        if @capture(elt, component(comp_mod_name_name_.comp_name_)    | component(comp_name_) |
                         component(comp_mod_name_.comp_name_, alias_) | component(comp_name_, alias_))

            # set local copy of comp_mod_name to the stated or default component module
            expr = (comp_mod_name === nothing ? :(comp_mod_name = nameof(calling_module)) : :(comp_mod_name = $(QuoteNode(comp_mod_name))))
            addexpr(expr)

            name = (alias === nothing ? comp_name : alias)
            expr = :(add_comp!($cc_name, eval(comp_mod_name).$comp_name, $(QuoteNode(name))))

        # TBD: extend comp.var syntax to allow module name, e.g., FUND.economy.ygross
        elseif (@capture(elt, src_comp_.src_name_[arg_] => dst_comp_.dst_name_) ||
                @capture(elt, src_comp_.src_name_ => dst_comp_.dst_name_))
            if (arg !== nothing && (! @capture(arg, t - offset_) || offset <= 0))
                error("Subscripted connection source must have subscript [t - x] where x is an integer > 0")
            end

            expr = :(Mimi.connect_param!($cc_name,
                                         $(QuoteNode(dst_comp)), $(QuoteNode(dst_name)),
                                         $(QuoteNode(src_comp)), $(QuoteNode(src_name)), 
                                         offset=$offset))

        elseif @capture(elt, index[idx_name_] = rhs_)
            expr = :(Mimi.set_dimension!($cc_name, $(QuoteNode(idx_name)), $rhs))

        elseif @capture(elt, comp_name_.param_name_ = rhs_)
            expr = :(Mimi.set_param!($cc_name, $(QuoteNode(comp_name)), $(QuoteNode(param_name)), $rhs))

        else
            # Pass through anything else to allow the user to define intermediate vars, etc.
            println("Passing through: $elt")
            expr = elt
        end
        
        expr = :(CompositeComponentDef($comp_id, $comp_name, $comps, bindings=$bindings, exports=$exports))
        addexpr(expr)
    end


    # addexpr(:($cc_name))     # return this or nothing?
    addexpr(:(nothing))
    return esc(result)
end
