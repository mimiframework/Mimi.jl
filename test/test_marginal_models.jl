using Mimi
using Base.Test

@defcomp compA begin
    varA = Variable(index=[time])
    parA = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.varA[t] = p.parA[t]
    end
end

x1 = collect(1:10)
x2 = collect(2:2:20)

model1 = Model()
set_dimension!(model1, :time, collect(1:10))
addcomponent(model1, compA)
set_parameter!(model1, :compA, :parA, x1)

mm = MarginalModel(model1, .5)

model2 = mm.marginal
set_parameter!(model2, :compA, :parA, x2)

run(mm)

for i in collect(1:10)
    @test mm[:compA, :varA][i] == 2*i
end
