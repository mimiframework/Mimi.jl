using MacroTools

# From 1/16/2020 meeting
#
# c1 = Component(A)
# Component(B) # equiv B = Component(B)
#
# x3 = Parameter(a.p1, a.p2, b.p3, default=3, description="asflijasef", visibility=:private)
#
# This creates external param x3, and connects b.p3 and ANY parameter in any child named p1 to it
# AND now no p1 in any child can be connected to anything else. Use Not from the next if you want
# an exception for that
# x3 = Parameter(p1, b.p3, default=3, description="asflijasef", visibility=:private)
#
# x3 = Parameter(p1, p2, Not(c3.p1), b.p3, default=3, description="asflijasef", visibility=:private)
#
# connect(B.p2, c1.v4)
# connect(B.p3, c1.v4)
#
# x2 = Parameter(c2.x2, default=35)
#
# BUBBLE UP PHASE
#
# for p in unique(unbound_parameters)
#   x1 = Parameter(c1.x1)
# end
#
# if any(unbound_parameter) then error("THIS IS WRONG")
#
#
# Expressions to parse in @defcomposite:
#
# 1. name_ = Component(compname_)
# 2. Component(compname_) => (compname = Component(compname_))
# 3. pname_ = Parameter(args__) # args can be: pname, comp.pname, or keyword=value
# 4. connect(a.param, b.var)
#
#

 # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
_arg_name(arg_tup) = arg_tup[1]
_arg_type(arg_tup) = arg_tup[2]
_arg_slurp(arg_tup) = arg_tup[3]
_arg_default(arg_tup) = arg_tup[4]

function _typecheck(obj, expected_type, msg)
    obj isa expected_type || error("$msg must be a $expected_type; got $(typeof(obj)): $obj")
end

"""
    parse_dotted_symbols(expr)

Parse and expression like `a.b.c.d` and return the tuple `(ComponentPath(:a, :b, :c), :d)`,
or `nothing` if the expression is not a series of dotted symbols.
"""
function parse_dotted_symbols(expr)
    global Args = expr
    syms = Symbol[]

    ex = expr
    while @capture(ex, left_.right_) && right isa Symbol
        push!(syms, right)
        ex = left
    end

    if ex isa Symbol
        push!(syms, ex)
    else
        return nothing
    end

    syms = reverse(syms)
    datum_name = pop!(syms)
    return ComponentPath(syms), datum_name
end

#
# Convert @defcomposite "shorthand" statements into Mimi API calls
#
function _parse(expr)

    result = nothing
    
    if @capture(expr, newname_ = Component(compname_, args__)) ||
        @capture(expr, Component(compname_, args__))

        valid_keys = (:first, :last)

        # check newname is nothing or Symbol, compname is Symbol
        _typecheck(compname, Symbol, "Referenced component name")
        if newname !== nothing
            _typecheck(newname, Symbol, "Local name for component name")
        end
        
        #assign newname
        newname = (newname === nothing ? compname : newname)
        
        # handle keyword arguments
        keyargs = []        
        for arg in args
            @capture(arg, keywd_ = value_) # keyword arguments
            if keywd in valid_keys
                push!(keyargs, arg)
            else
                error("Unrecognized Component keyword '$keywd'; must be 'first' or 'last")
            end
        end

        result = :(Mimi.add_comp!(obj, $compname, $(QuoteNode(newname)); $(keyargs...)))

    elseif @capture(expr, localparname_ = Parameter(args__))
        valid_keys = (:default, :description, :unit)

        regargs = []
        keyargs = []

        for arg in args
            if @capture(arg, keywd_ = value_)
                if keywd in valid_keys
                    push!(keyargs, arg)
                else
                    error("Unrecognized Parameter keyword '$keywd'; must be one of $valid_keys")
                end

            elseif @capture(arg, (cname_.pname_ | pname_))
                cname = (cname === nothing ? :(:*) : cname) # wildcard
                push!(regargs, :(obj[$(QuoteNode(cname))] => $(QuoteNode(pname))))

            end
        end
        result = :(Mimi.import_param!(obj, $(QuoteNode(localparname)), $(regargs...);
                                       $(keyargs...)))

    elseif @capture(expr, localvarname_ = Variable(datum_expr_))
        if ((tup = parse_dotted_symbols(datum_expr)) === nothing)
            error("In @defcomposite's Variable(x), x must a Symbol or ",
                  "a dotted series of Symbols. Got :($datum_expr)")
        end
        comppath, varname = tup
        # @info "Variable: $comppath, :$varname"
        _typecheck(localvarname, Symbol, "Local variable name")
        _typecheck(comppath, ComponentPath, "The referenced component")
        _typecheck(varname, Symbol, "Name of referenced variable")

        # import from the added copy of the component, not the template -- thus
        # the lookup of obj[varcomp].
        result = :(Mimi._import_var!(obj, $(QuoteNode(localvarname)), $comppath,
                                     $(QuoteNode(varname))))

    elseif @capture(expr, connect(parcomp_.parname_, varcomp_.varname_))
        # raise error if parameter is already bound
        result = :(Mimi.connect_param!(obj,
                    $(QuoteNode(parcomp)), $(QuoteNode(parname)),
                    $(QuoteNode(varcomp)), $(QuoteNode(varname));
                    # allow_overwrite=false # new keyword to implement
        ))
    else
        error("Unrecognized composite statement: $expr")
    end
    return result
end

# TBD: finish documenting this!
"""
    defcomposite(cc_name::Symbol, ex::Expr)

Define a Mimi CompositeComponentDef `cc_name` with the expressions in `ex`. Expressions
are all shorthand for longer-winded API calls, and include the following:

    p = Parameter(...)
    v = Variable(varname)
    local_name = Component(name)
    Component(name)  # equivalent to `name = Component(name)`
    connect(...)

Variable names are expressed as the component id (which may be prefixed by a module,
e.g., `Mimi.adder`) followed by a `.` and the variable name in that component. So the
form is either `modname.compname.varname` or `compname.varname`, which must be known
in the current module.

Unlike leaf components, composite components do not have user-defined `init` or
`run_timestep` functions; these are defined internally to iterate over constituent
components and call the associated method on each.
"""
macro defcomposite(cc_name, ex)
    @capture(ex, exprs__)

    calling_module = __module__

    # @info "defcomposite calling module: $calling_module"

    stmts = [_parse(expr) for expr in exprs]

    result = :(
        let cc_id = Mimi.ComponentId($calling_module, $(QuoteNode(cc_name))),
            obj = Mimi.CompositeComponentDef(cc_id)

            global $cc_name = obj
            $(stmts...)
            Mimi.import_params!(obj)
            $cc_name
        end
    )
    return esc(result)
end

"""
    import_params!(obj::AbstractCompositeComponentDef)

Imports all unconnected parameters below the given composite `obj` by adding references
to these parameters in `obj`.

N.B. This is also called at the end of code emitted by @defcomposite.
"""
function import_params!(obj::AbstractCompositeComponentDef)

    unconn = unconnected_params(obj)

    # Check for unresolved parameter name collisions. 
    # Users must explicitly define any parameters that come from multiple subcomponents.
    all_names = [ref.datum_name for ref in unconn]
    unique_names = unique(all_names)
    _map = Dict([name => count(isequal(name), all_names) for name in unique_names])
    non_unique = [name for (name, val) in _map if val>1]
    isempty(non_unique) || error("Cannot build composite :$(obj.name). There are unresolved parameter name collisions from subcomponents for the following parameter names: $(join(non_unique, ", ")).")

    for param_ref in unconn
        name = param_ref.datum_name
        haskey(obj, name) && error("Cannot build composite :$(obj.name). Failed to auto-import parameter :$name from component :$(param_ref.comp_name), this name has already been defined in the composite component's namespace.")
        obj[name] = CompositeParameterDef(obj, param_ref)
    end
end

# Helper function for finding any field collisions for parameters that want to be joined
function _find_collisions(fields, pairs::Vector{Pair{T, Symbol}}) where T
    collisions = Symbol[]

    pardefs = [comp.namespace[param_name] for (comp, param_name) in pairs]
    for f in fields
        subcomponent_set = Set([getproperty(pardef, f) for pardef in pardefs])
        length(subcomponent_set) > 1 && push!(collisions, f)
    end

    return collisions
end

# `kwargs` contains the keywords specified by the user when defining the composite parameter in @defcomposite.
# If the user does not provide a value for one or any of the possible fields, this function looks at the fields 
# of the subcomponents' parameters to use, but errors if any of them are in conflict.
# Note that :dim_names and :datatype can't be specified at the composite level, but must match from the subcomponents.
function _resolve_composite_parameter_kwargs(obj::AbstractCompositeComponentDef, kwargs::Dict{Symbol, Any}, pairs::Vector{Pair{T, Symbol}}, parname::Symbol)  where T <: AbstractComponentDef
    
    fields = (:default, :description, :unit, :dim_names, :datatype)
    collisions = _find_collisions(fields, pairs)

    # Create a new dictionary of resolved values to return
    new_kwargs = Dict{Symbol, Any}()

    for f in fields
        try 
            new_kwargs[f] = kwargs[f] # Get the user specified value for this field if there is one
        catch e
            # If the composite definition does not specify a value, then need to look to subcomponents and resolve or error
            if f in collisions
                error("Cannot build composite parameter :$parname, subcomponents have conflicting values for the \"$f\" field.")
            else
                compdef, curr_parname = pairs[1]
                pardef = compdef[curr_parname]   
                new_kwargs[f] = getproperty(pardef, f)
            end
        end
    end

    return new_kwargs
end

# Helper function for detecting whether a specified datum has already been imported or connected
function _is_connected(obj::AbstractCompositeComponentDef, comp_name::Symbol, datum_name::Symbol)
    for (k, item) in obj.namespace
        if isa(item, AbstractCompositeParameterDef)
            for ref in item.refs
                if ref.comp_name == comp_name && ref.datum_name == datum_name
                    return true
                end
            end
        elseif isa(item, AbstractCompositeVariableDef)
            ref = item.ref
            if ref.comp_name == comp_name && ref.datum_name == datum_name
                return true
            end            
        end
    end
    return false

    # cannot use the following, because all parameters haven't bubbled up yet
    # return UnnamedReference(comp_name, datum_name) in unconnected_params(obj)
end

# This function creates a CompositeParameterDef in the CompositeComponentDef obj
function import_param!(obj::AbstractCompositeComponentDef, localname::Symbol,
                        pairs::Pair...; kwargs...)

    print_pairs = [(comp.comp_id, name) for (comp, name) in pairs]
    # @info "import_param!($(obj.comp_id), :$localname, $print_pairs)"

    for (comp, pname) in pairs

        if comp == :*       # wild card
            error("Got wildcard component specification (*) for param $pname (Not yet implemented)")
        else
            compname = nameof(comp)
            has_comp(obj, compname) ||
                error("_import_param!: $(obj.comp_id) has no element named $compname")

            _is_connected(obj, compname, pname) &&
                error("Duplicate import of $(comp.name).$pname")
        end
    end
    new_kwargs = _resolve_composite_parameter_kwargs(obj, Dict{Symbol, Any}(kwargs), collect(pairs), localname)

    obj[localname] = CompositeParameterDef(localname, pathof(obj), collect(pairs), new_kwargs)
end

"""
Import a variable from the given subcomponent
"""
function _import_var!(obj::AbstractCompositeComponentDef, localname::Symbol,
                      path::ComponentPath, vname::Symbol)
    if haskey(obj, localname)
        error("Cannot import variable; :$localname already exists in component $(obj.comp_id)")
    end

    comp = @or(find_comp(obj, path), error("$path not found from component $(obj.comp_id)"))
    obj[localname] = CompositeVariableDef(localname, pathof(obj), comp, vname)
end

nothing
