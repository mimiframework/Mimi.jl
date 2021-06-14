module TestReplaceComp

using Test
using Mimi
import Mimi:
    compdefs, compname, compdef, components, comp_id, external_param_conns, model_params

@defcomp X begin
    x = Parameter(index = [time])
    y = Variable(index = [time])
    function run_timestep(p, v, d, t)
        v.y[t] = 1
    end
end

@defcomp X_repl begin
    x = Parameter(index = [time])
    y = Variable(index = [time])
    function run_timestep(p, v, d, t)
        v.y[t] = 2
    end
end

@defcomp X_repl_extraparams begin
    x = Parameter(index = [time])
    y = Variable(index = [time])

    a = Parameter(default = 10)
    b = Parameter()

    function run_timestep(p, v, d, t)
        v.y[t] = 2
    end
end

@defcomp bad1 begin
    x = Parameter()                 # parameter has same name but different dimensions
    y = Variable(index = [time])
end

@defcomp bad2 begin
    x = Parameter(index = [time])
    z = Variable(index = [time])    # different variable name
end

@defcomp bad3 begin
    z = Parameter()                 # different parameter name
    y = Variable(index = [time])
end

@defcomp bad4 begin
    x = Parameter{Symbol}(index = [time])   # different datatype
    y = Variable()                          # different variable dimensions
end

# 1. Test scenario where the replacement works

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)                         # Original component X
update_param!(m, :X, :x, zeros(6))
@test_throws ErrorException replace_comp!(m, X_repl, :X) # test that the old function name now errors
replace!(m, :X => X_repl)               # Replace X with X_repl
run(m)
@test length(components(m)) == 1        # Only one component exists in the model
@test m[:X, :y] == 2 * ones(6)          # Successfully ran the run_timestep function from X_repl


# 2. Test bad internal incoming parameter

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)                                     # Add two components
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)              # Make an internal connection with a parameter with a time dimension
@test_throws ErrorException replace!(m, :second => bad1)    # Cannot make reconnections because :x in bad1 has different dimensions
@test_throws ErrorException replace_comp!(m, bad1.comp_id, :second, reconnect = false) # Test that the old function name now errors
replace!(m, :second => bad1, reconnect = false)             # Can replace without reconnecting
second = compdef(m, :second)
@test second.comp_id.comp_name == :bad1                     # Successfully replaced


# 3. Test bad internal outgoing variable

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)                                  # Add two components
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)           # Make an internal connection from a variable with a time dimension
@test_throws ErrorException replace!(m, :first => bad2)  # Cannot make reconnections because bad2 does not have a variable :y
replace!(m, :first => bad2, reconnect = false)           # Can replace without reconnecting
first = compdef(m, :first)
@test first.comp_id.comp_name == :bad2                   # Successfully replaced


# 4. Test bad model parameter name

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
update_param!(m, :X, :x, zeros(6))                     # Set model parameter for :x

# Replaces with bad3, but warns that there is no parameter by the same name :x
@test_logs(
    # (:warn, r".*parameter x no longer exists in component.*"),
    replace!(m, :X => bad3)
)

@test compname(compdef(m, :X)) == :bad3            # The replacement was still successful
@test length(external_param_conns(m)) == 1         # The external parameter connection was removed, so just :z is there
@test length(model_params(m)) == 2              # The model parameter still exists for both :x and :z


# 5. Test bad model parameter dimensions

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
update_param!(m, :X, :x, zeros(6))                         # Set model parameter for :x
@test_throws ErrorException replace!(m, :X => bad1)     # Cannot reconnect model parameter, :x in bad1 has different dimensions


# 6. Test bad model parameter datatype

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
update_param!(m, :X, :x, zeros(6))                         # Set model parameter for :x
@test_throws ErrorException replace!(m, :X => bad4)  # Cannot reconnect model parameter, :x in bad4 has different datatype


# 7. Test component name that doesn't exist

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
@test_throws ErrorException replace!(m, :Z => X_repl)    # Component Z does not exist in the model, cannot be replaced


# 8. Test original position placement functionality

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :c1)
add_comp!(m, X, :c2)
add_comp!(m, X, :c3)

replace!(m, :c3 => X_repl)        # test replacing the last component
@test compdef(m, :c3).comp_id == X_repl.comp_id

replace!(m, :c2 => X_repl)        # test replacing not the last one
@test compdef(m, :c2).comp_id == X_repl.comp_id


# 9. Test that any previous set parameters are preserved, even in the presence of default values

@defcomp A begin
    p1 = Parameter(default=1)
end

@defcomp B begin
    p1 = Parameter(default=2)
end

m = Model()
set_dimension!(m, :time, 10)
add_comp!(m, A)
update_param!(m, :A, :p1, 3)
replace!(m, :A => B)
run(m)
@test m[:A, :p1] == 3

# 10. Test when the new component has extra parameters not in the original one

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)                         # Original component X
update_param!(m, :X, :x, zeros(6))
replace!(m, :X => X_repl_extraparams)               # Replace X with X_repl_extraparams
@test length(model_params(m)) == 3 # should have two new parameters in the model parameters list
update_param!(m, :X, :b, 8.0) # need to set b since it doesn't have a default, a will have a default
run(m)
@test length(components(m)) == 1        # Only one component exists in the model
@test m[:X, :y] == 2 * ones(6)          # Successfully ran the run_timestep function from X_repl

end # module
