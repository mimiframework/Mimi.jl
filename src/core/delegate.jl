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

    `@delegate compid(ci::CompositeComponentInstance, i::Int, f::Float64) => leaf`

expands to:

    `compid(ci::CompositeComponentInstance, i::Int, f::Float64) = compid(ci.leaf, i, f)`

If a second expression is given, it is spliced in, mainly to support the deprecated 
decache(m)". We might delete this feature, but why bother?
"""
macro delegate(ex, other=nothing)
    result = nothing
    other = (other === nothing ? [] : [other])  # make vector so $(other...) disappears if empty

    if (@capture(ex, fname_(varname_::T_, args__; kwargs__) => rhs_) || 
        @capture(ex, fname_(varname_::T_, args__) => rhs_))
        # @info "args: $args"
        new_args = delegated_args(args)

        if kwargs === nothing
            kwargs = new_kwargs = []
        else
            new_kwargs = delegated_args(kwargs)
        end

        result = quote
            function $fname($varname::$T, $(args...); $(kwargs...))
                retval = $fname($varname.$rhs, $(new_args...); $(new_kwargs...))
                $(other...)
                return retval
            end
        end
    end

    if result === nothing
        error("Calls to @delegate must be of the form 'func(obj, args...) => X', where X is a field of obj to delegate to'. Expression was: $ex")
    end
    return esc(result)
end
