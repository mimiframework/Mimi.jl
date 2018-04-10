function lint_helper(ex::Expr, ctx)
    if ex.head == :macrocall
        if ex.args[1] == Symbol("@defcomp")
            push!(ctx.callstack[end].types, ex.args[2])
            return true
        end
    end
    return false
end
