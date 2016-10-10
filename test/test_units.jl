using Base.Test
using Mimi

# Try directly using unitcheck
@test unitcheck("kg", "kg")
@test !unitcheck("kg", "MT")
@test !unitcheck("kg", "")

# Create a model with some matching and some mis-matching units
@defcomp FooUnits begin
    output = Variable(unit="kg")
end

@defcomp BarUnits begin
    input = Parameter(unit="MT")
end

@defcomp BazUnits begin
    input = Parameter(unit="kg")
end

m = Model()
setindex(m, :time, 1)
foo = addcomponent(m, FooUnits)
bar = addcomponent(m, BarUnits)
baz = addcomponent(m, BazUnits)

# Check that we cannot connect foo and bar...
@test_throws ErrorException bar[:input] = foo[:output]
# ...unless we pass ignoreunits=true
connectparameter(m, :BarUnits, :input,  :FooUnits, :output, ignoreunits=true)
# But we can connect foo and baz
baz[:input] = foo[:output]
