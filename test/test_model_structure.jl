module TestModelStructure

#tests the framework of components and connections

using Base.Test
using Mimi

import Mimi: 
    add_connector_comps, connect_parameter, unconnected_params, set_dimension, 
    reset_compdefs, numcomponents, get_connections, internal_param_conns, dim_count

reset_compdefs()

@defcomp A begin
    varA = Variable(index=[time])
    parA = Parameter()
    
    function run(p, v, d, t::Int)
        println("A.run($t)")
        v.varA[t] = p.parA
        println("varA[t] = $(v.varA[t])")
    end
end

@defcomp B begin
    varB = Variable()

    function run(p, v, d, t::Int)
        println("B.run($t)")

        if t < 10
            v.varB = 1
        else
            v.varB = 10
        end
        println("varB = $(v.varB)")
    end
end


@defcomp C begin
    varC = Variable()
    parC = Parameter()

    function run(p, v, d, t::Int)
        println("C.run($t)")
        v.varC = p.parC
        println("varC = $(v.varC)")
    end
end

# @defmodel m begin
#     index[time] = 2015:5:2100
#     component(A)
# end

m = Model()
set_dimension(m, :time, 2015:5:2100)

addcomponent(m, A)
addcomponent(m, B, before=:A)
addcomponent(m, C, after=:B)

connect_parameter(m, :A, :parA, :C, :varC)

unconn = unconnected_params(m)
@test length(unconn) == 1
@test unconn[1] == (:C, :parC)

connect_parameter(m, :C=>:parC, :B=>:varB)

@test_throws ErrorException addcomponent(m, C, after=:A, before=:B)


@test numcomponents(m.md) == 3

@test length(internal_param_conns(m)) == 2
@test get_connections(m, :A, :incoming)[1].src_comp_name == :C

@test length(get_connections(m, :B, :incoming)) == 0
@test get_connections(m, :B, :outgoing)[1].dst_comp_name == :C

@test length(get_connections(m, :A, :all)) == 1

#connect_parameter(m, :A, :parA, :C, :varC)
#connect_parameter(m, :C, :parC, :B, :varB)      # TBD: don't create redundant connection!

@test length(internal_param_conns(m)) == 3

@test length(unconnected_params(m)) == 0

#############################################
#  Tests for connecting scalar parameters   #
#############################################

add_connector_comps(m)
run(m)

for t in 1:9
    @test m[:A, :varA][t] == 1
end

for t in 10:dim_count(m.md, :time)
    @test m[:A, :varA][t] == 10
end

##########################
#   tests for indexing   #
##########################

@test dim_count(m.md, :time) == 18

@test m[:A, :parA] == 10
@test_throws ErrorException m[:A, :xx]

a = dim_keys(m, :time)
for i in 1:18
    @test a[i] == 2010 + 5*i
end

@test dimensions(m, :A, :varA)[1] == :time
@test length(dimensions(m, :A, :parA)) == 0

################################
#  tests for delete! function  #
################################

@test_throws ErrorException delete!(m, :D)
@test length(m.internal_parameter_connections) == 2
delete!(m, :A)
@test length(m.internal_parameter_connections) == 1
@test !(:A in components(m))
@test length(components(m)) == 2

#######################################
#   Test check for unset parameters   #
#######################################

@defcomp D begin
  varD = Variable(index=[time])
  parD = Parameter()
end

addcomponent(m, D)
@test_throws ErrorException Mimi.build(m)


end # module
