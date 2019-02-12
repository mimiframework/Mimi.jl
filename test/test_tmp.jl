module Tmp

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

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, exports=[:x => :z])          # Original component X
add_comp!(m, X_repl)
set_param!(m, :X, :x, zeros(6))

if false
    run(m)
    @test m[:X, :y] == ones(6)

    replace_comp!(m, X_repl, :X)
    run(m)

    @test length(components(m)) == 1        # Only one component exists in the model
    @test m[:X, :y] == 2 * ones(6)          # Successfully ran the run_timestep function from X_repl
end

end # module

using Mimi
m = Tmp.m
