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
        result = :(Mimi._import_param!(obj, $(QuoteNode(localparname)), $(regargs...);
                                       $(keyargs...)))

    elseif @capture(expr, localvarname_ = Variable(varcomp_.varname_))
        _typecheck(localvarname, Symbol, "Local variable name")
        _typecheck(varcomp, Symbol, "Name of referenced component")
        _typecheck(varname, Symbol, "Name of referenced variable")

        result = :(Mimi._import_var!(obj, $(QuoteNode(localvarname)),
                                     $varcomp, $(QuoteNode(varname))))

    elseif @capture(expr, connect(parcomp_.parname_, varcomp_.varname_))
        # raise error if parameter is already bound
        result = :(Mimi.connect_param!(obj,
                    $(QuoteNode(parcomp)), $(QuoteNode(parname)),
                    $(QuoteNode(varcomp)), $(QuoteNode(varname));
                    #allow_overwrite=false # new keyword to implement
        ))
    else
        error("Unrecognized composite statement: $expr")
    end
    return result
end

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
to these parameters in `obj`. If `names` is not `nothing`, only the given names are
imported into `obj`.

This is called automatically by `build!()`, but it can be useful for developers of
composites as well.

N.B. This is called at the end of code emitted by @defcomposite.
"""
function import_params!(obj::AbstractCompositeComponentDef;
                        names::Union{Nothing,Vector{Symbol}}=nothing)
    # returns a Vector{ParamPath}, which are Tuple{ComponentPath, Symbol}
    for (path, name) in unconnected_params(obj)
        @info "import_params!($(obj.comp_id)) ($path, $name)"

        comp = compdef(obj, path)
        if names === nothing || name in names
            #
            # TBD: looks like this works only for composites (which have refs), not leafs
            obj[name] = datum_reference(comp, name)
        end
    end
end

function _import_param!(obj::AbstractCompositeComponentDef, localname::Symbol,
                        pairs::Pair...)
    # @info "pairs: $pairs"
    for (comp, pname) in pairs
        if comp == :*       # wild card
            @info "Got wildcard for param $pname (Not yet implemented)"
        else
            newcomp = obj[nameof(comp)]
            @info "import_param!($(obj.comp_id)) ($(pathof(newcomp)), $pname) as $localname"

            # import the parameter from the given component
            obj[localname] = datum_reference(newcomp, pname)
        end
    end
end

#
# Import a variable from the given subcomponent
#
function _import_var!(obj::AbstractCompositeComponentDef, localname::Symbol,
                      comp::AbstractComponentDef, vname::Symbol)
    @info "import_var!($(obj.comp_id), $localname, $(comp.comp_id), $vname):"

    obj[localname] = datum_reference(comp, vname)
end


const NumericArray = Array{T, N} where {T <: Number, N}

# Deprecated
function _collect_bindings(exprs)
    bindings = []
    # @info "_collect_bindings: $exprs"

    for expr in exprs
        if @capture(expr, name_ => val_) && name isa Symbol &&
            (val isa Symbol || val isa Number || val.head in (:vcat, :hcat, :vect))
            push!(bindings, name => val)
        else
            error("Elements of bindings list must Pair{Symbol, Symbol} or Pair{Symbol, Number or Array of Number} got $expr")
        end
    end

    # @info "returning $bindings"
    return bindings
end

# Deprecated
function _subcomp(calling_module, args, kwargs)
    # splitarg produces a tuple for each arg of the form (arg_name, arg_type, slurp, default)
    arg_tups = map(splitarg, args)

    if kwargs === nothing
        # If a ";" was not used to separate kwargs, move any kwargs from args.
        kwarg_tups = filter(tup -> _arg_default(tup) !== nothing, arg_tups)
        arg_tups   = filter(tup -> _arg_default(tup) === nothing, arg_tups)
    else
        kwarg_tups = map(splitarg, kwargs)
    end

    if 1 > length(arg_tups) > 2
        @error "component() must have one or two non-keyword values"
    end

    arg1 = _arg_name(arg_tups[1])
    alias = length(arg_tups) == 2 ? _arg_name(args_tups[2]) : nothing

    cmodule = nothing
    if ! (@capture(arg1, cmodule_.cname_) || @capture(arg1, cname_Symbol))
        error("Component name must be a Module.name expression or a symbol, got $arg1")
    end

    valid_kws = (:bindings,)    # valid keyword args to the component() psuedo-function
    kw = Dict([key => [] for key in valid_kws])

    for (arg_name, arg_type, slurp, default) in kwarg_tups
        if arg_name in valid_kws
            if default isa Expr && hasmethod(Base.iterate, (typeof(default.args),))
                append!(kw[arg_name], default.args)
            else
                @error "Value of $arg_name argument must be iterable"
            end
        else
            @error "Unknown keyword $arg_name; valid keywords are $valid_kws"
        end
    end

    bindings = _collect_bindings(kw[:bindings])
    module_obj = (cmodule === nothing ? calling_module : getfield(calling_module, cmodule))
    return SubComponent(module_obj, cname, alias, bindings)
end

# Convert an expr like `a.b.c.d` to `[:a, :b, :c, :d]`
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
        # @warn "Expected Symbol or Symbol.Symbol..., got $expr"
        return nothing
    end

    syms = reverse(syms)
    var_or_par = pop!(syms)
    return ComponentPath(syms), var_or_par
end

"""
    defcomposite(cc_name::Symbol, ex::Expr)

Define a Mimi CompositeComponent `cc_name` with the expressions in `ex`.  Expressions
are all variations on `component(...)`, which adds a component to the composite. The
calling signature for `component()` processed herein is:

    component(comp_name, local_name;
              bindings=[list Pair{Symbol, Symbol or Number or Array of Numbers}])

Bindings are expressed as a vector of `Pair` objects, where the first element of the
pair is the name (again, without the `:` prefix) representing a parameter in the component
being added, and the second element is either a numeric constant, a matrix of the
appropriate shape, or the name of a variable in another component. The variable name
is expressed as the component id (which may be prefixed by a module, e.g., `Mimi.adder`)
followed by a `.` and the variable name in that component. So the form is either
`modname.compname.varname` or `compname.varname`, which must be known in the current module.

Unlike leaf components, composite components do not have user-defined `init` or `run_timestep`
functions; these are defined internally to iterate over constituent components and call the
associated method on each.
"""
macro OLD_defcomposite(cc_name, ex)
    # @info "defining composite $cc_name in module $(fullname(__module__))"

    @capture(ex, elements__)
    comps = SubComponent[]
    imports = []
    conns = []

    calling_module = __module__
    # @info "defcomposite calling module: $calling_module"

    for elt in elements
        # @info "parsing $elt"; dump(elt)

        if @capture(elt, (component(args__; kwargs__) | component(args__)))
            push!(comps, _subcomp(calling_module, args, kwargs))

        # distinguish imports, e.g., :(EXP_VAR = CHILD_COMP1.COMP2.VAR3),
        #    from connections, e.g., :(COMP1.PAR2 = COMP2.COMP5.VAR2)

        # elseif elt.head == :tuple && length(elt.args) > 0 && @capture(elt.args[1], left_ = right_) && left isa Symbol
        #     # Aliasing a local name to several parameters at once is possible using an expr like
        #     # :(EXP_PAR1 = CHILD_COMP1.PAR2, CHILD_COMP2.PAR2, CHILD_COMP3.PAR5, CHILD_COMP3.PAR6)
        #     # Note that this parses as a tuple expression with first element being `EXP_PAR1 = CHILD_COMP1`.
        #     # Here we parse everything on the right side, at once using broadcasting and add the initial
        #     # component (immediately after "=") to the list, and then store a Vector of param refs.
        #     args = [right, elt.args[2:end]...]
        #     vars_pars = parse_dotted_symbols.(args)
        #     @info "import as $left = $vars_pars"
        #     push!(imports, (left, vars_pars))

        elseif @capture(elt, left_ = right_)

            if left isa Symbol # simple import case
                # Save a singletons as a 1-element Vector for consistency with multiple linked params
                var_par = right.head == :tuple ? parse_dotted_symbols.(right.args) : [parse_dotted_symbols(right)]
                push!(imports, (left, var_par))
                # @info "import as $left = $var_par"

            # note that `comp_Symbol.name_Symbol` failed; bug in MacroTools?
            elseif @capture(left, comp_.name_) # simple connection case
                dst = parse_dotted_symbols(left)
                dst === nothing && error("Expected dot-delimited sequence of symbols, got $left")

                src = parse_dotted_symbols(right)
                src === nothing && error("Expected dot-delimited sequence of symbols, got $right")

                push!(conns, (dst, src))
                # @info "connection: $dst = $src"

            else
                error("Unrecognized expression on left hand side of '=' in @defcomposite: $elt")
            end
        else
            error("Unrecognized element in @defcomposite: $elt")
        end
    end

    # @info "imports: $imports"
    # @info "  $(length(imports)) elements"
    # global IMP = imports

    result = :(
        let conns = $conns,
            imports = $imports,

            cc_id = Mimi.ComponentId($calling_module, $(QuoteNode(cc_name)))

            global $cc_name = Mimi.CompositeComponentDef(cc_id, $(QuoteNode(cc_name)), $comps, $__module__)

            # @info "Defining composite $cc_id"

            function _store_in_ns(refs, local_name)
                isempty(refs) && return

                if length(refs) == 1
                    $cc_name[local_name] = refs[1]
                else
                    # We will eventually allow linking parameters, but not variables. For now, neither.
                    error("Variables and parameters may only be aliased individually: $refs")
                end
            end

            # This is more complicated than needed for now since we're leaving in place some of
            # the structure to accommodate linking multiple parameters to a single imported name.
            # We're postponing this feature to accelerate merging the component branch and will
            # return to this later.
            for (local_name, item) in imports
                var_refs = []
                par_refs = []

                for (src_path, src_name) in item
                    dr = Mimi.DatumReference(src_name, $cc_name, src_path)
                    if Mimi.is_parameter(dr)
                        push!(par_refs, Mimi.ParameterDefReference(dr))
                    else
                        push!(var_refs, Mimi.VariableDefReference(dr))
                    end
                end

                _store_in_ns(var_refs, local_name)
                _store_in_ns(par_refs, local_name)
            end

            for ((dst_path, dst_name), (src_path, src_name)) in conns
                # @info "connect_param!($(nameof($cc_name)), $dst_path, :$dst_name, $src_path, :$src_name)"
                Mimi.connect_param!($cc_name, dst_path, dst_name, src_path, src_name)
            end

            # import unconnected parameters
            Mimi.import_params!($cc_name)

            $cc_name
        end
    )

    # @info "defcomposite:\n$result"
    return esc(result)
end

nothing
