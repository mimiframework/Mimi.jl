module TestModelStructure

#tests the framework of components and connections

using Base.Test
using Mimi

import Mimi: 
    connect_param!, unconnected_params, set_dimension!, 
    reset_compdefs, numcomponents, get_connections, internal_param_conns, dim_count, 
    modeldef, modelinstance, compdef, getproperty, setproperty!, dimension, 
    dimensions, compdefs

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

add_comp!(m, A)
add_comp!(m, B, before=:A)
add_comp!(m, C, after=:B)
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

add_comp!(m, D)
@test_throws ErrorException Mimi.build(m)


end # module

##########################################
#   Test check # of function arguments   #
##########################################

function defcomp_error1()
    try
        @defcomp Error1 begin
            function run_timestep(p, v, d) 
            end   
        end
    catch err
        rethrow(err)
    end
end
@test_throws UndefVarError defcomp_error1()

function defcomp_error2()
    try
        @defcomp Error2 begin
            function run_timestep(p, v, d, t) 
            end   
            function init(p, v)
            end
        end
    catch err
        rethrow(err)
    end
end
@test_throws UndefVarError defcomp_error2()

##########################################
#   Test init function                   #
##########################################

reset_compdefs()

@defcomp A begin
    varA::Int = Variable(index=[time])
    parA::Int = Parameter()
    parB::Int = Parameter()

    function init(p, v, d)
        v.varA[1] = p.parA
    end

    function run_timestep(p, v, d, t)
        if !is_first(t)
            v.varA[t] = p.parB
        end
    end
end

m = Model()
set_dimension!(m, :time, 2015:5:2100)
add_comp!(m, A)
set_param!(m, :A, :parA, 1)
set_param!(m, :A, :parB, 10)
run(m)

results = m[:A, :varA]
for i in 1:18
    if i == 1
        @test results[i] == 1
    else
        @test results[i] == 10
    end
end
