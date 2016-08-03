#tests the framework of components and connections without actually running the model

using Base.Test
using Mimi

@defcomp A begin
  varA = Variable(index=[time])
  parA = Parameter(index=[time])
end

@defcomp B begin
  varB = Variable(index=[time])
  parB = Parameter(index=[time])
end

m = Model()
setindex(m, :time, [2015:5:2110])

addcomponent(m, A)
addcomponent(m, B)

connectparameter(m, :A, :parA, :B, :varB)

@test length(m.components)==2
@test length(m.connections)==1
@test get_connections(m, :A, :incoming)[1].source_component_name == :B
@test length(get_connections(m, :B, :incoming)) == 0
@test get_connections(m, :B, :outgoing)[1].target_component_name == :A
@test length(get_connections(m, :A, :all)) == 1
