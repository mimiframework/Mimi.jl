module TestReplaceComp

using Test
using Mimi
import Mimi:
    reset_compdefs, compdefs, compdef, external_param_conns

reset_compdefs()

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
    x::Symbol = Parameter(index = [time])   # different datatype
    y = Variable()                          # different variable dimensions
end

# 1. Test scenario where the replacement works

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)                         # Original component X
set_param!(m, :X, :x, zeros(6))
replace_comp!(m, X_repl, :X)            # Successfully replaced by X_repl
run(m)
@test length(components(m)) == 1        # Only one component exists in the model
@test m[:X, :y] == 2 * ones(6)          # Successfully ran the run_timestep function from X_repl


# 2. Test bad internal incoming parameter

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)                                     # Add two components
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)              # Make an internal connection with a parameter with a time dimension
@test_throws ErrorException replace_comp!(m, bad1, :second) # Cannot make reconnections because :x in bad1 has different dimensions 
replace_comp!(m, bad1, :second, reconnect = false)          # Can replace without reconnecting
@test nameof(compdef(m.md, :second)) == :bad1                 # Successfully replaced


# 3. Test bad internal outgoing variable

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)                                     # Add two components
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)              # Make an internal connection from a variable with a time dimension
@test_throws ErrorException replace_comp!(m, bad2, :first)  # Cannot make reconnections because bad2 does not have a variable :y
replace_comp!(m, bad2, :first, reconnect = false)           # Can replace without reconnecting
@test nameof(compdef(m.md, :first)) == :bad2                  # Successfully replaced


# 4. Test bad external parameter name

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))                     # Set external parameter for :x

# Replaces with bad3, but warns that there is no parameter by the same name :x
@test_logs (:warn, r".*parameter x no longer exists in component.*") replace_comp!(m, bad3, :X)

@test nameof(compdef(m.md, :X)) == :bad3           # The replacement was still successful
#external_param_conns(md, comp_name)
@test length(external_param_conns(m)) == 0         # The external parameter connection was removed
@test length(external_params(m)) == 1              # The external parameter still exists


# 5. Test bad external parameter dimensions

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))                         # Set external parameter for :x
@test_throws ErrorException replace_comp!(m, bad1, :X)  # Cannot reconnect external parameter, :x in bad1 has different dimensions


# 6. Test bad external parameter datatype

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))                         # Set external parameter for :x
@test_throws ErrorException replace_comp!(m, bad4, :X)  # Cannot reconnect external parameter, :x in bad4 has different datatype


# 7. Test component name that doesn't exist

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
@test_throws ErrorException replace_comp!(m, X_repl, :Z)    # Component Z does not exist in the model, cannot be replaced


# 8. Test original postion placement functionality

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :c1)    
add_comp!(m, X, :c2)
add_comp!(m, X, :c3)

replace_comp!(m, X_repl, :c3)   # test replacing the last component
@test compdef(m.md, :c3) == X_repl

replace_comp!(m, X_repl, :c2)        # test replacing not the last one
@test compdef(m.md, :c2) == X_repl


end # module