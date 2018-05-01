using Mimi
using BenchmarkTools

@defcomp foo begin
    in = Parameter(index=[time])
    out = Variable(index=[time])

    function run_timestep(p,v,d,t)
      v.out[t] = p.in[t]
    end
end

m = Model()

set_dimension!(m, :time, [1,2,3])

addcomponent(m, foo)


set_parameter!(m, :foo, :in, [3.,6.,10.])

run(m)

@benchmark run(m)

function Mimi.run_timestep(::Val{:Main}, ::Val{:foo}, p::Mimi.ComponentInstanceParameters, v::Mimi.ComponentInstanceVariables, d::Dict{Symbol, Vector{Int}}, t::Union{Int64, Mimi.Timestep})
    println("WE ARE IN $t")
    println(typeof(p))
    a = Mimi.getproperty(p, Val(:in))
    # aaa = p.values
    # aa = aaa[1]
    # a = aa[]
    b = a[t]
    (Mimi.getproperty(v, Val(:out)))[t] = b
end

# Base.arrayref(Core.getfield(Core.getfield(Base.getfield(getfield(p, :values), 1), :x), :data), t)

p = m.mi.components[:foo].parameters

v = m.mi.components[:foo].variables

@code_warntype Mimi.run_timestep(Val(:Main), Val(:foo), p, v, Dict{Symbol,Vector{Int}}(), 2)

cl = Mimi.make_clock(m.mi, 4, [1,2,3,4])

@code_warntype run_timestep(Val(:Main),Val(:foo), m.mi.components[:foo], cl)