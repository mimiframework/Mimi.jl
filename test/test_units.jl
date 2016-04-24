using Base.Test
using Mimi

@test unitcheck("kg", "any")
@test unitcheck("kg", "kg")
@test !unitcheck("kg", "MT")


@defcomp FooUnits begin
    output = Variable(units="kg")
end

@defcomp BarUnits begin
    input = Parameter(units="MT")
end

@defcomp BazUnits begin
    input = Parameter(units="kg")
end

m = Model()
setindex(m, :time, 1)
foo = addcomponent(m, FooUnits)
bar = addcomponent(m, BarUnits)
baz = addcomponent(m, BazUnits)

@test_throws AssertionError bar[:input] = foo[:output]
baz[:input] = foo[:output]

