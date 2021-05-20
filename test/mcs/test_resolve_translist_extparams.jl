using Mimi
using Distributions
using Test

sd = @defsim begin
    sampling(LHSData)
    p = Normal(0, 1)
end 

@defcomp test1 begin
    p = Parameter(default = 5)
    function run_timestep(p, v, d, t) end
end

@defcomp test2 begin
    p = Parameter(default = 5)
    function run_timestep(p, v, d, t) end
end

@defcomp test3 begin
    a = Parameter(default = 5)
    function run_timestep(p, v, d, t) end
end

#------------------------------------------------------------------------------
# Test a failure to find the unshared parameter in any components
m = Model()
set_dimension!(m, :time, 2000:10:2050)
add_comp!(m, test3)

fail_expr1 = :(
    run(sd, m, 100)
)

err1 = try eval(fail_expr1) catch err err end 
@test occursin("Cannot resolve because p not found in any of the component", sprint(showerror, err1))

#------------------------------------------------------------------------------
# Test a failure due to finding the unshared parameter in more than one component
m = Model()
set_dimension!(m, :time, 2000:10:2050)
add_comp!(m, test1)
add_comp!(m, test2)

fail_expr2 = :(
    run(sd, m, 100)
)

err2 = try eval(fail_expr2) catch err err end 
@test occursin("Cannot resolve because parameter name p found in more than one component", sprint(showerror, err2))

#------------------------------------------------------------------------------
# Test a failure due to finding the unshared parameter in more than one component
m = Model()
set_dimension!(m, :time, 2000:10:2050)
add_comp!(m, test1)
add_comp!(m, test2)

fail_expr3 = :(
    run(sd, m, 100)
)

err3 = try eval(fail_expr3) catch err err end 
@test occursin("Cannot resolve because parameter name p found in more than one component", sprint(showerror, err3))

#------------------------------------------------------------------------------
# Test a failure due to finding an unshared parameter in both components but with 
# different names
m1 = Model()
set_dimension!(m1, :time, 2000:10:2050)
add_comp!(m1, test1)

m2 = Model()
set_dimension!(m2, :time, 2000:10:2050)
add_comp!(m2, test2)

fail_expr4 = :(
    run(sd, [m1, m2], 100)
)

err4 = try eval(fail_expr4) catch err err end 
@test occursin("Cannot resolve because model parameter connected to p has different names in different models", sprint(showerror, err4))

#------------------------------------------------------------------------------
# Test a failure due to finding an unshared parameter in one model, but it is shared
# in the other (and thus has a different name)
m1 = Model()
set_dimension!(m1, :time, 2000:10:2050)
add_comp!(m1, test1)

m2 = Model()
set_dimension!(m2, :time, 2000:10:2050)
add_comp!(m2, test2)
set_param!(m2, :p, 5)

fail_expr5 = :(
    run(sd, [m1, m2], 100)
)

err5 = try eval(fail_expr5) catch err err end 
@test occursin("Cannot resolve because p is not a shared parameter in models Any[:Model1], but is a shared parameter in the other models in sim_inst.models list", sprint(showerror, err5))

#------------------------------------------------------------------------------
# Test a failure due to finding an unshared parameter in one model, but not 
# the other
m1 = Model()
set_dimension!(m1, :time, 2000:10:2050)
add_comp!(m1, test1)

m2 = Model()
set_dimension!(m2, :time, 2000:10:2050)
add_comp!(m2, test2)

fail_expr6 = :(
    run(sd, [m1, m2], 100)
)

err6 = try eval(fail_expr6) catch err err end 
@test occursin("Cannot resolve because model parameter connected to p has different names in different models", sprint(showerror, err6))

#------------------------------------------------------------------------------
# Test success cases 

m = Model()
set_dimension!(m, :time, 2000:10:2050)
add_comp!(m, test1)
run(sd, m, 100)

add_comp!(m, test2)
set_param!(m, :p, 5)
run(sd, m, 100)
