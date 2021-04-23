using Mimi

# the @allow_missing macro allows a parameter or variable to access a missing value 
# without throwing an error, which is less safe for users but avoids some corner
# case problems in the context of this type of connectin or unit-conversion component

@defcomp multiplier begin

    multiply    = Parameter(index=[time])
    input       = Parameter(index=[time])
    output      = Variable(index=[time])

    function run_timestep(p, v, d, t)
        v.output[t] = @allow_missing(p.input[t]) * p.multiply[t]
    end
end
