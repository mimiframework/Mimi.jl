using Mimi
using Base.Test

reset_compdefs()

############################################
# adder component without a different name #
############################################

model1 = Model()
set_dimension!(model1, :time, 1:10)
addcomponent(model1, adder)

x = collect(1:10)
y = collect(2:2:20)

set_parameter!(model1, :adder, :input, x)
set_parameter!(model1, :adder, :add, y)

run(model1)

for i in 1:10
    @test model1[:adder, :output][i] == 3i
end

##############################################
# test adder component with a different name #
##############################################

model2 = Model()
set_dimension!(model2, :time, 1:10)
addcomponent(model2, adder, :compA)
set_parameter!(model2, :compA, :input, x)
set_parameter!(model2, :compA, :add, y)
run(model2)

for i in 1:10
    @test model2[:compA, :output][i] == 3i
end
