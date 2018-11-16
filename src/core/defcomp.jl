#
# @defcomp and supporting functions
#
using MacroTools

global defcomp_verbosity = true

function set_defcomp_verbosity(value::Bool)
    global defcomp_verbosity = value
    nothing
end

# Store a list of built-in components so we can suppress messages about creating them
# TBD: and (later) suppress their return in the list of components at the user level.
const global built_in_comps = (:adder,  :ConnectorCompVector, :ConnectorCompMatrix)

is_builtin(comp_name) = comp_name in built_in_comps

function _generate_run_func(comp_name, args, body)
    if length(args) != 4
        error("Can't generate run_timestep; requires 4 arguments but got $args")
    end

    (p, v, d, t) = args

    # Generate unique function name for each component so we can store a function pointer.
    # (Methods requiring dispatch cannot be invoked directly. Could use FunctionWrapper here...)
    func_name = Symbol("run_timestep_$comp_name")

    # Needs "global" so function is defined outside the "let" statement
    func = :(
        global function $(func_name)($(p)::Mimi.ComponentInstanceParameters, 
                                     $(v)::Mimi.ComponentInstanceVariables, 
                                     $(d)::Mimi.DimDict, 
                                     $(t)::T) where {T <: Mimi.AbstractTimestep}
            $(body...)
            return nothing
        end
    )
    return func
end

function _generate_init_func(comp_name, args, body)

    if length(args) != 3
        error("Can't generate init function; requires 3 arguments but got $args")
    end

    # add types to the parameters  
    (p, v, d) = args

    func_name = Symbol("init_$comp_name")

    func = :(
        global function $(func_name)($(p)::Mimi.ComponentInstanceParameters, 
                                     $(v)::Mimi.ComponentInstanceVariables, 
                                     $(d)::Mimi.DimDict)
            $(body...)
            return nothing
        end
    )
    @debug "init func: $func"
    return func
end

function _check_for_known_argname(name)
    if !(name in (:description, :unit, :index, :default))
        error("Unknown argument name: '$name'")
    end
end

function _check_for_known_element(name)
    if !(name in (:Variable, :Parameter, :Index))
        error("Unknown component element type: '$name'")
    end
end

# Generates an expression to construct a Variable or Parameter
function _generate_var_or_param(elt_type, name, datatype, dimensions, dflt, desc, unit)
    func_name = elt_type == :Parameter ? :addparameter : :addvariable
    args = [datatype, dimensions, desc, unit]
    if elt_type == :Parameter
        push!(args, dflt)
    end

    expr = :(Mimi.$func_name(comp, $(QuoteNode(name)), $(args...)))
    @debug "Returning: $expr\n"
    return expr
end

function _generate_dims_expr(name, args, vartype)
    @debug "  Index $name"

    # Args are not permitted; we attempt capture only to check syntax
    if length(args) > 0
        error("Index $name: arguments to Index() are not permitted")
    end

    # Ditto types for Index, e.g., region::Foo = Index()
    if vartype !== nothing
        error("Index $name: Type specification ($vartype) is not supported")
    end

    expr = :(Mimi.add_dimension!(comp, $(QuoteNode(name))))
    return expr
end

_generate_dims_expr(name::Symbol) = _generate_dims_expr(name, [], nothing)

"""
    defcomp(comp_name::Symbol, ex::Expr)

Define a Mimi component `comp_name` with the expressions in `ex`.  The following 
types of expressions are supported:

1. `dimension_name = Index()`   # defines a dimension
2. `parameter = Parameter(index = [dimension_name], units = "unit_name", default = default_value)`    # defines a parameter with optional arguments
3. `variable = Variable(index = [dimension_name], units = "unit_name")`    # defines a variable with optional arguments
4. `init(p, v, d)`              # defines an init function for the component
5. `run_timestep(p, v, d, t)`   # defines a run_timestep function for the component

Parses a @defcomp definition, converting it into a series of function calls that
create the corresponding ComponentDef instance. At model build time, the ModelDef
(including its ComponentDefs) will be converted to a runnable model.
"""
macro defcomp(comp_name, ex)
    known_dims = Set{Symbol}()

    @capture(ex, elements__)
    @debug "Component $comp_name"

    # Allow explicit definition of module to define component in
    if @capture(comp_name, module_name_.cmpname_)       # e.g., Mimi.adder
        comp_name = cmpname
    end

    # We'll return a block of expressions that will define the component. First,
    # save the ComponentId to a variable with the same name as the component.
    # @__MODULE__ is evaluated when the expanded macro is interpreted
    result = :(
        let current_module = @__MODULE__
            global const $comp_name = Mimi.ComponentId(nameof(current_module), $(QuoteNode(comp_name)))
        end
    )

    # helper function used in loop below
    function addexpr(expr)
        let_block = result.args[end].args
        push!(let_block, expr)
    end

    newcomp = :(comp = new_comp($comp_name, $defcomp_verbosity))
    addexpr(newcomp)

    for elt in elements
        @debug "elt: $elt"
       
        if @capture(elt, function fname_(args__) body__ end)
            if fname == :run_timestep
                expr = _generate_run_func(comp_name, args, body)

            elseif fname == :init
                expr = _generate_init_func(comp_name, args, body)
            else
                error("@defcomp can contain only these functions: init(p, v, d) and run_timestep(p, v, d, t)")
            end

            addexpr(expr)
            continue
        end

        if ! @capture(elt, (name_::vartype_ | name_) = elt_type_(args__))
            error("Element syntax error: $elt")           
        end

        # elt_type is one of {:Variable, :Parameter, :Index}
        if elt_type == :Index
            expr = _generate_dims_expr(name, args, vartype)
            push!(known_dims, name)
            addexpr(expr)

        elseif elt_type in (:Variable, :Parameter)
            @debug "  $elt_type $name"
            desc = ""
            unit = ""
            dflt = nothing
            dimensions = Array{Symbol}(undef, 0)

            for arg in args
                @debug "    arg: $arg"
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
                    @debug "    dims: $dims"
                    append!(dimensions, dims)

                    # Add undeclared dimensions on-the-fly
                    for dim in dims
                        if ! (dim in known_dims)
                            addexpr(_generate_dims_expr(dim))
                            push!(known_dims, dim)
                        end
                    end

                elseif @capture(arg, default = dflt_)
                    if elt_type == :Variable
                        error("Default values are permitted only for Parameters, not for Variables")
                    end
                    @debug "Default for parameter $name is $dflt"
                end
            end

            @debug "    index $(Tuple(dimensions)), unit '$unit', desc '$desc'"

            dflt = eval(dflt)
            if (dflt !== nothing && length(dimensions) != ndims(dflt))
                error("Default value has different number of dimensions ($(ndims(dflt))) than parameter '$name' ($(length(dimensions)))")
            end

            vartype = vartype === nothing ? Number : eval(vartype)
            addexpr(_generate_var_or_param(elt_type, name, vartype, dimensions, dflt, desc, unit))

        else
            error("Unrecognized element type: $elt_type")
        end
    end

    # addexpr(:($comp_name))
    addexpr(:(nothing))         # reduces noise

    return esc(result)
end

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

        if @capture(elt, component(comp_mod_name_name_.comp_name_)    | component(comp_name_) |
                         component(comp_mod_name_.comp_name_, alias_) | component(comp_name_, alias_))

            # set local copy of comp_mod_name to the stated or default component module
            expr = (comp_mod_name === nothing ? :(comp_mod_name = nameof(calling_module)) : :(comp_mod_name = $(QuoteNode(comp_mod_name))))
            addexpr(expr)

            name = (alias === nothing ? comp_name : alias)
            expr = :(add_comp!($model_name, eval(comp_mod_name).$comp_name, $(QuoteNode(name))))

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
            println("Passing through: $elt")
            expr = elt
        end

        addexpr(expr)
    end

    # addexpr(:($model_name))     # return this or nothing?
    addexpr(:(nothing))
    return esc(result)
end
