module TestCompositeParameters

using Mimi
using Test 

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
# Test a failure to auto-import a paramter because it's name has already been used

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
@test occursin("Cannot build model; the following parameters are not set", sprint(showerror, err7))

# Set separate values for p1 in A and B
m2 = get_model()
set_param!(m2, :A, :p1, 1)  # Set the value only for component A
@test length(m2.md.external_param_conns) == 1 # test that only one connection has been made
@test Mimi.UnnamedReference(:B, :p1) in Mimi.unconnected_params(m2.md)  # and that B.p1 is still unconnected 

err8 = try set_param!(m2, :B, :p1, 2) catch err err end
@test occursin("the model already has an external parameter with this name", sprint(showerror, err8))

set_param!(m2, :B, :p1, :B_p1, 2)   # Use a unique name to set B.p1
@test length(m2.md.external_param_conns) == 2 
@test Set(keys(m2.md.external_params)) == Set([:p1, :B_p1])

# Test defaults being set properly:
m3 = get_model()
set_param!(m3, :p1, 1, ignoreunits=true)    # Need to set parameter values for all except :p5, which has a default
set_param!(m3, :p2, 2)    
set_param!(m3, :p3, 3)    
set_param!(m3, :p4, 1:10)    
run(m3)
@test length(keys(m3.md.external_params)) == 4      # The default value was not added to the original md's list
@test length(keys(m3.mi.md.external_params)) == 5   # Only added to the model instance's definition

#------------------------------------------------------------------------------
# Test set_param! for parameter that exists in neither model definition nor any subcomponent

m1 = get_model()
err8 = try set_param!(m1, :pDNE, 42) catch err err end
@test occursin("not found in ModelDef or children", sprint(showerror, err8))

end #module
