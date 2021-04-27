module TestMultiplier

using Mimi
using Test

############################################
# adder component without a different name #
############################################

model1 = Model()
set_dimension!(model1, :time, 1:10)
add_comp!(model1, Mimi.multiplier)

x = collect(1:10)
y = collect(2:2:20)

set_param!(model1, :multiplier, :input, x)
set_param!(model1, :multiplier, :multiply, y)

run(model1)

@test model1[:multiplier, :output] == x.*y

##############################################
# test adder component with a different name #
##############################################

model2 = Model()
set_dimension!(model2, :time, 1:10)
add_comp!(model2, Mimi.multiplier, :compA)
set_param!(model2, :compA, :input, x)
set_param!(model2, :compA, :multiply, y)
run(model2)

@test model2[:compA, :output] == x.*y

end #module
