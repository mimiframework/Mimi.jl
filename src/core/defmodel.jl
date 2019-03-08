#
# @defmodel and supporting functions
#
using MacroTools

"""
Target looks like this:

# Test the calls the macro will produce
let calling_module = @__MODULE__
    global m = Model()

    ccname = :testcomp
    ccid  = ComponentId(calling_module, ccname)
    comps = AbstractComponentDef[compdef(Comp1), compdef(Comp2), compdef(Comp3)]
    
    # TBD: need to implement this to create connections and default value
    bindings = Binding[
        DatumReference(:par_1_1, Comp1) => 5,                                 # bind Comp1.par_1_1 to constant value of 5
        DatumReference(:par_2_2, Comp2) => DatumReference(:var_1_1, Comp1),   # connect target Comp2.par_2_1 to source Comp1.var_1_1
        DatumReference(:par_3_1, Comp3) => DatumReference(:var_2_1, Comp2)]

    exports = [
        DatumReference(:par_1_1, Comp1) => :c1p1,        # i.e., export Comp1.par_1_1 as :c1p1
        DatumReference(:par_2_2, Comp2) => :c2p2,
        DatumReference(:var_3_1, Comp3) => :c3v1]

    m.md = md = ModelDef()
    CompositeComponentDef(md, ccid, comps, bindings, exports)
                                
    set_dimension!(m, :time, 2005:2020)
    nothing
end
"""

"""
    defmodel(model_name::Symbol, ex::Expr)

Define a Mimi model. The following types of expressions are supported:

1. `component(name)`                            # add comp to model
2. `dst_component.name = ex::Expr`              # provide a value for a parameter
3. `src_component.name => dst_component.name`   # connect a variable to a parameter
4. `index[name] = iterable-of-values`           # define values for an index
"""
macro defmodel(model_name, ex)
    @capture(ex, elements__)

    # @__MODULE__ is evaluated in calling module when macro is interpreted
    # TBD: simplify using __module__ ?
    result = :(
        let calling_module = @__MODULE__, comp_mod_name = nothing
            global $model_name = Model()
        end
    )
    
    # helper function used in loop below
    function addexpr(expr)
        let_block = result.args[end].args
        push!(let_block, expr)
    end

    for elt in elements
        offset = 0

        if @capture(elt, component(comp_mod_name_.comp_name_)         | component(comp_name_) |
                         component(comp_mod_name_.comp_name_, alias_) | component(comp_name_, alias_))

            # set local copy of comp_mod_name to the stated or default component module
            expr = (comp_mod_name === nothing ? :(comp_mod_name = nameof(calling_module)) 
                                              : :(comp_mod_name = $(QuoteNode(comp_mod_name))))
            addexpr(expr)

            name = (alias === nothing ? comp_name : alias)
            expr = :(add_comp!($model_name, Mimi.ComponentId(comp_mod_name, $(QuoteNode(comp_name))), $(QuoteNode(name))))


        # TBD: extend comp.var syntax to allow module name, e.g., FUND.economy.ygross
        elseif (@capture(elt, src_comp_.src_name_[arg_] => dst_comp_.dst_name_) ||
                @capture(elt, src_comp_.src_name_ => dst_comp_.dst_name_))
            if (arg !== nothing && (! @capture(arg, t - offset_) || offset <= 0))
                error("Subscripted connection source must have subscript [t - x] where x is an integer > 0")
            end

            expr = :(Mimi.connect_param!($model_name,
                                         $(QuoteNode(dst_comp)), $(QuoteNode(dst_name)),
                                         $(QuoteNode(src_comp)), $(QuoteNode(src_name)), 
                                         offset=$offset))

        elseif @capture(elt, index[idx_name_] = rhs_)
            expr = :(Mimi.set_dimension!($model_name, $(QuoteNode(idx_name)), $rhs))

        elseif @capture(elt, comp_name_.param_name_ = rhs_)
            expr = :(Mimi.set_param!($model_name, $(QuoteNode(comp_name)), $(QuoteNode(param_name)), $rhs))

        else
            # Pass through anything else to allow the user to define intermediate vars, etc.
            @info "Passing through: $elt"
            expr = elt
        end

        addexpr(expr)
    end

    # addexpr(:($model_name))     # return this or nothing?
    addexpr(:(nothing))
    return esc(result)
end
