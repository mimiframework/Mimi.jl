function replace_dots(e)
    if isa(e, Expr) && e.head == Symbol("=") && e.args[1].head == Symbol(".")
        return :( set_property!( $(e.args[1].args[1]), Val($(e.args[1].args[2])), $(e.args[2]) ) )
    elseif isa(e, Expr) && e.head == Symbol(".")
        return :( get_property!( $(e.args[1]), Val($(e.args[2])) ) )
    else
        return e
    end
end

# This is a temporary macro until we move the run_timestep definition
# into the @defcomp macro. For now this macro can be put before a
# `function run_timestep` definition.
macro deftimestep(compname, ex)
    module_name = Symbol(string(current_module()))
    q = quote
        function run_timestep(::Val{$(QuoteNode(module_name))}, ::Val{$(QuoteNode(compname))}, $(ex.args[1].args[2]),$(ex.args[1].args[3]),$(ex.args[1].args[4]),$(ex.args[1].args[5]))
            $(MacroTools.prewalk(replace_dots,ex. args[2]))
        end
    end
    # println(q)
    return q
end
