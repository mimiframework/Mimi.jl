using MacroTools

# Dummy versions for macro testing
struct ComponentId
    module_name::Symbol
    comp_name::Symbol
end

abstract type AbstractComponentDef end

struct BindingDef
    param::Symbol
    value::Union{Number, Symbol}
end

mutable struct CompositeComponentDef <: AbstractComponentDef
    comp_id::ComponentId
    name::Symbol
    comps::Vector{AbstractComponentDef}
    bindings::Vector{BindingDef}
    exports::Vector{Symbol}

    function CompositeComponentDef(module_name::Symbol, name::Symbol)
        compid   = ComponentId(module_name, name)
        comps    = Vector{AbstractComponentDef}()
        bindings = Vector{BindingDef}()
        exports  = Vector{Symbol}()
        return new(compid, name, comps, bindings, exports)
    end
end

function add_comp!(cc::CompositeComponentDef, compid::ComponentId, name::Symbol, bindings::Vector{BindingDef}, exports::Vector{Symbol})
    # push!(cc.comps, comp)
    # append!(cc.bindings, bindings)
    # append!(cc.exports, exports)
end

macro defcc(cc_name, ex)
    legal_kw = (:bindings, :exports)

    # @__MODULE__ is evaluated in calling module when macro is interpreted
    result = :(
        let calling_module = @__MODULE__
            global $cc_name = CompositeComponentDef($(QuoteNode(cc_name)))
        end
    )
    
    # helper function used in loop below
    function addexpr(expr)
        let_block = result.args[end].args
        @info "addexpr($expr)"
        push!(let_block, expr)
    end

    @capture(ex, elements__)
    println(elements)
    for el in elements
        if ( @capture(el, component(args__; kwargs__)) || @capture(el, component(args__)) )
            if kwargs === nothing
                # extract kw args if expr didn't use a ";"
                kwargs = filter(arg ->  @capture(arg, lhs_ = rhs__), args)

                # remove the kw args, leaving non-kwargs
                filter!(arg -> !@capture(arg, lhs_ = rhs__), args)
            end
        end
        @info "args:$args kwargs:$kwargs"

        nargs = length(args)
        if !(nargs == 1 || nargs == 2)
            error("defcc: component takes one or two non-keyword args, got: $args")
        end

        num_kwargs = length(kwargs)
        if num_kwargs > length(legal_kw)
            error("defcc: component takes one or two non-keyword args, got: $args")
        end

        # initialize dict with empty vectors for each keyword, allowing keywords to
        # appear multiple times, with all values appended together.
        kwdict = Dict([kw => [] for kw in legal_kw])

        for kwarg in kwargs
            @info "kwarg: $kwarg"
            @capture(kwarg, lhs_ = rhs__) || error("defcc: keyword arg '$kwarg' is missing a value")
            
            if ! (lhs in legal_kw)
                error("defcc: unrecognized keyword $lhs")
            end

            append!(kwdict[lhs], rhs)

            # for kw in keys(kwdict)
            #     val = kwdict[kw]
            #     @info "$kw: $val"
            # end
        end

        id = args[1]
        name = (nargs == 2 ? args[2] : nothing)

        expr = :(add_comp!($cc_name, $id, $name; bindings=$(kwdict[:bindings]), exports=$(kwdict[:exports])))
        addexpr(expr)
    end

    addexpr(:(nothing))
    return esc(result)
end

@macroexpand @defcc my_cc begin
    component(foo, bar; bindings=[1], exports=[1, 2])
    component(foo2, bar2, exports=[1, 2])
    component(bar, other)

    # error: "defcc: component takes one or two non-keyword args"
    # component(a, b, c)

    # error: "defcc: unrecognized keyword unrecog"
    # component(foo, bar, unrecog=[1, 2, 3])

    # error: "defcc: keyword arg 'baz' is missing a value"
    # component(foo, bar; baz)
end