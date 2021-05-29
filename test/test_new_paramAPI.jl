## Testing the New Parameter API

import Mimi: model_param, is_shared

#
# Section 1. update_param!, add_shared_param! and connect_param!
#

@defcomp A begin

    p1 = Parameter{Symbol}()
    p2 = Parameter(default = 2)
    p3 = Parameter()
    p4 = Parameter(unit = "dollars")
    p5 = Parameter(unit = "\$")
    p6 = Parameter(index = [time])
    p7 = Parameter(index = [regions, time])

    function run_timestep(p,v,d,t)
    end
end

function _get_model()
    m = Model()
    set_dimension!(m, :time, 1:5);
    set_dimension!(m, :regions, [:R1, :R2, :R3])
    add_comp!(m, A)
    return m
end

# DataType, Shared vs. Unshared 
m = _get_model()

@test_throws MethodError update_param!(m, :A, :p1, 3) # can't convert
update_param!(m, :A, :p1, :hello)
@test model_param(m, :A, :p1).value == :hello
add_shared_param!(m, :p1_fail, 3)
@test_throws ErrorException connect_param!(m, :A, :p1, :p1_fail) # we throw specific error here
add_shared_param!(m, :p1, :goodbye)
connect_param!(m, :A, :p1, :p1)
@test model_param(m, :A, :p1).value == :goodbye
@test_throws ErrorException update_param!(m, :A, :p1, :foo) # can't call this method on a shared parameter
update_param!(m, :p1, :foo)
@test model_param(m, :A, :p1).value == :foo
disconnect_param!(m, :A, :p1)
update_param!(m, :A, :p1, :foo) # now we can update :p1 with this syntax since it was disconnected
update_param!(m, :p1, :bar) # this is the shared parameter named :p1
@test model_param(m, :A, :p1).value == :foo
@test model_param(m, :p1).value == :bar
    
m = _get_model()

add_shared_param!(m, :shared_param, 100)
connect_param!(m, :A, :p2, :shared_param)
connect_param!(m, :A, :p3, :shared_param)
@test model_param(m, :A, :p2).value == model_param(m, :A, :p3).value == 100

# we don't have to disconnect first because they have their own names, not :shared_param
update_param!(m, :A, :p2, 1)
update_param!(m, :A, :p3, 2)


# Units, Shared vs. Unshared
m = _get_model()

add_shared_param!(m, :myparam, 100)
connect_param!(m, :A, :p3, :myparam)
@test_throws ErrorException connect_param!(m, :A, :p4, :myparam) # units error
connect_param!(m, :A, :p4, :myparam; ignoreunits = true)
@test model_param(m, :A, :p3).value == model_param(m, :A, :p4).value == 100
@test_throws ErrorException update_param!(m, :myparam, :boo) # cannot convert
update_param!(m, :myparam, 200)
@test model_param(m, :A, :p3).value == model_param(m, :A, :p4).value == 200
@test_throws ErrorException connect_param!(m, :A, :p3, :myparam) # units error

# Default
m = _get_model()

@test model_param(m, :A, :p2).value == 2
@test !(is_shared(model_param(m, :A, :p2)))
update_param!(m, :A, :p2, 100)
@test !(is_shared(model_param(m, :A, :p2)))

# arrays and dimensions
m = _get_model()

@test_throws ErrorException add_shared_param!(m, :x, [1:10]) # need dimensions to be specified
@test_throws ErrorException add_shared_param!(m, :x, [1:10], dims = [:time]) # wrong dimensions
add_shared_param!(m, :x, 1:5, dims = [:time])

@test_throws ErrorException add_shared_param!(m, :y, fill(1, 3, 5)) # need dimensions to be specified
@test_throws ErrorException add_shared_param!(m, :y, fill(1, 3, 5), dims = [:time, :regions]) # need dimensions to be specified
add_shared_param!(m, :y, fill(1, 5, 3), dims = [:time, :regions])

@test_throws ErrorException connect_param!(m, :A, :p7, :y) # wrong dimensions, flipped around

#
# Section 2. set_leftover_params!
#

# TODO

#
# Section 3. update_params!
#

@defcomp A begin

    p1 = Parameter(default = 0)
    p2 = Parameter(default = 0)
    p3 = Parameter()
    p4 = Parameter()
    p5 = Parameter()
    p6 = Parameter()

    function run_timestep(p,v,d,t)
    end
end

function _get_model()
    m = Model()
    set_dimension!(m, :time, 1:5);
    add_comp!(m, A)

    add_shared_param!(m, :shared_param, 0)
    connect_param!(m, :A, :p3, :shared_param)
    connect_param!(m, :A, :p4, :shared_param)

    return m
end

# update the shared parameters and unshared parameters separately
m = _get_model()

shared_dict = Dict(:shared_param => 1)
update_params!(m, shared_dict)

unshared_dict = Dict((:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, unshared_dict)

run(m)
@test m[:A, :p3] == m[:A, :p4] == 1
@test m[:A, :p5] == 2
@test m[:A, :p6] == 3

# update both at the same time
m = _get_model()

dict = Dict(:shared_param => 1, (:A, :p5) => 2, (:A, :p6) => 3)
update_params!(m, dict)

run(m)
@test m[:A, :p3] == m[:A, :p4] == 1
@test m[:A, :p5] == 2
@test m[:A, :p6] == 3

# test failures

m = _get_model()

shared_dict = Dict(:shared_param => :foo)
@test_throws ErrorException update_params!(m, shared_dict) # units failure
shared_dict = Dict(:p3 => 3)
@test_throws ErrorException update_params!(m, shared_dict) # can't find parameter

unshared_dict = Dict((:A, :p5) => :foo, (:A, :p6) => 3)
@test_throws MethodError update_params!(m, unshared_dict) # units failure
unshared_dict = Dict((:B, :p5) => 5) 
@test_throws ErrorException update_params!(m, unshared_dict) # can't find component
unshared_dict = Dict((:B, :missing) => 5) 
@test_throws ErrorException update_params!(m, unshared_dict) # can't find parameter

nothing
