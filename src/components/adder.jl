using Mimi

# When evaluated in the __init__() function, the surrounding module
# is Main rather than Mimi.
@defcomp adder begin
    add    = Parameter(index=[time])
    input  = Parameter(index=[time])
    output = Variable(index=[time])

    function run_timestep(p, v, d, t)
        v.output[t] = p.input[t] + p.add[t]
    end
end

