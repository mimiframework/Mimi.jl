using MacroTools

export @modelegate, @defmodel


# Delegate calls to ::Model to internal ModelInstance or ModelDe` objects.
macro modelegate(ex)
    if @capture(ex, fname_(varname_::Model, args__) => rhs_)
        result = esc(:($fname($varname::Model, $(args...)) = $fname($varname.$rhs, $(args...))))
        #println(result)
        return result
    end
    error("Calls to @modelegate must be of the form 'func(m::Model, args...) => X', where X is either mi or md'. Expression was: $ex")
end

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
    result = quote $(esc(model_name)) = Model() end 

    for elt in elements
        if @capture(elt, component(comp_mod_.comp_name_) | 
                         component(comp_name_)) # | 
                        #  component(comp_mod_.comp_name_, alias_) | 
                        #  component(comp_name_, alias_))

            comp_mod = comp_mod == nothing ? curr_module : comp_mod
            expr = :(addcomponent($(esc(model_name)), $(esc(module_name)).$comp_name)) #, alias=alias)))

        elseif @capture(elt, src_comp_.src_name_ => dst_comp_.dst_name_)
            expr = :(connectparameter($(esc(model_name)),
                                      $(QuoteNode(src_comp)), $(QuoteNode(src_name)),
                                      $(QuoteNode(dst_comp)), $(QuoteNode(dst_name))))

        elseif @capture(elt, index[idx_name_] = rhs_)
            expr = :(setindex($(esc(model_name)), $(QuoteNode(idx_name)), $rhs))

        elseif @capture(elt, comp_name_.param_name_ = rhs_)
            expr = :(setparameter($(esc(model_name)), $(QuoteNode(comp_name)), $(QuoteNode(param_name)), $rhs))

        else
            # Pass through anything else to allow the user to define intermediate vars, etc.
            println("Passing through: $elt")
            expr = elt
        end

        push!(result.args, expr)
    end

    return result
end