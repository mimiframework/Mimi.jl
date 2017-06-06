using Mimi
using Base.Test

############################################
# adder component without a different name #
############################################

model1 = Model()
setindex(model1, :time, collect(1:10))
addcomponent(model1, adder)

x = collect(1:10)
y = collect(2:2:22)

setparameter(model1, :adder, :input, x)
setparameter(model1, :adder, :add, y)

run(model1)

for i in collect(1:10)
    @test model1[:adder, :output][i] == 3i
end

##############################################
# test adder component with a different name #
##############################################

model2 = Model()
setindex(model2, :time, collect(1:10))
addcomponent(model2, adder, :compA)
setparameter(model2, :compA, :input, x)
setparameter(model2, :compA, :add, y)
run(model2)

for i in collect(1:10)
    @test model2[:compA, :output][i] == 3i
end
