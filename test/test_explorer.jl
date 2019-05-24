using Mimi
using Test
using DataFrames
using VegaLite
using Electron

import Mimi: 
    dataframe_or_scalar, createspec_singlevalue, 
    createspec_lineplot, createspec_multilineplot, createspec_barplot,
    getmultiline, getline, getbar, _spec_for_item, menu_item_list, explore, 
    getdataframe, reset_compdefs

reset_compdefs()

@defcomp MyComp begin
    a = Parameter(index=[time, regions])
    b = Parameter(index=[time])
    c = Parameter(index=[regions])
    d = Parameter()
    e = Parameter(index=[four])
    f::Array{Float64, 2} = Parameter()

    x = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.x[t, r] = 0
        end
    end
end

m = Model()
set_dimension!(m, :time, 2000:2100)
set_dimension!(m, :regions, 3)
set_dimension!(m, :four, 4)

add_comp!(m, MyComp)
set_param!(m, :MyComp, :a, ones(101,3))
set_param!(m, :MyComp, :b, 1:101)
set_param!(m, :MyComp, :c, [4,5,6])
set_param!(m, :MyComp, :d, .5)
set_param!(m, :MyComp, :e, [1,2,3,4])
set_param!(m, :MyComp, :f, [1.0 2.0; 3.0 4.0])

run(m)

# 1.  dataframe helper functions
@test typeof(dataframe_or_scalar(m, :MyComp, :a)) == DataFrame
@test typeof(dataframe_or_scalar(m, :MyComp, :d)) == Float64

#2.  JSON strings for the spec "values" key
#:  getmultiline, getline, getbar, getdatapart

#3.  full specs for VegaLit

#TODO:  createspec_singlevalue, createspec_multilineplot, 
#createspec_lineplot, createspec_barplot, _spec_for_item

s = menu_item_list(m)
@test typeof(s) == Array{Any, 1}
@test length(s) == 7

#4.  explore(m::Model, title = "Electron")
w = explore(m, title = "Testing Window")
@test typeof(w) == Electron.Window
close(w)

#5.  Mim.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
#       dim_name::Union{Nothing, Symbol} = nothing)

p = Mimi.plot(m, :MyComp, :a)
@test typeof(p) == VegaLite.VLSpec{:plot}

#6.  errors and warnings
@defcomp MyComp2 begin

    a = Parameter(index = [time, regions, four])
    x = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, t)
        for r in d.regions
            v.x[t, r] = rand(10)[1]
        end
    end
end

m2 = Model()
set_dimension!(m2, :time, 2000:2100)
set_dimension!(m2, :regions, 3)
set_dimension!(m2, :four, 4)

add_comp!(m2, MyComp2)
set_param!(m2, :MyComp2, :a, ones(101, 3, 4)) 

run(m2)

#spec creation for MyComp.a should fail and error, haven't handled case of > 3 dims yet
# TODO Reenable
# @test_warn "has >2 graphing dims" explore(m2)
