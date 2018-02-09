#
# @defmodel and supporting functions
#
using MacroTools

#
# A few types of expressions are supported:
# 1. component(name)
# 2. dst_cmp.name = ex::Expr
# 3. src_comp.name => dst_comp.name
# 4. index[time] = 2050:5:2100
#
macro defmodel(model_name, ex)
    @capture(ex, elements__)

    curr_module = Base.module_name(current_module())

    # Allow explicit definition of module to define model in
    if @capture(model_name, module_name_.model_)       # e.g., Mimi.adder
        model_name = model
    else
        module_name = curr_module
    end

    # We'll return a block of expressions that will define the model.
    # First, we add the empty model and assign it to the given model name.
    result = quote $model_name = Model() end 

    for elt in elements
        if @capture(elt, component(comp_mod_.comp_name_) | component(comp_name_))
            comp_mod = comp_mod == nothing ? curr_module : comp_mod
            expr = :(addcomponent($model_name, ComponentKey($(QuoteNode(comp_mod)), $(QuoteNode(comp_name)))))

        elseif @capture(elt, src_comp_.src_name_ => dst_comp_.dst_name_)
            expr = :(connectparameter($model_name, 
                                      $(QuoteNode(src_comp)), $(QuoteNode(src_name)),
                                      $(QuoteNode(dst_comp)), $(QuoteNode(dst_name))))

        elseif @capture(elt, index[idx_name_] = rhs_)
            expr = :(setindex($model_name, $(QuoteNode(idx_name)), $rhs))

        elseif @capture(elt, comp_name_.param_name_ = rhs_)
            expr = :(setparameter($model_name, $(QuoteNode(comp_name)), $(QuoteNode(param_name)), $rhs))

        else
            # Pass through anything else to allow the user to define intermediate vars, etc.
            println("Passing through: $elt")
            expr = elt
        end

        push!(result.args, expr)
    end

    return result
end