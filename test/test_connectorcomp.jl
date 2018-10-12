module TestConnectorComp

using Mimi
using Test

import Mimi:
    reset_compdefs, compdef

reset_compdefs()

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
dim = Mimi.Dimension(years)

#------------------------------------------------------------------------------
#  1. Manual way of using ConnectorComp
#------------------------------------------------------------------------------

m = Model()
set_dimension!(m, :time, years)

add_comp!(m, Short; first=late_start)
add_comp!(m, Mimi.ConnectorCompVector, :MyConnector) # Rename component in this model
add_comp!(m, Long)

comp_def = compdef(m, :MyConnector)
@test Mimi.compname(comp_def.comp_id) == :ConnectorCompVector

set_param!(m, :Short, :a, 2.)
connect_param!(m, :MyConnector, :input1, :Short, :b)

set_param!(m, :MyConnector, :input2, zeros(length(years)))
connect_param!(m, :Long, :x, :MyConnector, :output)

run(m)

b = m[:Short, :b]
input1 = m[:MyConnector, :input1]
output = m[:MyConnector, :output]
x = m[:Long, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years)
@test length(input1) == length(years)
@test length(output) == length(years)
@test length(x) == length(years)

# Test the values are the right values before the late start
@test all(ismissing, b[1:dim[late_start]-1])
@test all(ismissing, input1[1:dim[late_start]-1])
@test all(iszero, output[1:dim[late_start]-1])
@test all(iszero, x[1:dim[late_start]-1])

# Test the values are right after the late start
@test b[dim[late_start]:end] == 
    input1[dim[late_start]:end] == 
    output[dim[late_start]:end] == 
    x[dim[late_start]:end] == 
    [2 * i for i in 1:(years[end]-late_start + 1)]

# Test the dataframe size
b = getdataframe(m, :Short, :b)
@test size(b) == (length(years), 2)


#------------------------------------------------------------------------------
#  2. Use the connect_param! method with backup data (ConnectorComp gets added 
#       under the hood during build)
#------------------------------------------------------------------------------

model2 = Model()
set_dimension!(model2, :time, years)
add_comp!(model2, Short; first=late_start)
add_comp!(model2, Long)
set_param!(model2, :Short, :a, 2.)
connect_param!(model2, :Long, :x, :Short, :b, zeros(length(years)))

run(model2)

# @test length(components(model2.mi)) == 2
@test length(components(model2.mi)) == 3    # is there a way to prevent this? ConnectorComp is added to the list of components in the model isntance
@test length(model2.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model2[:Short, :b]
x = model2[:Long, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years)
@test length(x) == length(years)

@test all(ismissing, b[1:dim[late_start]-1])
@test all(iszero, x[1:dim[late_start]-1])

# Test the values are right after the late start
@test b[dim[late_start]:end] == 
    x[dim[late_start]:end] == 
    [2 * i for i in 1:(years[end]-late_start + 1)]


#------------------------------------------------------------------------------
#  3. Test with a short component that ends early (and test Variable timesteps)
#------------------------------------------------------------------------------

years_variable = [2000:2004..., 2005:5:2030...]
dim_variable = Mimi.Dimension(years_variable)

early_last = 2010

model3 = Model()
set_dimension!(model3, :time, years_variable)
add_comp!(model3, Short; last=early_last)
add_comp!(model3, Long)
set_param!(model3, :Short, :a, 2.)
connect_param!(model3, :Long, :x, :Short, :b, zeros(length(years_variable)))

run(model3)

@test length(components(model3.mi)) == 3    
@test length(model3.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model3[:Short, :b]
x = model3[:Long, :x]

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
#  4. A model that requires multiregional ConnectorComps
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

model4 = Model()
set_dimension!(model4, :time, years)
set_dimension!(model4, :regions, regions)
add_comp!(model4, Short_multi; first=late_start)
add_comp!(model4, Long_multi)
set_param!(model4, :Short_multi, :a, [1,2])
connect_param!(model4, :Long_multi, :x, :Short_multi, :b, zeros(length(years), length(regions)))

run(model4)

@test length(components(model4.mi)) == 3    
@test length(model4.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model4[:Short_multi, :b]
x = model4[:Long_multi, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test size(b) == (length(years), length(regions))
@test size(x) == (length(years), length(regions))

@test all(ismissing, b[1:dim[late_start]-1, :])
@test all(iszero, x[1:dim[late_start]-1, :])

# Test the values are right after the late start
@test b[dim[late_start]:end, :] == 
    x[dim[late_start]:end, :] == 
    [[i + 1 for i in 1:(years[end]-late_start + 1)] [i + 2 for i in 1:(years[end]-late_start + 1)]]


#------------------------------------------------------------------------------
#  5. Test where the short component starts late and ends early
#------------------------------------------------------------------------------

first, last = 2002, 2007

model5 = Model()
set_dimension!(model5, :time, years)
set_dimension!(model5, :regions, regions)
add_comp!(model5, Short_multi; first=first, last=last)
add_comp!(model5, Long_multi)

set_param!(model5, :Short_multi, :a, [1,2])
connect_param!(model5, :Long_multi=>:x, :Short_multi=>:b, zeros(length(years), length(regions)))

run(model5)

@test length(components(model5.mi)) == 3    
@test length(model5.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model5[:Short_multi, :b]
x = model5[:Long_multi, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test size(b) == (length(years), length(regions))
@test size(x) == (length(years), length(regions))

@test all(ismissing, b[1:dim[first]-1, :])
@test all(ismissing, b[dim[last]+1:end, :])
@test all(iszero, x[1:dim[first]-1, :])
@test all(iszero, x[dim[last]+1:end, :])

# Test the values are right after the late start
@test b[dim[first]:dim[last], :] == 
    x[dim[first]:dim[last], :] == 
    [[i + 1 for i in 1:(years[end]-late_start + 1)] [i + 2 for i in 1:(years[end]-late_start + 1)]]


#------------------------------------------------------------------------------
#  6. Test errors with backup data
#------------------------------------------------------------------------------

late_start_long = 2002

model6 = Model()
set_dimension!(model6, :time, years)
add_comp!(model6, Short; first = late_start)
add_comp!(model6, Long; first = late_start_long)    # starts later as well, so backup data needs to match this size
set_param!(model6, :Short, :a, 2)

# A. test wrong size (needs to be length of component, not length of model)
@test_throws ErrorException connect_param!(model6, :Long=>:x, :Short=>:b, zeros(length(years)))

# B. test no backup data provided
# TODO: do we want this to error?
connect_param!(model6, :Long=>:x, :Short=>:b)   # Connect long to short without any backup

run(model6)     # TODO: doesn't error, is that okay?

@test length(components(model6.mi)) == 2    # no ConnectorComp added because no backup data given  
@test length(model6.md.comp_defs) == 2      

b = model6[:Short, :b]
x = model6[:Long, :x]

@test all(ismissing, b[1:dim[late_start]-1])
@test all(ismissing, x[1:dim[late_start]-1])    # Values are `missing` in Long's :x parameter because no backup data


#------------------------------------------------------------------------------
#  7. Test connecting Short component to Long component (does not add a 
#       connector component)
#------------------------------------------------------------------------------

@defcomp foo begin
    par = Parameter(index=[time])
    var = Variable(index=[time])
    function run_timestep(p, v, d, ts)
        v.var[ts] = p.par[ts]
    end
end

model7 = Model()
set_dimension!(model7, :time, years)
add_comp!(model7, foo, :Long)
add_comp!(model7, foo, :Short; first=late_start)
connect_param!(model7, :Short=>:par, :Long=>:var)
set_param!(model7, :Long, :par, years)

run(model7)

@test length(components(model7.mi)) == 2

short_par = model7[:Short, :par]
short_var = model7[:Short, :var]

@test short_par == years    # TODO: is this the functionality we want? it has values instead of 
                            # `missing`` for years when this component doesn't run, because they are 
                            # coming from the longer component that did run

@test all(ismissing, short_var[1:dim[late_start]-1])
@test short_var[dim[late_start]:end] == years[dim[late_start]:end]


end #module
