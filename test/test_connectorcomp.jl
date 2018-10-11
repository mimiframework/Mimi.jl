module TestConnectorComp
# @testset "ConnectorComp" begin

using Mimi
using Test

import Mimi:
    reset_compdefs, compdef

reset_compdefs()

@defcomp LongComponent begin
    x = Parameter(index=[time])
end

@defcomp ShortComponent begin
    a = Parameter()
    b = Variable(index=[time])
    
    function run_timestep(p, v, d, t)
        v.b[t] = p.a * t.t
    end
end

years = 2000:2010
late_start = 2005

#------------------------------------------------------------------------------
#  1. Manual way of using ConnectorComp
#------------------------------------------------------------------------------

m = Model()
set_dimension!(m, :time, years)

add_comp!(m, ShortComponent; first=late_start)
add_comp!(m, Mimi.ConnectorCompVector, :MyConnector) # Rename component in this model
add_comp!(m, LongComponent)

comp_def = compdef(m, :MyConnector)
@test Mimi.compname(comp_def.comp_id) == :ConnectorCompVector

set_param!(m, :ShortComponent, :a, 2.)
connect_param!(m, :MyConnector, :input1, :ShortComponent, :b)

set_param!(m, :MyConnector, :input2, zeros(length(years)))
connect_param!(m, :LongComponent, :x, :MyConnector, :output)

run(m)

b = m[:ShortComponent, :b]
input1 = m[:MyConnector, :input1]
output = m[:MyConnector, :output]
x = m[:LongComponent, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years)
@test length(input1) == length(years)
@test length(output) == length(years)
@test length(x) == length(years)

dim = Mimi.Dimension(years)

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
b = getdataframe(m, :ShortComponent, :b)
@test size(b) == (length(years), 2)


#------------------------------------------------------------------------------
#  2. Use the connect_param! method with backup data (ConnectorComp gets added 
#       under the hood during build)
#------------------------------------------------------------------------------

model2 = Model()
set_dimension!(model2, :time, years)
add_comp!(model2, ShortComponent; first=late_start)
add_comp!(model2, LongComponent)
set_param!(model2, :ShortComponent, :a, 2.)
connect_param!(model2, :LongComponent, :x, :ShortComponent, :b, zeros(length(years)))

run(model2)

# @test length(components(model2.mi)) == 2
@test length(components(model2.mi)) == 3    # is there a way to prevent this? ConnectorComp is added to the list of components in the model isntance
@test length(model2.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model2[:ShortComponent, :b]
x = model2[:LongComponent, :x]

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
#  3. Test with a short component that ends early
#------------------------------------------------------------------------------

early_last = 2005

model3 = Model()
set_dimension!(model3, :time, years)
add_comp!(model3, ShortComponent; last=early_last)
add_comp!(model3, LongComponent)
set_param!(model3, :ShortComponent, :a, 2.)
connect_param!(model3, :LongComponent, :x, :ShortComponent, :b, zeros(length(years)))

run(model3)

@test length(components(model3.mi)) == 3    
@test length(model3.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model3[:ShortComponent, :b]
x = model3[:LongComponent, :x]

# Test that all allocated datum arrays are the full length of the time dimension
@test length(b) == length(years)
@test length(x) == length(years)

@test all(ismissing, b[dim[early_last]+1 : end])
@test all(iszero, x[dim[early_last]+1 : end])

# Test the values are right after the late start
@test b[1 : dim[early_last]] == 
    x[1 : dim[early_last]] == 
    [2 * i for i in 1:dim[early_last]]


#------------------------------------------------------------------------------
#  4. A model that requires multiregional ConnectorComps
#------------------------------------------------------------------------------

@defcomp Long begin
    regions = Index()

    x = Parameter(index = [time, regions])
end

@defcomp Short begin
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
add_comp!(model4, Short; first=late_start)
add_comp!(model4, Long)
set_param!(model4, :Short, :a, [1,2])
connect_param!(model4, :Long, :x, :Short, :b, zeros(length(years), length(regions)))

run(model4)

@test length(components(model4.mi)) == 3    
@test length(model4.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model4[:Short, :b]
x = model4[:Long, :x]

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
add_comp!(model5, Short; first=first, last=last)
add_comp!(model5, Long)

set_param!(model5, :Short, :a, [1,2])
connect_param!(model5, :Long=>:x, :Short=>:b, zeros(length(years), length(regions)))

run(model5)

@test length(components(model5.mi)) == 3    
@test length(model5.md.comp_defs) == 2      # The ConnectorComp shows up in the model instance but not the model definition

b = model5[:Short, :b]
x = model5[:Long, :x]

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

# end  # testset
end #module
