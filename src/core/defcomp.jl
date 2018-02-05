"""
    @defcomp name begin

Define a new component.
"""
macro defcomp(name, ex)
    resetvarsdef = Expr(:block)

    metavardef = Expr(:block)
    metapardef = Expr(:block)
    metadimdef = Expr(:block)

    numarrayparams = 0

    for line in ex.args
        if line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Index
            dimensionName = line.args[1]

            push!(metadimdef.args, :(metainfo.adddimension(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(dimensionName)) )))
        elseif line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Parameter
            if isa(line.args[1], Symbol)
                parameterName = line.args[1]
                parameterType = :Number
            elseif line.args[1].head==:(::)
                parameterName = line.args[1].args[1]
                parameterType = line.args[1].args[2]
            else
                error()
            end

            kws = collectkw(line.args[2].args)

            # Get description and unit, if provided
            description = get(kws, :description, "")
            unit = get(kws, :unit, "")

            if haskey(kws, :index)
                parameterIndex = kws[:index].args

                if length(parameterIndex)<=2 && parameterIndex[1]==:time
                    numarrayparams += 1
                end

                pardims = Array{Any}(0)
                for l in parameterIndex
                    push!(pardims, l)
                end

                push!(metapardef.args, :(metainfo.set_external_parameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), $(pardims), $(description), $(unit))))
            else
                push!(metapardef.args, :(metainfo.set_external_parameter(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), [], $(description), $(unit))))
            end
        elseif line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Variable
            if isa(line.args[1], Symbol)
                variableName = line.args[1]
                variableType = :Number
            elseif line.args[1].head==:(::)
                variableName = line.args[1].args[1]
                variableType = line.args[1].args[2]
            else
                error()
            end

            kws = collectkw(line.args[2].args)

            # Get description and unit, if provided
            description = get(kws, :description, "")
            unit = get(kws, :unit, "")

            if haskey(kws, :index)
                variableIndex = kws[:index].args

                vardims = Array{Any}(0)
                for l in variableIndex
                    push!(vardims, l)
                end

                push!(metavardef.args, :(metainfo.addvariable(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), $(vardims), $(description), $(unit))))

                if variableType==:Number
                    push!(resetvarsdef.args,:($(esc(Symbol("fill!")))(s.Variables.$(variableName),$(esc(Symbol("NaN"))))))
                end
            else
                push!(metavardef.args, :(metainfo.addvariable(module_name(current_module()), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), [], $(description), $(unit))))

                if variableType==:Number
                    push!(resetvarsdef.args,:(s.Variables.$(variableName) = $(esc(Symbol("NaN")))))
                end
            end
        elseif line.head==:line
        else
            error("Unknown expression.")
        end
    end

    module_def = :(eval(current_module(), :(module temporary_name end)))
    module_def.args[3].args[1].args[2] = Symbol(string("_mimi_implementation_", name))

    call_expr = Expr(:call,
        Expr(:curly,
            Expr(:., Expr(:., Expr(:., :Main, QuoteNode(Symbol(current_module()))), QuoteNode(Symbol(string("_mimi_implementation_", name)))), QuoteNode(Symbol(string(name,"Impl")))),
            :T, :OFFSET, :DURATION, :FINAL
            ),
        :indices
        )

    callsignature = Expr(:call, Expr(:curly, Symbol(name), :T, :OFFSET, :DURATION, :FINAL), :(::Type{T}), :(::Type{Val{OFFSET}}),:(::Type{Val{DURATION}}),:(::Type{Val{FINAL}}))
    for i in 1:numarrayparams
        push!(call_expr.args[1].args, Symbol("OFFSET$i"))
        push!(call_expr.args[1].args, Symbol("DURATION$i"))

        push!(callsignature.args[1].args, Symbol("OFFSET$i"))
        push!(callsignature.args[1].args, Symbol("DURATION$i"))
        push!(callsignature.args, :(::Type{Val{$(Symbol("OFFSET$i"))}}))
        push!(callsignature.args, :(::Type{Val{$(Symbol("DURATION$i"))}}))

    end
    push!(callsignature.args, :indices)
    # println(call_expr)
    # println(callsignature)
    # println(Expr(:function, callsignature, call_expr))

    x = quote

        abstract type $(esc(Symbol(name))) <: Mimi.ComponentState end

        import Mimi.run_timestep
        import Mimi.init
        import Mimi.resetvariables

        # why not just this: function resetvariables(s::$name) $resetvarsdef end  ?
        function $(esc(Symbol("resetvariables")))(s::$(esc(Symbol(name))))
            $(resetvarsdef)
        end

        metainfo.addcomponent(module_name(current_module()), $(Expr(:quote,name)))
        $(metavardef)
        $(metapardef)
        $(metadimdef)

        $(module_def)
        eval($(esc(Symbol(string("_mimi_implementation_", name)))), metainfo.generate_comp_expressions(module_name(current_module()), $(Expr(:quote,name))))

        # callsignature.args[1].args[1] = $esc(Symbol(name)) # how to do this?
        $(Expr(:function, Expr(:call, Expr(:curly, esc(Symbol(name)), callsignature.args[1].args[2:end]...), callsignature.args[2:end]...), call_expr))

    end

    x
end