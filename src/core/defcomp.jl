#
# This file is deprecated, but left here for reference for now.
#

function curr_module_name()
    return Base.module_name(current_module())
end

# text for constructing module name and component types from @defcomp name
const module_prefix = "_mimi_module_"
const comp_suffix = "Impl"

#
# TO DO: 
# - Change this to generate a struct with all the relevant data rather than with
#   expressions. Generate the expressions from the struct. Incorporate improvements
#   from defcomp_new using @capture.
# - Add the code from deftimestep_macro.jl to incorporate the timestep function into @defcomp
#
"""
    @defcomp name begin expressions... end

Define a new component.
"""
macro defcomp(name, ex)
    module_name = curr_module_name()

    resetvarsdef = Expr(:block) # don't accumulate expressions here
    metavardef = Expr(:block)
    metapardef = Expr(:block)
    metadimdef = Expr(:block)

    numarrayparams = 0

    for line in ex.args
        if line.head==:(=) && line.args[2].head==:call && line.args[2].args[1]==:Index
            dimensionName = line.args[1]

            push!(metadimdef.args, :(adddimension(curr_module_name(), $(Expr(:quote,name)), $(QuoteNode(dimensionName)) )))
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

                if length(parameterIndex) <= 2 && parameterIndex[1] == :time
                    numarrayparams += 1
                end

                pardims = Array{Any}(0)
                for l in parameterIndex
                    push!(pardims, l)
                end

                push!(metapardef.args, :(addparameter($(QuoteNode(module_name)), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), $(pardims), $(description), $(unit))))
            else
                push!(metapardef.args, :(addparameter($(QuoteNode(module_name)), $(Expr(:quote,name)), $(QuoteNode(parameterName)), $(esc(parameterType)), [], $(description), $(unit))))
            end

        elseif line.head == :(=) && line.args[2].head == :call && line.args[2].args[1 ]== :Variable
            if isa(line.args[1], Symbol)
                variableName = line.args[1]
                variableType = :Number
            elseif line.args[1].head == :(::)
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

                push!(metavardef.args, :(addvariable(curr_module_name(), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), $(vardims), $(description), $(unit))))

                if variableType == :Number
                    push!(resetvarsdef.args,:($(esc(Symbol("fill!")))(s.Variables.$(variableName),$(esc(Symbol("NaN"))))))
                end
            else
                push!(metavardef.args, :(addvariable(curr_module_name(), $(Expr(:quote,name)), $(QuoteNode(variableName)), $(esc(variableType)), [], $(description), $(unit))))

                if variableType == :Number
                    push!(resetvarsdef.args,:(s.Variables.$(variableName) = $(esc(Symbol("NaN")))))
                end
            end
        elseif line.head == :line
            # TBD: use MacroTools.rmlines() to get rid of these
        else
            error("Unknown expression.")
        end
    end

    module_name = Symbol(string(module_prefix, name))
    module_def = :(eval(current_module(), :(module $module_name end)))

    call_expr = Expr(:call,
                    Expr(:curly,
                        Expr(:., 
                            Expr(:., 
                                Expr(:., 
                                    :Main, 
                                    QuoteNode(Symbol(current_module()))), 
                                QuoteNode(module_name)),
                            QuoteNode(Symbol(string(name, comp_suffix)))),
                        :T, :OFFSET, :DURATION, :FINAL),
                    :indices)

    callsignature = Expr(:call, Expr(:curly, Symbol(name), :T, :OFFSET, :DURATION, :FINAL), :(::Type{T}), :(::Type{Val{OFFSET}}),:(::Type{Val{DURATION}}),:(::Type{Val{FINAL}}))
    for i in 1:numarrayparams
        offset   = Symbol("OFFSET$i")
        duration = Symbol("DURATION$i")

        push!(call_expr.args[1].args, offset)
        push!(call_expr.args[1].args, duration)

        push!(callsignature.args[1].args, offset)
        push!(callsignature.args[1].args, duration)
        push!(callsignature.args, :(::Type{Val{$(QuoteNode(offset))}}))
        push!(callsignature.args, :(::Type{Val{$(QuoteNode(duration))}}))

    end
    push!(callsignature.args, :indices)
    # println(call_expr)
    # println(callsignature)
    # println(Expr(:function, callsignature, call_expr))

    return gen_component_expr(name, module_def, resetvarsdef, metavardef, metapardef, metadimdef, callsignature, call_expr)
end

#
# TODO: this needs to be largely rewritten. Should take a struct with all the values rather than all these args.
#
function gen_component_expr(name, module_def, resetvarsdef, metavardef, metapardef, metadimdef, callsignature, call_expr)
    expr = quote

        abstract type $name <: Mimi.ComponentState end

        import Mimi.run_timestep
        import Mimi.init
        import Mimi.resetvariables

        function resetvariables(s::$name) 
            $resetvarsdef
        end

        # ComponentKey supplies current module name when only the component name is given
        key = ComponentKey($(QuoteNode(name)))

        # Create an empty component
        addcomponent(key)

        $metavardef
        $metapardef
        $metadimdef
        $module_def

        eval($(esc(Symbol(string(module_prefix, name)))), generate_comp_expressions(key))

        # RP: not sure what DA was attempting to do here:
        # callsignature.args[1].args[1] = $esc(Symbol(name)) # DA: how to do this?

        function $name{$(callsignature.args[1].args[2:end]...)}($(callsignature.args[2:end]...))
            $call_expr
        end
    end
    return expr
end
