module TestModelStructure

#tests the framework of components and connections

using Base.Test
using Mimi

import Mimi: 
    add_connector_comps, connect_parameter, unconnected_params, set_dimension!, 
    reset_compdefs, numcomponents, get_connections, internal_param_conns, dim_count, 
    modeldef, modelinstance

reset_compdefs()

@defcomp A begin
    varA::Int = Variable(index=[time])
    parA::Int = Parameter()
    
    function run_timestep(p, v, d, t)
        v.varA[t] = p.parA
    end
end

@defcomp B begin
    varB::Int = Variable()

    function run_timestep(p, v, d, t)
        if t.t < 10
            v.varB = 1
        else
            v.varB = 10
        end
    end
end

@defcomp C begin
    varC::Int = Variable()
    parC::Int = Parameter()

    function run_timestep(p, v, d, t)
        v.varC = p.parC
    end
end

m = Model()
set_dimension!(m, :time, 2015:5:2100)

addcomponent(m, A)
addcomponent(m, B, before=:A)
addcomponent(m, C, after=:B)
# Component order is B -> C -> A.

connect_parameter(m, :A, :parA, :C, :varC)

unconn = unconnected_params(m)
@test length(unconn) == 1
@test unconn[1] == (:C, :parC)

connect_parameter(m, :C => :parC, :B => :varB)

@test_throws ErrorException addcomponent(m, C, after=:A, before=:B)

@test numcomponents(m.md) == 3

@test length(internal_param_conns(m)) == 2
@test get_connections(m, :A, :incoming)[1].src_comp_name == :C

@test length(get_connections(m, :B, :incoming)) == 0
@test get_connections(m, :B, :outgoing)[1].dst_comp_name == :C

@test length(get_connections(m, :A, :all)) == 1

@test length(unconnected_params(m)) == 0

add_connector_comps(m)
run(m)

#############################################
#  Tests for model def and instance         #
#############################################

@test modeldef(m) == m.md
@test modelinstance(m) == m.mi

#############################################
#  Tests for connecting scalar parameters   #
#############################################

@test all([m[:A, :varA][t] == 1 for t in 1:9])

@test all([m[:A, :varA][t] == 10 for t in 10:dim_count(m.md, :time)])


##########################
#   tests for indexing   #
##########################

@test dim_count(m.md, :time) == 18

@test m[:A, :parA] == 10
@test_throws ErrorException m[:A, :xx]

time = dimension(m, :time)
a = collect(keys(time))
@test all([a[i] == 2010 + 5*i for i in 1:18])

@test dimensions(m, :A, :varA)[1] == :time
@test length(dimensions(m, :A, :parA)) == 0

################################
#  tests for delete! function  #
################################

@test_throws ErrorException delete!(m, :D)
@test length(m.md.internal_param_conns) == 2
delete!(m, :A)
@test length(m.md.internal_param_conns) == 1
@test !(:A in compdefs(m))
@test length(compdefs(m)) == 2

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
