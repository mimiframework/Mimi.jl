#
# @defcomp and supporting functions
#
using MacroTools

# Store a list of built-in components so we can suppress messages about creating them.
# TBD: suppress returning these in the list of components at the user level.
const global built_in_comps = (:adder,  :multiplier, :ConnectorCompVector, :ConnectorCompMatrix)

is_builtin(comp_name) = comp_name in built_in_comps

function _generate_run_func(comp_name, module_name, args, body)
    if length(args) != 4
        error("Cannot generate run_timestep; requires 4 arguments but got $args")
    end

    (p, v, d, t) = args

    # Generate unique function name for each component so we can store a function pointer.
    # (Methods requiring dispatch cannot be invoked directly. Could use FunctionWrapper here...)
    func_name = Symbol("run_timestep_$(module_name)_$(comp_name)")

    # Needs "global" so function is defined outside the "let" statement
    func = :(
        global function $(func_name)($(p), #::Mimi.ComponentInstanceParameters,
                                     $(v), #::Mimi.ComponentInstanceVariables
                                     $(d), #::NamedTuple
                                     $(t)) #::T <: Mimi.AbstractTimestep
            $(body...)
            return nothing
        end
    )
    return func
end

function _generate_init_func(comp_name, module_name, args, body)

    if length(args) != 3
        error("Cannot generate init function; requires 3 arguments but got $args")
    end

    # add types to the parameters  
    (p, v, d) = args

    func_name = Symbol("init_$(module_name)_$(comp_name)")

    func = :(
        global function $(func_name)($(p), #::Mimi.ComponentInstanceParameters
                                     $(v), #::Mimi.ComponentInstanceVariables
                                     $(d)) #::NamedTuple
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

# Add a variable to a ComponentDef. CompositeComponents have no vars of their own,
# only references to vars in components contained within.
function add_variable(comp_def::ComponentDef, name, datatype, dimensions, description, unit)
    v = VariableDef(name, comp_def.comp_path, datatype, dimensions, description, unit)
    comp_def[name] = v            # adds to namespace and checks for duplicate
    return v
end

# Add a variable to a ComponentDef referenced by ComponentId
function add_variable(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    add_variable(compdef(comp_id), name, datatype, dimensions, description, unit)
end

function add_parameter(comp_def::ComponentDef, name, datatype, dimensions, description, unit, default)
    if default !== nothing
        ndims_default = (default isa Symbol || default isa String) ? 0 : ndims(default)
        if length(dimensions) != ndims_default
            error("Default value has different number of dimensions ($(ndims_default))) than parameter '$name' ($(length(dimensions)))")
        end
    end
    p = ParameterDef(name, comp_def.comp_path, datatype, dimensions, description, unit, default)
    comp_def[name] = p            # adds to namespace and checks for duplicate
    dirty!(comp_def)
    return p
end

function add_parameter(comp_id::ComponentId, name, datatype, dimensions, description, unit, default)
    add_parameter(compdef(comp_id), name, datatype, dimensions, description, unit, default)
end

# Generates an expression to construct a Variable or Parameter
function _generate_var_or_param(elt_type, name, datatype, dimensions, dflt, desc, unit)
    func_name = elt_type == :Parameter ? :add_parameter : :add_variable
    args = [datatype, dimensions, desc, unit]
    if elt_type == :Parameter
        push!(args, dflt)
    end

    expr = :(Mimi.$func_name(comp, $(QuoteNode(name)), $(args...)))
    @debug "Returning: $expr\n"
    return expr
end

function _generate_dims_expr(name, args, datum_type)
    @debug "  Index $name"

    # Args are not permitted; we attempt capture only to check syntax
    if length(args) > 0
        error("Index $name: arguments to Index() are not permitted")
    end

    # Ditto types for Index, e.g., region::Foo = Index()
    if datum_type !== nothing
        error("Index $name: Type specification ($datum_type) is not supported")
    end

    name_expr = (name isa Symbol) ? :($(QuoteNode(name))) : name
    expr = :(Mimi.add_dimension!(comp, $name_expr))
    @debug "  dims expr: $expr"
    return expr
end

_generate_dims_expr(name) = _generate_dims_expr(name, [], nothing)

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
    known_dims = Set{Union{Int, Symbol}}()

    @capture(ex, elements__)
    @debug "Component $comp_name"

    # TBD: Allow explicit definition of module to define component in
    if @capture(comp_name, module_name_.cmpname_)       # e.g., Mimi.adder
        comp_name = cmpname
    end

    # We'll return a block of expressions that will define the component.
    # N.B. @__MODULE__ is evaluated when the expanded macro is interpreted.
    result = :(
        let calling_module = @__MODULE__,
            comp_id = Mimi.ComponentId(calling_module, $(QuoteNode(comp_name))),
            comp = Mimi.ComponentDef(comp_id)

            global $comp_name = comp
        end
    )

    # helper function used in loop below
    function addexpr(expr)
        let_block = result.args[end].args
        push!(let_block, expr)
    end

    for elt in elements
        @debug "elt: $elt"

        # handle doc strings, which appear as macro calls to 
        if @capture(elt, @name_ doc_String expr_) && name isa GlobalRef && name.name == Symbol("@doc")
            @debug "ignoring doc string: $doc"
            elt = expr  # extract the expression; ignore the doc string
        end

        if @capture(elt, function fname_(args__) body__ end)
            if fname == :run_timestep
                body = elt.args[2].args  # replace captured body with this, which includes line numbers
                expr = _generate_run_func(comp_name, nameof(__module__), args, body)

            elseif fname == :init
                body = elt.args[2].args  # as above
                expr = _generate_init_func(comp_name, nameof(__module__), args, body)
            else
                error("@defcomp can contain only these functions: init(p, v, d) and run_timestep(p, v, d, t)")
            end

            addexpr(expr)
            continue
        end

        # DEPRECATION
        if @capture(elt, name_::datum_type_ = elt_type_(args__))
            error("The following syntax has been deprecated in @defcomp: \"$name::$datum_type = $elt_type(...)\". Use curly bracket syntax instead: \"$name = $elt_type{$datum_type}(...)\"")
        elseif ! @capture(elt, name_ = (elt_type_{datum_type_}(args__) | elt_type_(args__)))
        end
        
        # elt_type is one of {:Variable, :Parameter, :Index}
        if elt_type == :Index
            expr = _generate_dims_expr(name, args, datum_type)
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

                    if !isempty(filter(x -> !(x isa Union{Int,Symbol}), dims))
                        error("Dimensions ($dims) must be defined by a Symbol placeholder or an Int")
                    end
                    
                    append!(dimensions, map(Symbol, dims))  # converts, e.g., 4 into Symbol("4")

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

            datum_type = (datum_type === nothing ? :Number : datum_type)
            addexpr(_generate_var_or_param(elt_type, name, datum_type, dimensions, dflt, desc, unit))
        else
            error("Unrecognized element type: $elt_type")
        end
    end

    addexpr(:(nothing))         # reduces noise
    return esc(result)
end
