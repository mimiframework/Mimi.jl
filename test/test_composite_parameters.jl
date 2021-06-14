module TestCompositeParameters

using Mimi
using Test 

import Mimi: model_params

@defcomp A begin
    p1 = Parameter(unit = "\$", default=3)
    p2 = Parameter()

    v1 = Variable()
    v2 = Variable(index=[time])
end

@defcomp B begin
    p1 = Parameter(unit = "thous \$", default=3)
    p3 = Parameter(description="B p3")
    p4 = Parameter(index=[time])
    p5 = Parameter(default = 1)
end

#------------------------------------------------------------------------------
# Test a failure to resolve namespace collisions

fail_expr1 = :(
    @defcomposite TestFailComposite begin
        Component(A)
        Component(B)
        # Will fail because you need to resolve the namespace collision of the p1's
    end
)

err1 = try eval(fail_expr1) catch err err end 
@test occursin("unresolved parameter name collisions from subcomponents", sprint(showerror, err1))


#------------------------------------------------------------------------------
# Test a failure to resolve conflicting "description" fields

fail_expr2 = :(
    @defcomposite TestFailComposite begin
        Component(A)
        Component(B)
        
        p1 = Parameter(A.p1, B.p1, unit="")
        p2 = Parameter(A.p2, B.p3)  # Will fail because the conflicting descriptions aren't resolved
    end
)

err2 = try eval(fail_expr2) catch err err end 
@test occursin("subcomponents have conflicting values for the \"description\" field", sprint(showerror, err2))


#------------------------------------------------------------------------------
# Test trying to join parameters with different dimensions

fail_expr3 = :(
    @defcomposite TestFailComposite begin
        Component(A)
        Component(B)
        
        p1 = Parameter(A.p1, B.p1, unit="")
        p2 = Parameter(A.p2, B.p4)  # Will fail because different dimensions
    end
)

err3 = try eval(fail_expr3) catch err err end 
@test occursin("subcomponents have conflicting values for the \"dim_names\" field", sprint(showerror, err3))


#------------------------------------------------------------------------------
# Test a failure to auto-import a parameter because it's name has already been used

fail_expr4 = :(
    @defcomposite TestFailComposite begin
        Component(A)
        Component(B)
        
        p3 = Parameter(A.p1, B.p1, unit="")    # should fail on auto import of other p3 parameter
    end
)

err4 = try eval(fail_expr4) catch err err end 
@test occursin("this name has already been defined in the composite component's namespace", sprint(showerror, err4))


#------------------------------------------------------------------------------
# Test an attempt to import a parameter twice

fail_expr5 = :(
    @defcomposite TestFailComposite begin
        Component(A)
        Component(B)
        
        p1 = Parameter(A.p1, B.p1, unit="") 
        p1_repeat = Parameter(B.p1) # should not allow a second import of B.p1 (already connected)
    end
)

err5 = try eval(fail_expr5) catch err err end 
@test occursin("Duplicate import", sprint(showerror, err5))


#------------------------------------------------------------------------------
# Test set_param! with unit collision

function get_model()
    m = Model()
    set_dimension!(m, :time, 10)
    add_comp!(m, A)
    add_comp!(m, B)
    return m
end

m1 = get_model()
err6 = try set_param!(m1, :p1, 5) catch err err end
@test occursin("components have conflicting values for the :unit field of this parameter", sprint(showerror, err6))

# use ignoreunits flag
set_param!(m1, :p1, 5, ignoreunits=true)    

err7 = try run(m1) catch err err end
@test occursin("Cannot build model; the following parameters still have values of `nothing` and need to be updated:", sprint(showerror, err7))

# Set separate values for p1 in A and B
m2 = get_model()
set_param!(m2, :A, :p1, 2)  # Set the value only for component A

# test that the proper connection has been made for :p1 in :A
@test Mimi.model_param(m2, :p1).value == 2 
@test Mimi.model_param(m2, :p1).is_shared
# and that B.p1 is still the default value and unshared
sym = Mimi.get_model_param_name(m2, :B, :p1)
@test Mimi.model_param(m2, sym).value == 3
@test Mimi.model_param(m2, :B, :p1).value == 3
@test !Mimi.model_param(m2, :B, :p1).is_shared

# test defaults
m3 = get_model()
set_param!(m3, :p1, 1, ignoreunits=true)    # Need to set parameter values for all except :p5, which has a default
set_param!(m3, :p2, 2)    
set_param!(m3, :p3, 3)    
set_param!(m3, :p4, 1:10)    
run(m3)

err8 = try set_param!(m3, :B, :p1, 2) catch err err end
@test occursin("the model already has a parameter with this name", sprint(showerror, err8))

set_param!(m3, :B, :p1, :B_p1, 2)   # Use a unique name to set B.p1
@test Mimi.model_param(m3, :B_p1).value == 2 
@test Mimi.model_param(m3, :B_p1).is_shared
@test issubset(Set([:p1, :B_p1]), Set(keys(m3.md.model_params)))


#------------------------------------------------------------------------------
# Test update_param! with unit collision

function get_model()
    m = Model()
    set_dimension!(m, :time, 10)
    add_comp!(m, A)
    add_comp!(m, B)
    return m
end

m1 = get_model()
add_shared_param!(m1, :p1, 5)
connect_param!(m1, :A, :p1, :p1) # no conflict
err9 = try connect_param!(m1, :B, :p1, :p1) catch err err end
@test occursin("Cannot connect B:p1 to shared model parameter", sprint(showerror, err9))

# use ignoreunits flag
connect_param!(m1, :B, :p1, :p1, ignoreunits=true)    

err10 = try run(m1) catch err err end
@test occursin("Cannot build model; the following parameters still have values of `nothing` and need to be updated:", sprint(showerror, err10))

# Set separate values for p1 in A and B
m2 = get_model()
add_shared_param!(m2, :p1, 2)
connect_param!(m2, :A, :p1, :p1) # Set the value only for component A

# test that the proper connection has been made for :p1 in :A
@test Mimi.model_param(m2.md, :p1).value == 2 
@test Mimi.model_param(m2.md, :p1).is_shared
# and that B.p1 is still the default value and unshared
sym = Mimi.get_model_param_name(m2, :B, :p1)
@test Mimi.model_param(m2, sym).value == 3
@test Mimi.model_param(m2, :B, :p1).value == 3
@test !Mimi.model_param(m2, :B, :p1).is_shared

# test defaults - # Need to set parameter values for all except :p5, which has a default
m3 = get_model()
add_shared_param!(m3, :p1, 1)
connect_param!(m3, :A, :p1, :p1, ignoreunits = true)
connect_param!(m3, :B, :p1, :p1, ignoreunits = true)
update_param!(m3, :A, :p2, 2)    
update_param!(m3, :B, :p3, 3)    
update_param!(m3, :B, :p4, 1:10)    
run(m3)

err11 = try add_shared_param!(m3, :p1, 2) catch err err end
@test occursin("the model already has a shared parameter with this name", sprint(showerror, err11))

add_shared_param!(m3, :B_p1, 2) # Use a unique name to set B.p1
connect_param!(m3, :B, :p1, :B_p1)
@test Mimi.model_param(m3, :B_p1).value == 2 
@test Mimi.model_param(m3, :B_p1).is_shared
@test issubset(Set([:p1, :B_p1]), Set(keys(m3.md.model_params)))

#------------------------------------------------------------------------------
# Unit tests on default behavior

# different default and override 
@defcomp A begin
    p1 = Parameter(default=3)
end
@defcomp B begin
    p1 = Parameter(default=2)
end

@defcomposite top begin
    Component(A)
    Component(B)
    superp1 = Parameter(A.p1, B.p1, default = nothing) # override default collision with nothing
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, top);
@test length(model_params(m)) == 1
model_param_name = Mimi.get_model_param_name(m.md, :top, :superp1)
@test Mimi.is_nothing_param(model_params(m)[model_param_name])
@test !model_params(m)[model_param_name].is_shared

@defcomposite top begin
    Component(A)
    Component(B)
    superp1 = Parameter(A.p1, B.p1, default = 8.0) # override default collision with value
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, top);
@test length(model_params(m)) == 1
model_param_name = Mimi.get_model_param_name(m.md, :top, :superp1)
@test model_params(m)[model_param_name].value == 8.0
@test !model_params(m)[model_param_name].is_shared

# same default and no override
@defcomp A begin
    p1 = Parameter(default=2)
end
@defcomp B begin
    p1 = Parameter(default=2)
end

@defcomposite top begin
    Component(A)
    Component(B)
    superp1 = Parameter(A.p1, B.p1) 
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, top);
@test length(model_params(m)) == 1
model_param_name = Mimi.get_model_param_name(m.md, :top, :superp1)
@test model_params(m)[model_param_name].value == 2
@test !model_params(m)[model_param_name].is_shared

# simple case with no super parameter
@defcomp A begin
    p1 = Parameter(default=2)
end
@defcomp B begin
    p2 = Parameter(default=3)
end

@defcomposite top begin
    Component(A)
    Component(B)
end

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, top);
@test length(model_params(m)) == 2
model_param_name = Mimi.get_model_param_name(m.md, :top, :p1)
@test model_params(m)[model_param_name].value == 2
@test !model_params(m)[model_param_name].is_shared
model_param_name = Mimi.get_model_param_name(m.md, :top, :p2)
@test model_params(m)[model_param_name].value == 3
@test !model_params(m)[model_param_name].is_shared

#------------------------------------------------------------------------------
# Test set_param! for parameter that exists in neither model definition nor any subcomponent

m1 = get_model()
err12 = try set_param!(m1, :pDNE, 42) catch err err end
@test occursin("not found in ModelDef or children", sprint(showerror, err12))

# Test update_param! for parameter that exists in neither model definition nor any subcomponent
err13 = try update_param!(m1, :pDNE, 42) catch err err end
@test occursin("not found in composite's model parameters", sprint(showerror, err13))

end #module
