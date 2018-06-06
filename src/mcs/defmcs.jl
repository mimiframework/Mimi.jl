# For generating symbols that work as dataframe column names
global _rvnum = 0

function _make_rvname(name)
    global _rvnum += 1
    return Symbol("$(name)_$(_rvnum)")
end

macro defmcs(expr)
    let # to make vars local to each macro invocation
        local _rvs::Vector{RandomVariable} = []
        local _corrs::Vector{CorrelationSpec} = []
        local _transforms::Vector{TransformSpec} = []
        local _saves::Vector{Tuple} = []

        # distilled into a function since it's called from two branches below
        function saverv(rvname, distname, distargs)
            args = Tuple(distargs)
            push!(_rvs, RandomVariable(rvname, eval(distname)(args...)))
        end

        @capture(expr, elements__)
        for elt in elements
            # Meta.show_sexpr(elt)
            # println("")
            # e.g.,  rv(name1) = Normal(10, 3)
            if @capture(elt, rv(rvname_) = distname_(distargs__))
                saverv(rvname, distname, distargs)

            elseif @capture(elt, save(vars__))
                for var in vars
                    # println("var: $var")
                    if @capture(var, comp_.datum_)
                        push!(_saves, (comp, datum))
                    else
                        error("Save arg spec must be of the form comp_name.datum_name; got ($var)")
                    end
                end

            # e.g., name1:name2 = 0.7
            elseif @capture(elt, name1_:name2_ = value_)
                push!(_corrs, (name1, name2, value))

            # e.g., ext_var5[2010:2050, :] *= name2
            # A bug in Macrotools prevents this shorter expression from working:
            # elseif @capture(elt, ((extvar_  = rvname_Symbol) | 
            #                       (extvar_ += rvname_Symbol) |
            #                       (extvar_ *= rvname_Symbol) |
            #                       (extvar_  = distname_(distargs__)) | 
            #                       (extvar_ += distname_(distargs__)) |
            #                       (extvar_ *= distname_(distargs__))))
            elseif (@capture(elt, extvar_  = rvname_Symbol) ||
                    @capture(elt, extvar_ += rvname_Symbol) ||
                    @capture(elt, extvar_ *= rvname_Symbol) ||
                    @capture(elt, extvar_  = distname_(distargs__)) ||
                    @capture(elt, extvar_ += distname_(distargs__)) ||
                    @capture(elt, extvar_ *= distname_(distargs__)))

                # For "anonymous" RVs, e.g., ext_var2[2010:2100, :] *= Uniform(0.8, 1.2), we
                # gensym a name based on the external var name and process it as a named RV.
                if rvname == nothing
                    param_name = @capture(extvar, name_[args__]) ? name : extvar
                    rvname = _make_rvname(param_name)
                    saverv(rvname, distname, distargs)
                end

                op = elt.head
                if @capture(extvar, name_[args__])
                    # println("Ref:  $name, $args")        
                    # Meta.show_sexpr(extvar)
                    # println("")

                    # if extvar.head == :ref, extvar.args must be one of:
                    # - a scalar value, e.g., name[2050] => (:ref, :name, 2050)
                    #   convert to tuple of dimension specifiers (:name, 2050)
                    # - a slice expression, e.g., name[2010:2050] => (:ref, :name, (:(:), 2010, 2050))
                    #   convert to (:name, 2010:2050) [convert it to actual UnitRange instance]
                    # - a tuple of symbols, e.g., name[(US, CHI)] => (:ref, :name, (:tuple, :US, :CHI))
                    #   convert to (:name, (:US, :CHI))
                    # - combinations of these, e.g., name[2010:2050, (US, CHI)] => (:ref, :name, (:(:), 2010, 2050), (:tuple, :US, :CHI))
                    #   convert to (:name, 2010:2050, (:US, :CHI))
                    dims = Vector{Any}()
                    for arg in args
                        # println("Arg: $arg")

                        if @capture(arg, i_Int)  # scalar (must be integer)
                            # println("arg is Int")
                            dim = i

                        elseif @capture(arg, first_Int:last_)   # last can be an int or 'end', which is converted to 0
                            # println("arg is range")
                            last = last == :end ? 0 : last
                            dim = first:last

                        elseif @capture(arg, first_Int:step_:last_)
                            # println("arg is step range")
                            last = last == :end ? 0 : last
                            dim = first:step:last

                        elseif @capture(arg, s_Symbol)
                            if arg == :(:)
                                # println("arg is Colon")
                                dim = Colon()
                            else
                                # println("arg is Symbol")
                                dim = s
                            end

                        elseif isa(arg, Expr) && arg.head == :tuple  # tuple of Symbols (@capture didn't work...)
                            dim = convert(Vector{Symbol}, arg.args)

                        else
                            error("Unrecognized stochastic parameter specification: $arg")
                        end
                        push!(dims, dim)
                        # println("dims = $dims")
                    end

                    push!(_transforms, TransformSpec(name, op, rvname, dims))
                else
                    push!(_transforms, TransformSpec(extvar, op, rvname))
                end
            else
                error("Unrecognized expression '$elt' in @defmcs")
            end
        end
        return MonteCarloSimulation(_rvs, _transforms, _corrs, _saves)
    end
end