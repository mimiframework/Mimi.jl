module metainfo

type MetaVariable
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::String
    unit::String
end

type MetaParameter
    name::Symbol
    datatype::DataType
    dimensions::Array{Any}
    description::String
    unit::String
end

type MetaDimension
    name::Symbol
end

type MetaComponent
    module_name::Symbol
    component_name::Symbol

    variables::Dict{Symbol,MetaVariable}
    parameters::Dict{Symbol,MetaParameter}
    dimensions::Dict{Symbol,MetaDimension}

    function MetaComponent(module_name::Symbol, component_name::Symbol)
        v = new(module_name, component_name, Dict{Symbol, MetaVariable}(), Dict{Symbol, MetaParameter}(), Dict{Symbol, MetaDimension}())
        return v
    end
end

const global _mimi_metainfo = Dict{Tuple{Symbol,Symbol},MetaComponent}()

function addcomponent(module_name::Symbol, component_name::Symbol)
    c = MetaComponent(module_name, component_name)
    _mimi_metainfo[(module_name, component_name)] = c
    nothing
end

function addvariable(module_name::Symbol, component_name::Symbol, name, datatype, dimensions, description, unit)
    c = _mimi_metainfo[(module_name, component_name)]

    v = MetaVariable(name, datatype, dimensions, description, unit)
    c.variables[name] = v
    nothing
end

function set_external_parameter(module_name::Symbol, component_name::Symbol, name, datatype, dimensions, description, unit)
    c = _mimi_metainfo[(module_name, component_name)]

    p = MetaParameter(name, datatype, dimensions, description, unit)
    c.parameters[name] = p
    nothing
end

function adddimension(module_name::Symbol, component_name::Symbol, name)
    c = _mimi_metainfo[(module_name, component_name)]

    d = MetaDimension(name)
    c.dimensions[name] = d
    nothing
end


function getallcomps()
    _mimi_metainfo
end

function generate_comp_expressions(module_name, component_name)
    parameters = values(_mimi_metainfo[(module_name, component_name)].parameters)
    variables = values(_mimi_metainfo[(module_name, component_name)].variables)
    dimensions = values(_mimi_metainfo[(module_name, component_name)].dimensions)

    arrayparameters = collect(filter(i->length(i.dimensions)>0, parameters))

    pname = string(component_name,"Parameters")

    ptypesignature = Expr(:curly, Symbol(pname), :T)
    pconstructor = Expr(:call, Expr(:curly, Symbol(pname), :T),  Expr(:(::), Expr(:curly, :Type, :T)))
    pnewargs = Expr(:curly, :new, :T)
    inewargs = Expr(:curly, :new, :T, :OFFSET, :DURATION)
    implconstructor = Expr(:call, Expr(:curly, Symbol(string(component_name, "Impl")), :T, :OFFSET, :DURATION), Expr(:(::), Expr(:curly, :Type, :T)), Expr(:(::), Expr(:curly, :Type, :OFFSET)), Expr(:(::), Expr(:curly, :Type, :DURATION)))
    for (i, p) in enumerate(arrayparameters)
        push!(ptypesignature.args, Symbol("OFFSET$i"))
        push!(ptypesignature.args, Symbol("DURATION$i"))

        push!(pconstructor.args[1].args, Symbol("OFFSET$i"))
        push!(pconstructor.args[1].args, Symbol("DURATION$i"))
        push!(pconstructor.args, Expr(:(::), Expr(:curly, :Type, Symbol("OFFSET$i"))))
        push!(pconstructor.args, Expr(:(::), Expr(:curly, :Type, Symbol("DURATION$i"))))

        push!(implconstructor.args[1].args, Symbol("OFFSET$i"))
        push!(implconstructor.args[1].args, Symbol("DURATION$i"))
        push!(implconstructor.args, Expr(:(::), Expr(:curly, :Type, Symbol("OFFSET$i"))))
        push!(implconstructor.args, Expr(:(::), Expr(:curly, :Type, Symbol("DURATION$i"))))

        push!(pnewargs.args, Symbol("OFFSET$i"))
        push!(pnewargs.args, Symbol("DURATION$i"))
    end
    pnewcall = Expr(:call, pnewargs)
    implnewcall = Expr(:call, inewargs)
    push!(implconstructor.args, :indices)

    println(ptypesignature)
    println(pconstructor)
    println(implconstructor)

    compexpr = quote
        using Mimi

        # Define type for parameters
        # type $(Symbol(string(component_name,"Parameters"))){T}
        type $(ptypesignature)
            $(begin
                x = Expr(:block)
                i=1
                for p in parameters
                    concreteParameterType = p.datatype == Number ? :T : p.datatype
                    offset = Symbol("OFFSET$i")
                    duration = Symbol("DURATION$i")

                    if length(p.dimensions)==0
                        push!(x.args, :($(p.name)::$(concreteParameterType)) )
                    elseif length(p.dimensions)==1
                        push!(x.args, :($(p.name)::OurTVector{$(concreteParameterType), $(offset), $(duration)}))
                        i += 1
                    elseif length(p.dimensions)==2
                        push!(x.args, :($(p.name)::OurTMatrix{$(concreteParameterType), $(offset), $(duration)}))
                        i+=1
                    else
                        push!(x.args, :($(p.name)::Array{$(concreteParameterType),$(length(p.dimensions))}) )
                        i+=1
                    end
                end
                x
            end)

            # function $(Symbol(string(component_name,"Parameters"))){T}(::Type{T})
                # new{T}()
            # end
            $(Expr(:function, $(pconstructor), $(pnewcall)))
        end

        # Define type for variables
        type $(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION}
            $(begin
                x = Expr(:block)
                for v in variables
                    concreteVariableType = v.datatype == Number ? :T : v.datatype

                    if length(v.dimensions)==0
                        push!(x.args, :($(v.name)::$(concreteVariableType)) )
                    elseif length(v.dimensions)==1
                        push!(x.args, :($(v.name)::OurTVector{$(concreteVariableType), OFFSET, DURATION}))
                    elseif length(v.dimensions)==2
                        push!(x.args, :($(v.name)::OurTMatrix{$(concreteVariableType), OFFSET, DURATION}))
                    else
                        push!(x.args, :($(v.name)::Array{$(concreteVariableType),$(length(v.dimensions))}) )
                    end
                end
                x
            end)

            function $(Symbol(string(component_name, "Variables"))){T, OFFSET, DURATION}(::Type{T}, ::Type{OFFSET}, ::Type{DURATION}, indices)
                s = new{T, OFFSET, DURATION}()

                $(begin
                    ep = Expr(:block)
                    for v in filter(i->length(i.dimensions)>0, variables)
                        concreteVariableType = v.datatype == Number ? :T : v.datatype

                        u = :(temp_indices = [])
                        for l in v.dimensions
                            if isa(l, Symbol)
                                push!(u.args[2].args, :(indices[$(QuoteNode(l))]))
                            elseif isa(l, Int)
                                push!(u.args[2].args, l)
                            else
                                error()
                            end
                        end
                        push!(ep.args,u)
                        push!(ep.args,:(s.$(v.name) = Array($(concreteVariableType),temp_indices...)))
                    end
                    ep
                end)

                return s
            end
        end


        # Define type for dimensions
        type $(Symbol(string(component_name,"Dimensions")))
            $(begin
                x = Expr(:block)
                for d in dimensions
                    push!(x.args, :($(d.name)::UnitRange{Int}) )
                end
                x
            end)

            function $(Symbol(string(component_name,"Dimensions")))(indices)
                s = new()
                $(begin
                    ep = Expr(:block)
                    for d in dimensions
                        push!(ep.args,:(s.$(d.name) = UnitRange{Int}(1,indices[$(QuoteNode(d.name))])))
                    end
                    ep
                end)
                return s
            end
        end

        # Define implementation typeof
        type $(Symbol(string(component_name, "Impl"))){T} <: Main.$(Symbol(module_name)).$(Symbol(component_name))
            nsteps::Int
            Parameters::$(ptypesignature)
            Variables::$(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION}
            Dimensions::$(Symbol(string(component_name,"Dimensions")))

            # function $(Symbol(string(component_name, "Impl"))){T}(::Type{T}, indices)
            #     s = new{T}()
            #     s.nsteps = indices[:time]
            #     s.Parameters = $(Symbol(string(component_name,"Parameters"))){T}(T)
            #     s.Dimensions = $(Symbol(string(component_name,"Dimensions")))(indices)
            #     s.Variables = $(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION}(T, indices)
            # end
            $(Expr(:function, $(implconstructor),
                :(s = $(implnewcall)),
                :(s.nsteps = indices[:time]),
                :(s.Parameters = $(pconstructor)),
                :(s.Dimensions = $(Symbol(string(component_name,"Dimensions")))(indices)),
                :(s.Variables = $(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION}(T, indices)),
                :(return s)
            ))

        end


    end
    return compexpr
end

end
