
module test

struct ComponentInstanceParameters{T <: NamedTuple}
    nt::T                                           
end

struct ComponentInstanceVariables{T <: NamedTuple}
    nt::T                                           
end

struct ComponentInstance{V <: NamedTuple, P <: NamedTuple}
    vars::ComponentInstanceVariables{V}
    params::ComponentInstanceParameters{P}
end

function ComponentInstanceParameters(names, types, values)
    NT = NamedTuple{names, types}
    ComponentInstanceParameters{NT}(NT(values))
end

@inline function Base.getproperty(obj::ComponentInstanceParameters{T}, name::Symbol) where {T}
    nt = getfield(obj, :nt)
    return fieldtype(T, name) <: Ref ? getproperty(nt, name)[] : getproperty(nt, name)
end


using BenchmarkTools

ci = ComponentInstanceParameters((a=1., b=2.))

foo(ci) = ci.a + ci.b

println("@btime ci.a + ci.b")
@btime foo($ci)

function run_timestep(p, v, d, t)
end

end # module
