# DEPRECATED. Delete this once integration with defcomp is completed.

#
# Main> MacroTools.prewalk(replace_dots, :(p.foo[1,2] = v.bar))
# :((get_property(p, Val(:foo)))[1, 2] = get_property(v, Val(:bar)))
#
# Main> MacroTools.prewalk(replace_dots, :(p.foo = v.bar[1]))
# :(set_property!(p, Val(:foo), (get_property(v, Val(:bar)))[1]))
#
function replace_dots(ex)
    if @capture(ex, obj_.field_ = rhs_)
        return :(set_property!($obj, Val($(QuoteNode(field))), $rhs))
    
    elseif @capture(ex, obj_.field_)
        return :(get_property($obj, Val($(QuoteNode(field)))))

    elseif @capture(ex, obj_.field_[args__] = rhs_)
        return :(get_property($obj, Val($(QuoteNode(field))))[$(args...)] = $rhs)

    elseif @capture(ex, obj_.field_[args__])
        return :(get_property($obj, Val($(QuoteNode(field))))[$(args...)])

    else
        return ex
    end
end

macro deftimestep(compname, ex)
    module_name = module_name(current_module())
    if ! @capture(ex, function run(args__) body__ end)
        error("Badly formatted timestep function: $ex")
    end

    func = :(
        function run_timestep(::Val{$(QuoteNode(module_name))}, ::Val{$(QuoteNode(compname))}, $(args...))
            $(MacroTools.prewalk(replace_dots, body)...)
        end
    )
    # println(func)
    return func
end
