using Base.test
using Mimi

@defcomp A begin
  varA = Variable()
  parA = Parameter()
end

@defcomp B begin
  varB = Variable()
  parB = Parameter()
end

m = Model()
addcomponent(m, A)
addcomponent(m, B)

connectparameter(m, :A, :parA, :B, :varB)

@test length(m.nodes)==2
@test length(m.edges)==1
@test get_connections(m, :A, :INCOMING)[0].source_component_name == :B
@test length(get_connections(m, :B, :INCOMING)) == 0
