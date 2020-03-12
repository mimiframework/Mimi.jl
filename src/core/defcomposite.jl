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
# @defcomposite should just emit all the same API calls one could make manually
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
    valid_keys = (:default, :description, :visability, :unit)
    result = nothing

    if @capture(expr, newname_ = Component(compname_)) ||
       @capture(expr, Component(compname_))
        # check newname is nothing or Symbol, compname is Symbol
        _typecheck(compname, Symbol, "Referenced component name")

        if newname !== nothing
            _typecheck(newname, Symbol, "Local name for component name")
        end

        newname = (newname === nothing ? compname : newname)
        result = :(Mimi.add_comp!(obj, $compname, $(QuoteNode(newname))))

    elseif @capture(expr, localparname_ = Parameter(args__))
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
                push!(regargs, :($cname => $(QuoteNode(pname))))
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
    import_params!(obj::AbstractCompositeComponentDef;
                   names::Union{Nothing,Vector{Symbol}}=nothing)

Imports all unconnected parameters below the given composite `obj` by adding references
to these parameters in `obj`.

NOT IMPLEMENTED: If `names` is not `nothing`, only the given names ar imported.

This is called automatically by `build!()`, but it can be useful for developers of
composites as well.

N.B. This is also called at the end of code emitted by @defcomposite.
"""
function import_params!(obj::AbstractCompositeComponentDef;
                        names::Union{Nothing,Vector{Symbol}}=nothing)

    unconn = unconnected_params(obj)
    params = parameters(obj)

    # remove imported params from list of unconnected params
    unconn = setdiff(unconn, params)
    # filter!(param_ref -> !(param_ref in params), unconn)

    # verify that all explicit names are importable
    if names !== nothing
        unconn_names = [nameof(param_ref) for param_ref in unconn]
        unknown = setdiff(names, unconn_names)
        if ! isempty(unknown)
            @error "Can't import names $unknown as these are not unconnected params"
        end
    end

    for param_ref in unconn
        # @info "importing $param_ref to $(obj.comp_id)"
        name = nameof(param_ref)
        if names === nothing || name in names
            obj[name] = param_ref
        end
    end
end

# Return the local name of an already-imported parameter, or nothing if not found
function _find_param_ref(obj, dr)
    for (name, param_ref) in param_dict(obj)
        # @info "Comparing refs $param_ref == $dr"
        if param_ref == dr
            # @info "Found prior import to $dr named $name"
            return name
        end
    end
    nothing
end

function import_param!(obj::AbstractCompositeComponentDef, localname::Symbol,
                        pairs::Pair...; kwargs...)

    print_pairs = [(comp.comp_id, name) for (comp, name) in pairs]
    # @info "import_param!($(obj.comp_id), :$localname, $print_pairs)"

    for (comp, pname) in pairs

        if comp == :*       # wild card
            @info "Got wildcard for param $pname (Not yet implemented)"
        else
            compname = nameof(comp)
            has_comp(obj, compname) ||
                error("_import_param!: $(obj.comp_id) has no element named $compname")

            newcomp = obj[compname]

            dr = datum_reference(newcomp, pname)
            old_name = _find_param_ref(obj, dr)

            # TBD: :allow_overwrite is not yet passed from @defcomposite
            key = :allow_overwrite
            if old_name === nothing || (haskey(kwargs, key) && kwargs[key])
                # import the parameter from the given component
                obj[localname] = dr = datum_reference(newcomp, pname)
                # @info "import_param! created dr $dr"
            else
                error("Duplicate import of $dr as $localname, already imported as $old_name. ",
                      "To allow duplicates, use Parameter($(nameof(comp)).$pname; :$key=True)")
            end

            if haskey(kwargs, :default)
                root =  get_root(obj)
                ref = ParameterDefReference(pname, root, pathof(newcomp), kwargs[:default])
                save_default!(obj, ref)
            end
        end
    end
end

"""
Import a variable from the given subcomponent
"""
function _import_var!(obj::AbstractCompositeComponentDef, localname::Symbol,
                      path::ComponentPath, vname::Symbol)
    if haskey(obj, localname)
        error("Can't import variable; :$localname already exists in component $(obj.comp_id)")
    end

    comp = @or(find_comp(obj, path), error("$path not found from component $(obj.comp_id)"))
    obj[localname] = datum_reference(comp, vname)
end

nothing
