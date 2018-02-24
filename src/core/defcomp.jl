#
# @defcomp and supporting functions
#
using MacroTools

_Debug = false

function debug(msg)
    if _Debug
        println(msg)
    end
end

#
# Main> MacroTools.prewalk(replace_dots, :(p.foo[1,2] = v.bar))
# :((getproperty(p, Val(:foo)))[1, 2] = getproperty(v, Val(:bar)))
#
# Main> MacroTools.prewalk(replace_dots, :(p.foo = v.bar[1]))
# :(setproperty!(p, Val(:foo), (getproperty(v, Val(:bar)))[1]))
#
function _replace_dots(ex)
    debug("\nreplace_dots($ex)\n")

    if @capture(ex, obj_.field_ = rhs_)
        return :(setproperty!($obj, Val($(QuoteNode(field))), $rhs))
    
    elseif @capture(ex, obj_.field_)
        return :(getproperty($obj, Val($(QuoteNode(field)))))

    elseif @capture(ex, obj_.field_[args__] = rhs_)
        return :(getproperty($obj, Val($(QuoteNode(field))))[$(args...)] = $rhs)

    elseif @capture(ex, obj_.field_[args__])
        return :(getproperty($obj, Val($(QuoteNode(field))))[$(args...)])

    else
        #debug("No dots to replace")
        return ex
    end
end

function _generate_run_func(module_name, comp_name, args, body)
    # replace each expression with its dot-replaced equivalent
    body = [MacroTools.prewalk(_replace_dots, expr) for expr in body]

    func = :(
        function run_timestep($comp_name, $(args...))
            $(body...)
        end
    )
    debug("func: $func")
    return func
end

function _check_for_known_argname(name)
    if !(name in (:description, :unit, :index))
        error("Unknown argument name: '$name'")
    end
end

function _check_for_known_element(name)
    if !(name in (:Variable, :Parameter, :Index))
        error("Unknown component element type: '$name'")
    end
end

# Generates an expression to construct a Variable or Parameter
function _generate_var_or_param(elt_type, name, datatype, dimensions, desc, unit)
    func_name = elt_type == :Parameter ? :addparameter : :addvariable
    expr = :($func_name($(esc(:comp)), $(QuoteNode(name)), $datatype, $dimensions, $desc, $unit))
    debug("Returning: $expr\n")
    return expr
end

function _generate_dims_expr(name, args, vartype)
    debug("  Index $name")

    # Args are not permitted; we attempt capture only to check syntax
    if length(args) > 0
        error("Index $name: arguments to Index() are not permitted")
    end

    # Ditto types for Index, e.g., region::Foo = Index()
    if vartype != nothing
        error("Index $name: Type specification ($vartype) is not supported")
    end

    expr = :(add_dimension($(esc(:comp)), $(QuoteNode(name))))
    return expr
end

_generate_dims_expr(name::Symbol) = _generate_dims_expr(name, [], nothing)

#
# Parse a @defcomp definition, converting it into a series of function calls that
# create the corresponding ComponentDef instance. At model build time, the ModelDef
# (including its ComponentDefs) will be converted to a runnable model.
#
macro defcomp(comp_name, ex)
    known_dims = Set{Symbol}()
    
    @capture(ex, elements__)
    debug("Component $comp_name")

    # Allow explicit definition of module to define component in
    if @capture(comp_name, mod_name_.cmpname_)       # e.g., Mimi.adder
        comp_name = cmpname
    else
        mod_name = Base.module_name(current_module())
    end

    
    # We'll return a block of expressions that will define the component. First,
    # Firstsave the ComponentId to a variable with the same name as the component.
    result = quote   
        global const $(esc(comp_name)) = ComponentId($(QuoteNode(mod_name)), $(QuoteNode(comp_name)))
    end

    # helper function used in loop below
    function addexpr(expr)
        push!(result.args, expr)
    end
    
    # For some reason this was difficult to do at the higher language level. 
    # This fails: :(comp = newcomponent($(esc(mod_name).esc(comp_name))))
    # newcomp = Expr(:(=), :comp, Expr(:call, :newcomponent, QuoteNode(mod_name), QuoteNode(comp_name)))
    newcomp = :(comp = newcomponent($comp_name))
    addexpr(esc(newcomp))

    for elt in elements
        debug("elt: $elt")

        if @capture(elt, function run(args__) body__ end)
            # Save the expression that will store the run_timestep function definition, and
            # translate dot notation to get/setproperty. The func is created at build time so
            # it's created in the Mimi package.
            expr = _generate_run_func(mod_name, comp_name, args, body)
            run_expr = :(set_run_expr($(esc(:comp)), $(QuoteNode(expr))))
            addexpr(run_expr)
            continue
        end

        if ! @capture(elt, (name_::vartype_ | name_) = elt_type_(args__))
            error("Element syntax error: $elt")
        end

        # vartype = vartype == nothing ? ::Float64 : vartype
        # debug("name: $name, vartype: $vartype, elt_type: $elt_type, args: $args")

        # elt_type is one of {:Variable, :Parameter, :Index}
        if elt_type == :Index
            expr = _generate_dims_expr(name, args, vartype)
            push!(known_dims, name)
            addexpr(expr)

        elseif elt_type in (:Variable, :Parameter)
            debug("  $elt_type $name")
            desc = unit = ""
            dimensions = Array{Symbol}(0)

            for arg in args
                debug("    arg: $arg")
                if @capture(arg, argname_ = value_)
                    _check_for_known_argname(argname)

                elseif @capture(arg, argname_)
                    # If it's an unknown arg, report *that* rather than the missing value
                    _check_for_known_argname(argname)
                    error("Argument '$arg' of $elt_type $name is missing a value")

                else
                    error("Badly formatted argument: $arg")
                end

                if @capture(arg, description = value_)
                    desc = value

                elseif @capture(arg, unit = value_)
                    unit = value

                elseif @capture(arg, index = [dims__])
                    debug("    dims: $dims")
                    append!(dimensions, dims)

                    # Add undeclared dimensions on-the-fly
                    for dim in dims
                        if ! (dim in known_dims)
                            addexpr(_generate_dims_expr(dim))
                            push!(known_dims, dim)
                        end
                    end
                end
            end

            dims = Tuple(dimensions) # just for printing
            debug("    index $dims, unit '$unit', desc '$desc'")

            datatype = vartype == nothing ? Number : vartype
            addexpr(_generate_var_or_param(elt_type, name, datatype, dimensions, desc, unit))

        else
            error("Unrecognized element type: $elt_type")
        end
    end

    return rmlines(result)

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
        if @capture(elt, component(comp_mod_.comp_name_)         | component(comp_name_) |
                         component(comp_mod_.comp_name_, alias_) | component(comp_name_, alias_))

            comp_mod = comp_mod == nothing ? curr_module : comp_mod
            name = alias == nothing ? comp_name : alias
            expr = :(addcomponent($(esc(model_name)), $(esc(module_name)).$comp_name, $(QuoteNode(name))))

        elseif @capture(elt, src_comp_.src_name_ => dst_comp_.dst_name_)
            expr = :(connect_parameter($(esc(model_name)),
                                       $(QuoteNode(dst_comp)), $(QuoteNode(dst_name)),
                                       $(QuoteNode(src_comp)), $(QuoteNode(src_name))))

        elseif @capture(elt, index[idx_name_] = rhs_)
            expr = :(setindex($(esc(model_name)), $(QuoteNode(idx_name)), $rhs))

        elseif @capture(elt, comp_name_.param_name_ = rhs_)
            expr = :(set_parameter($(esc(model_name)), $(QuoteNode(comp_name)), $(QuoteNode(param_name)), $rhs))

        else
            # Pass through anything else to allow the user to define intermediate vars, etc.
            println("Passing through: $elt")
            expr = elt
        end

        push!(result.args, expr)
    end

    # Finally, add a call to create connector components in the new ModelDef
    push!(result.args, :(add_connector_comps!($(esc(model_name)))))

    return result
end