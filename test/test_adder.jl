module TestAdder

using Mimi
using Test

############################################
# adder component without a different name #
############################################

model1 = Model()
set_dimension!(model1, :time, 1:10)
add_comp!(model1, Mimi.adder)

x = collect(1:10)
y = collect(2:2:20)

update_param!(model1, :adder, :input, x)
update_param!(model1, :adder, :add, y)

run(model1)

for i in 1:10
    @test model1[:adder, :output][i] == 3i
end

##############################################
# test adder component with a different name #
##############################################

model2 = Model()
set_dimension!(model2, :time, 1:10)
add_comp!(model2, Mimi.adder, :compA)
update_param!(model2, :compA, :input, x)
update_param!(model2, :compA, :add, y)
run(model2)

for i in 1:10
    @test model2[:compA, :output][i] == 3i
end

end #module
