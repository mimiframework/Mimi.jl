using MacroTools

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
               exports::Union{Nothing,Vector}, bindings::Union{Nothing,Vector{Pair}})`

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

Unlike leaf components, composite components do not have user-defined `init` or `run_timestep`
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
            arg2 = length(args) == 2 ? args[2] : nothing

            for (arg_name, arg_type, slurp, default) in kwarg_tups
                if arg_name in valid_kws
                    if hasmethod(Base.iterate, typeof(default))
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

            expr = :(info = SubcompsDef($comps, bindings=$bindings, exports=$exports))
            addexpr(expr)

            expr = :(ComponentDef($comp_id, $comp_name; component_info=info))
            addexpr(expr)
        end
    end


    # addexpr(:($cc_name))     # return this or nothing?
    addexpr(:(nothing))
    return esc(result)
end
