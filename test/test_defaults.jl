module TestDefaults

using Mimi
using Test

import Mimi: model_params

@defcomp A begin
    p1 = Parameter(default = 1)
    p2 = Parameter{Symbol}()
end

m = Model()
set_dimension!(m, :time, 1:10)
add_comp!(m, A)

add_shared_param!(m, :p2, :hello)
connect_param!(m, :A, :p2, :p2)

# So far only :p2 is in the model definition's dictionary
@test :p2 in keys(model_params(m)) 
@test length(model_params(m)) == 2 

run(m)

# :p1's value is it's default 
@test m[:A, :p1] == 1

# This errors because p1 is unshared
@test_throws ErrorException update_param!(m, :p1, 10)
update_param!(m, :A, :p1, 10) 

# :p1 still not in the dictionary because unshared
@test !(:p1 in keys(model_params(m)))

# now add it as a shared parameter
add_shared_param!(m, :model_p1, 20)
connect_param!(m, :A, :p1, :model_p1)

# Now there is a :model_p1 in the model definition's dictionary but not :p1
@test !(:p1 in keys(model_params(m)))
@test :model_p1 in keys(model_params(m))

run(m)
@test m[:A, :p1] == 20

# Now we can use update_param! but only for the model parameter name and exclusively as a shared parameter
@test_throws ErrorException update_param!(m, :p1, 11)
update_param!(m, :model_p1, 30)   
run(m)
@test m[:A, :p1] == 30

# convert explicitly back to being unshared
@test_throws ErrorException update_param!(m, :A, :p1, 40)
disconnect_param!(m, :A, :p1)
update_param!(m, :A, :p1, 40)
run(m)
@test m[:A, :p1] == 40
@test Mimi.model_param(m, :model_p1).value == 30

end