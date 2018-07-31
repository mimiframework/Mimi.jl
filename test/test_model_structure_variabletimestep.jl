module TestModelStructure_VariableTimestep

#tests the framework of components and connections

using Base.Test
using Mimi

import Mimi: 
    add_connector_comps, connect_param!, unconnected_params, set_dimension!, 
    reset_compdefs, numcomponents, get_connections, internal_param_conns, dim_count, 
    compdef, getproperty, setproperty!, dimension, dimensions, compdefs

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
years = [2015:5:2100; 2110:10:2200]
set_dimension!(m, :time, years)

@test_throws ErrorException add_comp!(m, A, last = 2210) 
@test_throws ErrorException add_comp!(m, A, first = 2010) 
@test_throws ErrorException add_comp!(m, A, after=:B)
add_comp!(m, A, first = 2050, last = 2150) #test specific last and first

add_comp!(m, B, before=:A)

add_comp!(m, C, after=:B) # test a later first than model
# Component order is B -> C -> A.

connect_param!(m, :A, :parA, :C, :varC)

unconn = unconnected_params(m)
@test length(unconn) == 1
@test unconn[1] == (:C, :parC)

connect_param!(m, :C => :parC, :B => :varB)

@test_throws ErrorException add_comp!(m, C, after=:A, before=:B)

@test numcomponents(m.md) == 3

@test length(internal_param_conns(m)) == 2
@test get_connections(m, :A, :incoming)[1].src_comp_name == :C

@test length(get_connections(m, :B, :incoming)) == 0
@test get_connections(m, :B, :outgoing)[1].dst_comp_name == :C

@test length(get_connections(m, :A, :all)) == 1

@test length(unconnected_params(m)) == 0

#############################################
#  Tests for connecting scalar parameters   #
#############################################

add_connector_comps(m)
run(m)

@test all([m[:A, :varA][t] == 1 for t in 1:2])
@test all([m[:A, :varA][t] == 10 for t in 3:16])


##########################
#   tests for indexing   #
##########################

@test dim_count(m.md, :time) == 28

@test m[:A, :parA] == 10
@test_throws ErrorException m[:A, :xx]

time = dimension(m, :time)
a = collect(keys(time))
@test all([a[i] == years[i] for i in 1:28])

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

add_comp!(m, D)
@test_throws ErrorException Mimi.build(m)


end # module
