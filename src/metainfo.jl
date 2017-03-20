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
    quote
        using Mimi

        # Define type for parameters
        type $(Symbol(string(component_name,"Parameters"))){T}
            $(begin
                x = Expr(:block)
                for p in parameters
                    concreteParameterType = p.datatype == Number ? :T : p.datatype

                    if length(p.dimensions)==0
                        push!(x.args, :($(p.name)::$(concreteParameterType)) )
                    else
                        push!(x.args, :($(p.name)::Array{$(concreteParameterType),$(length(p.dimensions))}) )
                    end
                end
                x
            end)

            function $(Symbol(string(component_name,"Parameters"))){T}(::Type{T})
                new{T}()
            end
        end

        # Define type for variables
        type $(Symbol(string(component_name,"Variables"))){T}
            $(begin
                x = Expr(:block)
                for v in variables
                    concreteVariableType = v.datatype == Number ? :T : v.datatype

                    if length(v.dimensions)==0
                        push!(x.args, :($(v.name)::$(concreteVariableType)) )
                    else
                        push!(x.args, :($(v.name)::Array{$(concreteVariableType),$(length(v.dimensions))}) )
                    end
                end
                x
            end)

            function $(Symbol(string(component_name, "Variables"))){T}(::Type{T}, indices)
                s = new{T}()

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
            Parameters::$(Symbol(string(component_name,"Parameters"))){T}
            Variables::$(Symbol(string(component_name,"Variables"))){T}
            Dimensions::$(Symbol(string(component_name,"Dimensions")))

            function $(Symbol(string(component_name, "Impl"))){T}(::Type{T}, indices)
                s = new{T}()
                s.nsteps = indices[:time]
                s.Parameters = $(Symbol(string(component_name,"Parameters"))){T}(T)
                s.Dimensions = $(Symbol(string(component_name,"Dimensions")))(indices)
                s.Variables = $(Symbol(string(component_name,"Variables"))){T}(T, indices)
                return s
            end
        end


    end
end

end
