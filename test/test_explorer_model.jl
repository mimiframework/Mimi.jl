using Mimi
using Test
using DataFrames
using VegaLite
using Electron

import Mimi: 
    dataframe_or_scalar, _spec_for_item, menu_item_list, getdataframe, dim_names

# Helper function returns true if VegaLite is verison 3 or above, and false otherwise
function _is_VegaLite_v3()
    return isdefined(VegaLite, :vlplot) ? true : false
end

@defcomp MyComp begin
    a = Parameter(index=[time, regions])
    b = Parameter(index=[time])
    c = Parameter(index=[regions])
    d = Parameter()
    e = Parameter(index=[four])
    f = Parameter{Array{Float64, 2}}()

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

# 2.  Specs and menu
items = [:a, :b, :c, :d, :e, :f, :x]
for item in items
    static_spec = _spec_for_item(m, :MyComp, item; interactive = false)
    interactive_spec = _spec_for_item(m, :MyComp, item)
    if length(dim_names(m, :MyComp, item)) == 0
        name =  string(:MyComp, " : ", item, " = ", m[:MyComp, item])
    else
        name = string(:MyComp, " : ", item)
    end
    @test static_spec["name"] == interactive_spec["name"] == name
end

s = menu_item_list(m)
@test collect(keys(s)) == ["pars", "vars"]
@test length(collect(keys(s["pars"]))) == 6
@test length(collect(keys(s["vars"]))) == 1

# 3.  explore(m::Model)
w = explore(m)
@test typeof(w) == Electron.Window
close(w)

# 4.  Mimi.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
#       dim_name::Union{Nothing, Symbol} = nothing)
items = [:a, :b, :c, :d, :e, :f, :x]
for item in items
    p_type = _is_VegaLite_v3() ? VegaLite.VLSpec : VegaLite.VLSpec{:plot}
    @test typeof(Mimi.plot(m, :MyComp, item)) == p_type
end

# 5.  errors and warnings
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

# spec creation for MyComp.a should warn because over 2 indexed dimensions
# @test_logs (:warn, "MyComp2.a has > 2 indexed dimensions, not yet implemented in explorer") explore(m2) # URI PARSER WARNING IN CI
# @test_logs (:warn, "MyComp2.a has > 2 indexed dimensions, not yet implemented in explorer") _spec_for_item(m2, :MyComp2, :a) # URI PARSER WARNING IN CI

#7. Test TimestepArrays with time not as the first dimension

@defcomp gdp begin
    growth = Parameter(index=[regions, foo, time, 2])   # test that time is not first but not last
    gdp = Variable(index=[regions, foo, time, 2])
    gdp0 = Parameter(index=[regions, foo, 2])

    pgrowth = Parameter(index=[regions, 3, time])       # test time as last
    pop = Variable(index=[regions, 3, time])

    mat = Parameter(index=[regions, time])              # test time as last for a matrix
    mat2 = Variable(index=[regions, time])

    function run_timestep(p, v, d, ts)
        if is_first(ts)
            v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* p.gdp0
            v.pop[:, :, ts] = zeros(2, 3)
        else
            v.gdp[:, :, ts, :] = (1 .+ p.growth[:, :, ts, :]) .* v.gdp[:, :, ts-1, :]
            v.pop[:, :, ts] = v.pop[:, :, ts-1] .+ p.pgrowth[:, :, ts]
        end
        v.mat2[:, ts] = p.mat[:, ts]
    end
end

time_index = 2000:2100
regions = ["OECD","non-OECD"]
nsteps=length(time_index)

m = Model()
set_dimension!(m, :time, time_index)
set_dimension!(m, :regions, regions)
set_dimension!(m, :foo, 3)
add_comp!(m, gdp)
set_param!(m, :gdp, :gdp0, [3; 7] .* ones(length(regions), 3, 2))
set_param!(m, :gdp, :growth, [0.02; 0.03] .* ones(length(regions), 3, nsteps, 2))
set_leftover_params!(m, Dict{String, Any}([
    "pgrowth" => ones(length(regions), 3, nsteps),
    "mat" => rand(length(regions), nsteps)
]))
run(m)
w = explore(m)
close(w)

# 8. More plot types

@defcomp example begin
    p0 = Parameter(index = [time]) # line plot
    p1 = Parameter(index = [foo]) # scatter plot
    p2 = Parameter(index = [baz]) # bar plot
    p3 = Parameter(index = [foo, bar]) # multi-scatter
    p4 = Parameter(index = [baz, foo]) # multi-bar
    p5 = Parameter(index = [time, bar]) # multi-line
    p6 = Parameter(index = [time, baz]) # multi-line

    x = Variable(index = [time])
    function run_timestep(p,v,d,t)
        v.x[t] = 0
    end
end

m = Model()

set_dimension!(m, :time, 2000:2009)
set_dimension!(m, :foo, 1:5)
set_dimension!(m, :bar, 1:3)
set_dimension!(m, :baz, [:A, :B, :C])

add_comp!(m, example)

set_param!(m, :example, :p0, 1:10)
set_param!(m, :example, :p1, 6:10)
set_param!(m, :example, :p2, 4:6)

set_param!(m, :example, :p3, reshape(1:15, 5, 3))
set_param!(m, :example, :p4, reshape(1:15, 3, 5))
set_param!(m, :example, :p5, reshape(1:30, 10, 3))
set_param!(m, :example, :p6, reshape(1:30, 10, 3))

run(m)
explore(m)

items = [:p0, :p1, :p2, :p3, :p4, :p5, :p6]
for item in items
    static_spec = _spec_for_item(m, :example, item; interactive = false)
    interactive_spec = _spec_for_item(m, :example, item)
    if length(dim_names(m, :example, item)) == 0
        name =  string(:example, " : ", item, " = ", m[:example, item])
    else
        name = string(:example, " : ", item)
    end
    @test static_spec["name"] == interactive_spec["name"] == name
end
