module TestDefaults

using Mimi
using Test

import Mimi: external_params

@defcomp A begin
    p1 = Parameter(default = 1)
    p2 = Parameter()
end

m = Model()
set_dimension!(m, :time, 1:10)
add_comp!(m, A)
set_param!(m, :p2, 2)

# So far only :p2 is in the model definition's dictionary
@test :p2 in keys(external_params(m)) 
@test length(external_params(m)) == 2 

run(m)

# :p1's value is it's default 
@test m[:A, :p1] == 1

# This errors because p1 isn't in the model definition's external params 
@test_throws ErrorException update_param!(m, :p1, 10)  

# Need to use set_param! instead
set_param!(m, :p1, 10)

# Now there is a :p1 in the model definition's dictionary
@test :p1 in keys(external_params(m))

run(m)
@test m[:A, :p1] == 10
update_param!(m, :p1, 11)   # Now we can use update_param!


end