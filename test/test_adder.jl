using Mimi
using Base.Test

model = Model()
setindex(model, :time, collect(1:10))
addcomponent(model, adder, :compA)

x = collect(1:10)
y = collect(2:2:22)

setparameter(model, :compA, :input, x)
setparameter(model, :compA, :add, y)

run(model)

for i in collect(1:10)
    #@test model[:adder, :output][i] == 3i
    println(model[:compA, :output][i])
end
