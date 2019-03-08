module TestConnectorComp

using Mimi
using Test

import Mimi: compdef, compdefs

@defcomp Long begin
    x = Parameter(index=[time])
end

@defcomp Short begin
    a = Parameter()
    b = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
        v.b[t] = p.a * t.t
    end
end

years = 2000:2010
late_start = 2005
year_dim = Mimi.Dimension(years)


#------------------------------------------------------------------------------
#  1. Use the connect_param! method with backup data (ConnectorComp gets added 
#       under the hood during build)
#------------------------------------------------------------------------------

model1 = Model()
set_dimension!(model1, :time, years)
add_comp!(model1, Short; first=late_start)
add_comp!(model1, Long)
set_param!(model1, :Short, :a, 2.)
connect_param!(model1, :Long, :x, :Short, :b, zeros(length(years)))

run(model1)

@test length(components(model1.mi)) == 3    # ConnectorComp is added to the list of components in the model isntance
@test length(compdefs(model1.md)) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model1[:Short, :b]
x = model1[:Long, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years)
@test length(x) == length(years)

@test all(ismissing, b[1:year_dim[late_start]-1])
@test all(iszero, x[1:year_dim[late_start]-1])

# Test the values are right after the late start
@test b[year_dim[late_start]:end] == x[year_dim[late_start]:end]
@test b[year_dim[late_start]:end] == collect(year_dim[late_start]:year_dim[years[end]]) * 2.0

@test Mimi.datum_size(model1.md, Mimi.compdef(model1.md, :Long), :x) == (length(years),)

# Test the dataframe size
b = getdataframe(model1, :Short, :b)
@test size(b) == (length(years), 2)
 
#------------------------------------------------------------------------------
#  2. Test with a short component that ends early (and test Variable timesteps)
#------------------------------------------------------------------------------

years_variable = [2000:2004..., 2005:5:2030...]
dim_variable = Mimi.Dimension(years_variable)

early_last = 2010

model2 = Model()
set_dimension!(model2, :time, years_variable)
add_comp!(model2, Short; last=early_last)
add_comp!(model2, Long)
set_param!(model2, :Short, :a, 2.)
connect_param!(model2, :Long, :x, :Short, :b, zeros(length(years_variable)))

run(model2)

@test length(components(model2.mi)) == 3    
@test length(compdefs(model2.md)) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model2[:Short, :b]
x = model2[:Long, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years_variable)
@test length(x) == length(years_variable)

@test all(ismissing, b[dim_variable[early_last]+1 : end])
@test all(iszero, x[dim_variable[early_last]+1 : end])

# Test the values are right after the late start
@test b[1 : dim_variable[early_last]] == 
    x[1 : dim_variable[early_last]] == 
    [2 * i for i in 1:dim_variable[early_last]]


#------------------------------------------------------------------------------
#  3. A model that requires multiregional ConnectorComps
#------------------------------------------------------------------------------

@defcomp Long_multi begin
    regions = Index()

    x = Parameter(index = [time, regions])
end

@defcomp Short_multi begin
    regions = Index()

    a = Parameter(index=[regions])
    b = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, ts)
        for r in d.regions
            v.b[ts, r] = ts.t + p.a[r]
        end
    end
end

regions = [:A, :B]

model3 = Model()
set_dimension!(model3, :time, years)
set_dimension!(model3, :regions, regions)
add_comp!(model3, Short_multi; first=late_start)
add_comp!(model3, Long_multi)
set_param!(model3, :Short_multi, :a, [1,2])
connect_param!(model3, :Long_multi, :x, :Short_multi, :b, zeros(length(years), length(regions)))

run(model3)

@test length(components(model3.mi)) == 3    
@test length(compdefs(model3.md)) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model3[:Short_multi, :b]
x = model3[:Long_multi, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test size(b) == (length(years), length(regions))
@test size(x) == (length(years), length(regions))

@test all(ismissing, b[1:year_dim[late_start]-1, :])
@test all(iszero, x[1:year_dim[late_start]-1, :])

# Test the values are right after the late start
late_yr_idxs = year_dim[late_start]:year_dim[end]

@test b[late_yr_idxs, :] == x[year_dim[late_start]:end, :]

@test b[late_yr_idxs, :] == [[i + 1 for i in late_yr_idxs] [i + 2 for i in late_yr_idxs]]

#------------------------------------------------------------------------------
#  4. Test where the short component starts late and ends early
#------------------------------------------------------------------------------

first, last = 2002, 2007

model4 = Model()
set_dimension!(model4, :time, years)
set_dimension!(model4, :regions, regions)
add_comp!(model4, Short_multi; first=first, last=last)
add_comp!(model4, Long_multi)

set_param!(model4, :Short_multi, :a, [1,2])
connect_param!(model4, :Long_multi=>:x, :Short_multi=>:b, zeros(length(years), length(regions)))

run(model4)

@test length(components(model4.mi)) == 3    
@test length(compdefs(model4.md)) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model4[:Short_multi, :b]
x = model4[:Long_multi, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test size(b) == (length(years), length(regions))
@test size(x) == (length(years), length(regions))

@test all(ismissing, b[1:year_dim[first]-1, :])
@test all(ismissing, b[year_dim[last]+1:end, :])
@test all(iszero, x[1:year_dim[first]-1, :])
@test all(iszero, x[year_dim[last]+1:end, :])

# Test the values are right after the late start
yr_idxs = year_dim[first]:year_dim[last]
@test b[yr_idxs, :] == x[yr_idxs, :]
#@test b[yr_idxs, :] == [[i + 1 for i in 1:(years[end]-late_start + 1)] [i + 2 for i in 1:(years[end]-late_start + 1)]]
@test b[yr_idxs, :] == [[i + 1 for i in yr_idxs] [i + 2 for i in yr_idxs]]

#------------------------------------------------------------------------------
#  5. Test errors with backup data
#------------------------------------------------------------------------------

late_start_long = 2002

model5 = Model()
set_dimension!(model5, :time, years)
add_comp!(model5, Short; first = late_start)
add_comp!(model5, Long; first = late_start_long)    # starts later as well, so backup data needs to match this size
set_param!(model5, :Short, :a, 2)

# A. test wrong size (needs to be length of component, not length of model)
@test_throws ErrorException connect_param!(model5, :Long=>:x, :Short=>:b, zeros(length(years)))
@test_throws ErrorException connect_param!(model4, :Long_multi=>:x, :Short_multi=>:b, zeros(length(years), length(regions)+1)) # test case with >1 dimension


# B. test no backup data provided
@test_throws ErrorException connect_param!(model5, :Long=>:x, :Short=>:b)   # Error because no backup data provided


#------------------------------------------------------------------------------
#  6. Test connecting Short component to Long component (does not add a 
#       connector component)
#------------------------------------------------------------------------------

@defcomp foo begin
    par = Parameter(index=[time])
    var = Variable(index=[time])
    function run_timestep(p, v, d, ts)
        v.var[ts] = p.par[ts]
    end
end

model6 = Model()
set_dimension!(model6, :time, years)
add_comp!(model6, foo, :Long; exports=[:var => :long_var])
add_comp!(model6, foo, :Short; exports=[:var => :short_var], first=late_start)
connect_param!(model6, :Short => :par, :Long => :var)
set_param!(model6, :Long, :par, years)

run(model6)

@test length(components(model6.mi)) == 2

short_par = model6[:Short, :par]
short_var = model6[:Short, :var]

@test short_par == years    # The parameter has values instead of `missing` for years when this component doesn't run, 
                            # because they are coming from the longer component that did run

@test all(ismissing, short_var[1:year_dim[late_start]-1])
@test short_var[year_dim[late_start]:end] == years[year_dim[late_start]:end]


end #module
