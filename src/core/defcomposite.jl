using MacroTools

 # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
_arg_name(arg_tup) = arg_tup[1]
_arg_type(arg_tup) = arg_tup[2]
_arg_slurp(arg_tup) = arg_tup[3]
_arg_default(arg_tup) = arg_tup[4]

function _collect_exports(exprs)
    # each item in exprs is either a single symbol, or an expression mapping
    # one symbol to another, e.g., [:foo, :bar, :(:baz => :my_baz)]. We peel
    # out the symbols to create a list of pairs.
    exports = []
    # @info "_collect_exports: $exprs"

    for expr in exprs
        if (@capture(expr, name_ => expname_) || @capture(expr, name_)) &&
            (name isa Symbol && (expname === nothing || expname isa Symbol))
            push!(exports, name => @or(expname, name))
        else
            error("Elements of exports list must Symbols or Pair{Symbol, Symbol}, got $expr")
        end 
    end

    # @info "returning $exports"
    return exports
end

const NumericArray = Array{T, N} where {T <: Number, N}

function _collect_bindings(exprs)
    bindings = []
    # @info "_collect_bindings: $exprs"

    for expr in exprs
        if @capture(expr, name_ => val_) && name isa Symbol &&
            (val isa Symbol || val isa Number || val.head in (:vcat, :hcat, :vect))
            push!(bindings, name => val)
        else
            error("Elements of bindings list must Pair{Symbol, Symbol} or Pair{Symbol, Number or Array of Number} got $expr")
        end 
    end

    # @info "returning $bindings"
    return bindings
end

function _subcomp(args, kwargs)
    # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
    arg_tups = map(splitarg, args)

    if kwargs === nothing
        # If a ";" was not used to separate kwargs, move any kwargs from args.
        kwarg_tups = filter(tup -> _arg_default(tup) !== nothing, arg_tups)
        arg_tups   = filter(tup -> _arg_default(tup) === nothing, arg_tups)
    else
        kwarg_tups = map(splitarg, kwargs)
    end

    if 1 > length(arg_tups) > 2
        @error "component() must have one or two non-keyword values"
    end

    arg1 = _arg_name(arg_tups[1])
    alias = length(arg_tups) == 2 ? _arg_name(args_tups[2]) : nothing

    cmodule = nothing
    if ! (@capture(arg1, cmodule_.cname_) || @capture(arg1, cname_Symbol))
        error("Component name must be a Module.name expression or a symbol, got $arg1")
    end

    valid_kws = (:exports, :bindings)    # valid keyword args to the component() psuedo-function
    kw = Dict([key => [] for key in valid_kws])

    for (arg_name, arg_type, slurp, default) in kwarg_tups
        if arg_name in valid_kws
            if default isa Expr && hasmethod(Base.iterate, (typeof(default.args),))
                append!(kw[arg_name], default.args)
            else
                @error "Value of $arg_name argument must be iterable"
            end
        else
            @error "Unknown keyword $arg_name; valid keywords are $valid_kws"
        end
    end

    exports  = _collect_exports(kw[:exports])
    bindings = _collect_bindings(kw[:bindings])
    return SubComponent(cmodule, cname, alias, exports, bindings)
end

"""
    defcomposite(cc_name::Symbol, ex::Expr)

Define a Mimi CompositeComponent `cc_name` with the expressions in `ex`.  Expressions
are all variations on `component(...)`, which adds a component to the composite. The
calling signature for `component()` processed herein is:

    component(comp_name, local_name;
              exports=[list of symbols or Pair{Symbol,Symbol}],
              bindings=[list Pair{Symbol, Symbol or Number or Array of Numbers}])

In this macro, the vector of symbols to export is expressed without the `:`, e.g.,
`exports=[var_1, var_2 => export_name, param_1])`. The names must be variable or 
parameter names exported to the composite component being added by its sub-components.

Bindings are expressed as a vector of `Pair` objects, where the first element of the
pair is the name (again, without the `:` prefix) representing a parameter in the component
being added, and the second element is either a numeric constant, a matrix of the
appropriate shape, or the name of a variable in another component. The variable name
is expressed as the component id (which may be prefixed by a module, e.g., `Mimi.adder`)
followed by a `.` and the variable name in that component. So the form is either
`modname.compname.varname` or `compname.varname`, which must be known in the current module.

Unlike leaf components, composite components do not have user-defined `init` or `run_timestep`
functions; these are defined internally to iterate over constituent components and call the
associated method on each.
"""
macro defcomposite(cc_name, ex)
    # @info "defining composite $cc_name in module $(fullname(__module__))"
    
    @capture(ex, elements__)
    comps = SubComponent[]

    for elt in elements
        if @capture(elt, (component(args__; kwargs__) | component(args__)))
            push!(comps, _subcomp(args, kwargs))
        else
            error("Unrecognized element in @defcomposite: $elt")
        end
    end

    # module_name = nameof(__module__)

    # TBD: use fullname(__module__) to get "path" to module, as tuple of Symbols, e.g., (:Main, :ABC, :DEF)
    # TBD: use Base.moduleroot(__module__) to get the first in that sequence, if needed
    # TBD: parentmodule(m) gets the enclosing module (but for root modules returns self)
    # TBD: might need to replace the single symbol used for module name in ComponentId with Module path.

    result = quote
        cc_id = Mimi.ComponentId($__module__, $(QuoteNode(cc_name)))
        global $cc_name = Mimi.CompositeComponentDef(cc_id, $(QuoteNode(cc_name)), $comps, $__module__)
        $cc_name
    end

    # @info "defcomposite:\n$result"
    return esc(result)
end

nothing
