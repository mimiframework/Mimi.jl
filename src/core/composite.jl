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

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # All CompositeComponentInstances use a standard method that just loops over inner components.
        mod_and_comp = "$(comp_id.module_name)_$(comp_id.comp_name)"
        self.run_timestep = is_composite ? nothing else try eval(comp_module, Symbol("run_timestep_$(mod_and_comp)")) end           
        self.init         = is_composite ? nothing else try eval(comp_module, Symbol("init_$(mod_and_comp)")) end
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

# We delegate from CompositeComponentInstance to the internal LeafComponentInstance.
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

@delegate variables(m::Model) => cci
@delegate parameters(m::Model) => cci
@delegate components(m::Model) => cci
@delegate firsts(m::Model) => cci
@delegate lasts(m::Model) => cci
@delegate clocks(m::Model) => cci

function reset_variables(cci::CompositeComponentInstance)
    for ci in components(cci)
        reset_variables(ci)
    end
    return nothing
end

function init(ci::LeafComponentInstance)
    reset_variables(ci)

    fn = init_func(ci)
    if fn != nothing
        fn(parameters(ci), variables(ci), dims(ci))
    end
    return nothing
end

function init(cci::CompositeComponentInstance)
    for ci in components(cci)
        init(ci)
    end
    return nothing
end

function run_timestep(ci::LeafComponentInstance, clock::Clock)
    fn = timestep_func(ci)
    if fn != nothing
        fn(parameters(ci), variables(ci), dims(ci), clock.ts)
    end

    # TBD: move this outside this func if components share a clock
    advance(clock)

    return nothing
end

function run_timestep(cci::CompositeComponentInstance, clock::Clock)
    for ci in components(cci)
        run_timestep(ci, clock)
    end
    return nothing
end

 # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
_arg_name(arg_tup) = arg_tup[1]
_arg_type(arg_tup) = arg_tup[2]
_arg_slurp(arg_tup) = arg_tup[3]
_arg_default(arg_tup) = arg_tup[4]

function _extract_args(args, kwargs)
    valid_kws = (:exports, :bindings)    # valid keyword args to `component()`
    kw_values = Dict()

    arg_tups = map(splitarg, args)

    if kwargs === nothing
        # If a ";" was not used to separate kwargs, extract them from args.
        # tup[4] => "default" value which for kwargs, the actual value.
        kwarg_tups = filter!(tup -> _arg_default(tup) !== nothing, arg_tups)
    else
        kwarg_tups = map(splitarg, kwargs)
    end

    @info "args: $arg_tups"
    @info "kwargs: $kwarg_tups"

    if 1 > length(arg_tups) > 2
        @error "component() must have one or two non-keyword values"
    end

    arg1 = _arg_name(arg_tups[1])
    arg2 = length(args) == 2 ? _arg_name(arg_tups[2]) : nothing

    for tup in kwarg_tups
        arg_name = _arg_name(tup)
        if arg_name in valid_kws
            default = _arg_default(tup)
            if hasmethod(Base.iterate, (typeof(default),))
                append!(kw_values[arg_name], default)
            else
                @error "Value of $arg_name argument must be iterable"
            end

        else
            @error "Unknown keyword $arg_name; valid keywords are $valid_kws"
        end
    end

    @info "kw_values: $kw_values"
    return (arg1, arg2, kw_values)
end

"""
    defcomposite(cc_name::Symbol, ex::Expr)

Define a Mimi CompositeComponent `cc_name` with the expressions in `ex`.  Expressions
are all variations on `component(...)`, which adds a component to the composite. The
calling signature for `component()` processed herein is:

    `component(comp_id::ComponentId, name::Symbol=comp_id.comp_name; 
               exports::Union{Void,Vector}, bindings::Union{Void,Vector{Pair}})`

In this macro, the vector of symbols to export is expressed without the `:`, e.g.,
`exports=[var_1, var_2, param_1])`. The names must be variable or parameter names in
the component being added.

Bindings are expressed as a vector of `Pair` objects, where the first element of the
pair is the name (again, without the `:` prefix) representing a parameter in the component
being added, and the second element is either a numeric constant, a matrix of the
appropriate shape, or the name of a variable in another component. The variable name
is expressed as the component id (which may be prefixed by a module, e.g., `Mimi.adder`)
followed by a `.` and the variable name in that component. So the form is either
`modname.compname.varname` or `compname.varname`, which must be known in the current module.

Unlike LeafComponents, CompositeComponents do not have user-defined `init` or `run_timestep`
functions; these are defined internally to iterate over constituent components and call
the associated method on each.
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

    valid_kws = (:exports, :bindings)    # valid keyword args to `component()`
    kw_values = Dict()

    for elt in elements
        offset = 0

        if @capture(elt, (component(args__; kwargs__) | component(args__)))

            #   component(comp_mod_name_.comp_name_) | 
            #   component(comp_mod_name_.comp_name_, alias_)))

            # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
            arg_tups = map(splitarg, args)

            if kwargs === nothing
                # If a ";" was not used to separate kwargs, extract them from args.
                # tup[4] => "default" value which for kwargs, the actual value.
                kwarg_tups = filter!(tup -> tup[4] !== nothing, arg_tups)
            else
                kwarg_tups = map(splitarg, kwargs)
            end

            @info "args: $args"
            @info "kwargs: $kwargs"

            if 1 > length(args) > 2
                @error "component() must have one or two non-keyword values"
            end

            arg1 = args[1]
            arg2 = length(args) == 2 ? args[2] else nothing

            for (arg_name, arg_type, slurp, default) in kwarg_tups
                if arg_name in valid_kws
                    if hasmethod(Base.iterate, (typeof(default),)
                        append!(kw_values[arg_name], default)
                    else
                        @error "Value of $arg_name argument must be iterable"
                    end

                else
                    @error "Unknown keyword $arg_name; valid keywords are $valid_kws"
                end
            end

            @info "kw_values: $kw_values"

            # set local copy of comp_mod_name to the stated or default component module
            expr = (comp_mod_name === nothing ? :(comp_mod_name = nameof(calling_module)) : :(comp_mod_name = $(QuoteNode(comp_mod_name))))
            addexpr(expr)

            # name = (alias === nothing ? comp_name : alias)
            # expr = :(add_comp!($cc_name, eval(comp_mod_name).$comp_name, $(QuoteNode(name))))
            
            expr = :(CompositeComponentDef($comp_id, $comp_name, $comps, bindings=$bindings, exports=$exports))
            addexpr(expr)
        end
    end


    # addexpr(:($cc_name))     # return this or nothing?
    addexpr(:(nothing))
    return esc(result)
end
