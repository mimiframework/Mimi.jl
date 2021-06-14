module TestModelStructure

# tests the framework of components and connections

using Test
using Mimi

import Mimi:
    connect_param!, unconnected_params, set_dimension!,
    get_connections, internal_param_conns, dim_count,  dim_names,
    modeldef, modelinstance, compdef, getproperty, setproperty!, dimension, 
    nothing_params, compdefs

@defcomp A begin
    varA = Variable{Int}(index=[time])
    parA = Parameter{Int}()

    function run_timestep(p, v, d, t)
        v.varA[t] = p.parA
    end
end

@defcomp B begin
    varB = Variable{Int}()

    function run_timestep(p, v, d, t)
        if t.t < 10
            v.varB = 1
        else
            v.varB = 10
        end
    end
end

@defcomp C begin
    varC = Variable{Int}()
    parC = Parameter{Int}()

    function run_timestep(p, v, d, t)
        v.varC = p.parC
    end
end

m = Model()

# make sure you can't add a component before setting time dimension (only true for
# adding a component to a model, not adding to a composite component)
@test_throws ErrorException add_comp!(m, A)

set_dimension!(m, :time, 2015:5:2100)

add_comp!(m, A)
add_comp!(m, B, before=:A)
add_comp!(m, C, after=:B)
# Component order is B -> C -> A.

connect_param!(m, :A, :parA, :C, :varC)

unconns = unconnected_params(m)
@test length(unconns) == 0

nothingparams = nothing_params(m)
@test length(nothingparams) == 1

c = compdef(m, :C)
nothingparam = nothingparams[1]
@test nothingparam.comp_name == :C
@test nothingparam.datum_name == :parC

connect_param!(m, :C => :parC, :B => :varB)

@test_throws ErrorException add_comp!(m, C, after=:A, before=:B)

@test length(m.md) == 3

@test length(internal_param_conns(m)) == 2
c = compdef(m, :C)
@test get_connections(m, :A, :incoming)[1].src_comp_path == c.comp_path

@test length(get_connections(m, :B, :incoming)) == 0
@test get_connections(m, :B, :outgoing)[1].dst_comp_path == c.comp_path

@test length(get_connections(m, :A, :all)) == 1
@test length(nothing_params(m)) == 0

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

@test dim_names(m, :A, :varA)[1] == :time
@test length(dim_names(m, :A, :parA)) == 0

################################
#  tests for delete! function  #
################################

@test_throws ErrorException delete!(m, :D)
@test length(internal_param_conns(m.md)) == 2
delete!(m, :A)
@test length(internal_param_conns(m.md)) == 1
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
@test_throws ErrorException Mimi.build!(m)

##########################################
#   Test init function                   #
##########################################

@defcomp E begin
    varE = Variable{Int}()
    parE1 = Parameter{Int}()
    parE2 = Parameter{Int}()

    function init(p, v, d)
        v.varE = p.parE1
    end

    function run_timestep(p, v, d, t)
        if !is_first(t)
            v.varE = p.parE2
        end
    end
end

m = Model()

# run for several timesteps
set_dimension!(m, :time, 2015:5:2100)

add_comp!(m, E)
update_param!(m, :E, :parE1, 1)
update_param!(m, :E, :parE2, 10)

run(m)
@test m[:E, :varE] == 10

# run for just one timestep, so init sets the value here
set_dimension!(m, :time, [2015])

run(m)
@test m[:E, :varE] == 1

end # module
