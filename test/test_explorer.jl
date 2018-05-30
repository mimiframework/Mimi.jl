using Mimi
using Base.Test
using DataFrames

import Mimi: 
    dataframe_or_scalar, createspec_singlevalue, 
    createspec_lineplot, createspec_multilineplot, createspec_barplot,
    getmultiline, getline, getbar, _spec_for_item, spec_list, explore, 
    getdataframe


# define a model to test
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

addcomponent(m, MyComp)
set_parameter!(m, :MyComp, :a, ones(101,3))
set_parameter!(m, :MyComp, :b, 1:101)
set_parameter!(m, :MyComp, :c, [4,5,6])
set_parameter!(m, :MyComp, :d, .5)
set_parameter!(m, :MyComp, :e, [1,2,3,4])
set_parameter!(m, :MyComp, :f, [1.0 2.0; 3.0 4.0])

run(m)

# 1.  dataframe helper functions
@test typeof(dataframe_or_scalar(m, :MyComp, :a)) == DataFrame
@test typeof(dataframe_or_scalar(m, :MyComp, :d)) == Float64

#2.  JSON strings for the spec "values" key
# TODO:  getmultiline, getline, getbar, getdatapart

#3.  full specs for VegaLit

#TODO:  reatespec_singlevalue, createspec_multilineplot, 
#createspec_lineplot, createspec_barplot, _spec_for_item

s = spec_list(m)
@test typeof(s) == Array{Any, 1}
@test length(s) == 7
goodDicts = 0;
for i = 1:length(s)
    if typeof(s[1]) == Dict{String, Any} && collect(keys(s[i])) == ["name", "VLspec"]
        goodDicts += 1
    end
end
@test goodDicts == length(s)

#4.  explore
w = explore(m, title = "Testing Window")
@test typeof(w) == Electron.Window
