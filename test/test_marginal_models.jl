using Mimi
using Base.Test

@defcomp compA begin
    varA = Variable(index=[time])
    parA = Parameter(index=[time])
end

function run_timestep(state::compA, t::Int)
    v = state.Variables
    p = state.Parameters

    v.varA[t] = p.parA[t]
end

x1 = collect(1:10)
x2 = collect(2:2:22)

model1 = Model()
setindex(model1, :time, collect(1:10))
addcomponent(model1, compA)
setparameter(model1, :compA, :parA, x1)

model2 = Model()
setindex(model2, :time, collect(1:10))
addcomponent(model2, compA)
setparameter(model2, :compA, :parA, x2)

mm = MarginalModel(model1, model2, .5)

run(model1)
run(model2)

for i in collect(1:10)
    @test mm[:compA, :varA][i] == 2*i 
end
