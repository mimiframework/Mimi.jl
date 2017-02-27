#tests the framework of components and connections without actually running the model

using Base.Test
using Mimi

@defcomp A begin
  varA = Variable(index=[time])
  parA = Parameter()
end

@defcomp B begin
  varB = Variable()
end

@defcomp C begin
  varC = Variable()
  parC = Parameter()
end

m = Model()
setindex(m, :time, collect(2015:5:2100))

addcomponent(m, A)
addcomponent(m, B, before=:A)
@test_throws ErrorException addcomponent(m, C, after=:A, before=:B)
addcomponent(m, C, after=:B)

@test length(Mimi.show_unconnected_parameters(m))==2

connectparameter(m, :A, :parA, :B, :varB)

@test Mimi.show_unconnected_parameters(m)[1]==(:C,:parC)

@test length(m.components2)==3
@test length(m.internal_parameter_connections)==1
@test Mimi.get_connections(m, :A, :incoming)[1].source_component_name == :B
@test length(Mimi.get_connections(m, :B, :incoming)) == 0
@test Mimi.get_connections(m, :B, :outgoing)[1].target_component_name == :A
@test length(Mimi.get_connections(m, :A, :all)) == 1

#connectparameter(m, :A, :parA, :C, :varC)
connectparameter(m, :C, :parC, :B, :varB)
@test length(m.internal_parameter_connections)==2

@test length(Mimi.show_unconnected_parameters(m))==0

#############################################
#  Tests for connecting scalar parameters   #
#############################################

function run_timestep(s::C, t::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    if t==1
        v.varC = 1
    elseif t==10
        v.varC = 10
    end
end

function run_timestep(s::B, t::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    if t==1
        v.varB = 1
    elseif t==10
        v.varB = 10
    end
end

function run_timestep(s::A, t::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    v.varA[t] = p.parA
end

run(m)

for t in range(1, 9)
    @test m[:A, :varA][t] == 1
end

for t in range(10, m.indices_counts[:time]-10)
    @test m[:A, :varA][t] == 10
end

@test m[:A, :parA] == 10
@test_throws ErrorException m[:A, :xx]

@test getindexcount(m, :time) == 18

a = getindexvalues(m, :time)
for i in range(1,18)
    @test a[i] == 2010 + 5*i
end

@test getindexlabels(m, :A, :varA)[1] == :time
@test length(getindexlabels(m, :A, :parA)) == 0
