module TestDefaults

using Mimi
using Test


@defcomp A begin
    p1 = Parameter(default = 1)
    p2 = Parameter()
end

m = Model()
set_dimension!(m, :time, 1:10)
add_comp!(m, A)
set_param!(m, :p2, 2)

# So far only :p2 is in the model definition's dictionary
@test length(m.md.external_params) == 1

run(m)

# During build, :p1's value is set to it's default 
@test m[:A, :p1] == 1

# But the original model definition does not have :p1 in it's external parameters
@test length(m.md.external_params) == 1     
@test length(m.mi.md.external_params) == 2      # But the model instance's md is where the default value was set
@test ! (:p1 in keys(m.md.external_params))
@test :p1 in keys(m.mi.md.external_params)

# This errors because p1 isn't in the model definition's external params 
@test_throws ErrorException update_param!(m, :p1, 10)  

# Need to use set_param! instead
set_param!(m, :p1, 10)

# Now there is a :p1 in the model definition's dictionary
@test :p1 in keys(m.md.external_params)

run(m)
@test m[:A, :p1] == 10
update_param!(m, :p1, 11)   # Now we can use update_param!


end