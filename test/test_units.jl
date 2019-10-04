module TestUnits

using Test
using Mimi

import Mimi: verify_units, connect_param!, ComponentReference, @defmodel

# Try directly using verify_units
@test verify_units("kg", "kg")
@test !verify_units("kg", "MT")
@test !verify_units("kg", "")

# Create a model with some matching and some mis-matching units
@defcomp Foo begin
    output = Variable(unit="kg")
end

@defcomp Bar begin
    input = Parameter(unit="MT")
end

@defcomp Baz begin
    input = Parameter(unit="kg")
end

@defmodel m begin
    index[time] = [1]
    component(Foo)
    component(Bar)
    component(Baz)
end

foo = ComponentReference(m, :Foo)
bar = ComponentReference(m, :Bar)
baz = ComponentReference(m, :Baz)

# Check that we cannot connect foo and bar...
@test_throws ErrorException bar[:input] = foo[:output]

# ...unless we pass ignoreunits=true
connect_param!(m, :Bar, :input,  :Foo, :output, ignoreunits=true)

# But we can connect foo and baz
baz[:input] = foo[:output]

end # module