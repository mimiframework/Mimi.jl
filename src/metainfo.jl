module metainfo
using DataStructures

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

    variables::OrderedDict{Symbol,MetaVariable}
    parameters::OrderedDict{Symbol,MetaParameter}
    dimensions::OrderedDict{Symbol,MetaDimension}

    function MetaComponent(module_name::Symbol, component_name::Symbol)
        v = new(module_name, component_name, OrderedDict{Symbol, MetaVariable}(), OrderedDict{Symbol, MetaParameter}(), OrderedDict{Symbol, MetaDimension}())
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

    arrayparameters = collect(filter(i->(length(i.dimensions)>0 && length(i.dimensions)<=2 && i.dimensions[1]==:time), parameters))

    pname = string(component_name,"Parameters")

    ptypesignature = Expr(:curly, Symbol(pname), :T)
    implconstructor = Expr(:call, Symbol(string(component_name, "Impl")))
    implsignature = Expr(:curly, Symbol((string(component_name, "Impl"))), :T, :OFFSET, :DURATION, :FINAL)
    for (i, p) in enumerate(arrayparameters)
        push!(ptypesignature.args, Symbol("OFFSET$i"))
        push!(ptypesignature.args, Symbol("DURATION$i"))

        push!(implsignature.args, Symbol("OFFSET$i"))
        push!(implsignature.args, Symbol("DURATION$i"))
    end
    push!(implconstructor.args, :indices)
    # println(ptypesignature)
    # println(implsignature)
    # println(implconstructor)

    compexpr = quote
        using Mimi

        # Define type for parameters
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
                    elseif length(p.dimensions)==1 && p.dimensions[1]==:time
                        push!(x.args, :($(p.name)::TimestepVector{$(concreteParameterType), $(offset), $(duration)}))
                        i += 1
                    elseif length(p.dimensions)==2 && p.dimensions[1]==:time
                        push!(x.args, :($(p.name)::TimestepMatrix{$(concreteParameterType), $(offset), $(duration)}))
                        i+=1
                    else
                        push!(x.args, :($(p.name)::Array{$(concreteParameterType),$(length(p.dimensions))}) )
                    end
                end
                x
            end)

            function $(Symbol(string(component_name,"Parameters")))()
                new()
            end

        end

        # Define type for variables
        type $(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION, FINAL}
            $(begin
                x = Expr(:block)
                for v in variables
                    concreteVariableType = v.datatype == Number ? :T : v.datatype

                    if length(v.dimensions)==0
                        push!(x.args, :($(v.name)::$(concreteVariableType)) )
                    elseif length(v.dimensions)==1 && v.dimensions[1]==:time
                        push!(x.args, :($(v.name)::TimestepVector{$(concreteVariableType), OFFSET, DURATION}))
                    elseif length(v.dimensions)==2 && v.dimensions[1]==:time
                        push!(x.args, :($(v.name)::TimestepMatrix{$(concreteVariableType), OFFSET, DURATION}))
                    else
                        push!(x.args, :($(v.name)::Array{$(concreteVariableType),$(length(v.dimensions))}))
                    end
                end
                x
            end)

            function $(Symbol(string(component_name, "Variables")))(indices)
                s = new()

                $(begin
                    ep = Expr(:block)
                    for v in filter(i->length(i.dimensions)>0, variables)
                        concreteVariableType = v.datatype == Number ? :T : v.datatype

                        useTarray = false
                        u = :(temp_indices = [])
                        for (i,l) in enumerate(v.dimensions)
                            if isa(l, Symbol) && l==:time && i==1
                                push!(u.args[2].args, :(Int((FINAL-OFFSET)/DURATION + 1)))
                                useTarray = true
                            elseif isa(l, Symbol)
                                push!(u.args[2].args, :(indices[$(QuoteNode(l))]))
                            elseif isa(l, Int)
                                push!(u.args[2].args, l)
                            else
                                error()
                            end
                        end
                        push!(ep.args,u)
                        if length(u.args[2].args) == 1 && useTarray
                            push!(ep.args,:(s.$(v.name) = TimestepVector{$concreteVariableType, OFFSET, DURATION}(temp_indices[1])))
                        elseif length(u.args[2].args) == 2 && useTarray
                            push!(ep.args,:(s.$(v.name) = TimestepMatrix{$concreteVariableType, OFFSET, DURATION}(temp_indices[1], temp_indices[2])))
                        else
                            push!(ep.args,:(s.$(v.name) = Array($(concreteVariableType),temp_indices...)))
                        end
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
        type $(implsignature) <: Main.$(Symbol(module_name)).$(Symbol(component_name))
            nsteps::Int
            Parameters::$(ptypesignature)
            Variables::$(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION, FINAL}
            Dimensions::$(Symbol(string(component_name,"Dimensions")))

            $(Expr(:function, implconstructor,
                :(return new(
                    indices[:time],
                    $(ptypesignature)(),
                    $(Symbol(string(component_name,"Variables"))){T, OFFSET, DURATION, FINAL}(indices),
                    $(Symbol(string(component_name,"Dimensions")))(indices)
                ))

            ))

        end


    end
    # println(compexpr)
    return compexpr
end

end
