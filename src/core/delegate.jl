#
# @delegate macro and support
#
using MacroTools

function delegated_args(args::Vector)
    newargs = []
    for a in args
        if a isa Symbol
            push!(newargs, a)

        elseif (@capture(a, var_::T_ = val_) || @capture(a, var_ = val_))
            push!(newargs, :($var = $var))

        elseif @capture(a, var_::T_)
            push!(newargs, var)      
        else
            error("Unrecognized argument format: $a")
        end
    end
    return newargs
end

"""
Macro to define a method that simply delegate to a method with the same signature
but using the specified field name of the original first argument as the first arg
in the delegated call. That is,

    `@delegate compid(ci::MetaComponentInstance, i::Int, f::Float64) => leaf`

expands to:

    `compid(ci::MetaComponentInstance, i::Int, f::Float64) = compid(ci.leaf, i, f)`

If a second expression is given, it is spliced in (basically to support "decache(m)")
"""
macro delegate(ex, other=nothing)
    result = nothing

    if @capture(ex, fname_(varname_::T_, args__) => rhs_)
        # @info "args: $args"
        new_args = delegated_args(args)
        result = quote
            function $fname($varname::$T, $(args...))
                retval = $fname($varname.$rhs, $(new_args...))
                $other
                return retval
            end
        end    
    elseif @capture(ex, fname_(varname_::T_, args__; kwargs__) => rhs_)
        # @info "args: $args, kwargs: $kwargs"
        new_args   = delegated_args(args)
        new_kwargs = delegated_args(kwargs)
        result = quote
            function $fname($varname::$T, $(args...); $(kwargs...))
                retval = $fname($varname.$rhs, $(new_args...); $(new_kwargs...))
                $other
                return retval
            end
        end  
    end

    if result === nothing
        error("Calls to @delegate must be of the form 'func(obj, args...) => X', where X is a field of obj to delegate to'. Expression was: $ex")
    end
    return esc(result)
end


# _arg_default(t::Nothing) = nothing
# _arg_default(value::Symbol) = QuoteNode(value)
# _arg_default(value::Any) = value

# function _compose_arg(arg_name, arg_type, slurp, default)
#     decl = arg_name
#     decl = arg_type != Any ? :($decl::$arg_type) : decl
#     decl = slurp ? :($decl...) : decl
#     decl = default !== nothing ? :($decl = $(_arg_default(default))) : decl
#     return decl
# end

# _compose_args(arg_tups::Vector{T}) where {T <: Tuple} = [_compose_arg(a...) for a in arg_tups]

# N.B.:
# julia> splitdef(funcdef)
# Dict{Symbol,Any} with 5 entries:
#   :name        => :fname
#   :args        => Any[:(arg1::T)]     # use splitarg() to bust out (arg_name, arg_type, slurp, default)
#   :kwargs      => Any[]
#   :body        => quote…
#   :rtype       => Any
#   :whereparams => ()

# Example
#=
@macroexpand @Mimi.delegates( 
    function foo(cci::CompositeComponentInstance, bar, baz::Int, other::Float64=4.0; x=10)
        println(other)
    end,

    mi::ModelInstance, 
    m::Model
)

=>

quote
    function foo(cci::CompositeComponentInstance, bar, baz::Int, other::Float64=4.0; x=10)
        println(other)
    end
    function foo(mi::ModelInstance, bar, baz::Int, other::Float64=4.0; x=10)::Any
        begin
            return foo(mi.cci, bar, baz, other; x = x)
        end
    end
    function foo(m::Model, bar, baz::Int, other::Float64=4.0; x=10)::Any
        begin
            return foo(m.mi, bar, baz, other; x = x)
        end
    end
end
=#
# macro delegates(args...)
#     funcdef = args[1]
#     args = collect(args[2:end])

#     parts = splitdef(funcdef)    
#     fnargs = parts[:args]
#     kwargs = parts[:kwargs]
    
#     result = quote $funcdef end     # emit function as written, then add delegation funcs

#     for delegee in filter(x -> !(x isa LineNumberNode), args)
#         (arg_name, arg_type, slurp, default)     = splitarg(fnargs[1])
#         (delegee_name, arg_type, slurp, default) = splitarg(delegee)

#         fnargs[1] = :($delegee_name.$arg_name)
#         call_args   = [:($name) for (name, atype, slurp, default) in map(splitarg, fnargs)]
#         call_kwargs = [:($name = $name) for (name, atype, slurp, default) in map(splitarg, kwargs)]

#         parts[:body] = quote return $(parts[:name])($(call_args...); $(call_kwargs...)) end
#         fnargs[1] = delegee
#         push!(result.args, MacroTools.combinedef(parts))
#     end

#     return esc(result)
# end
