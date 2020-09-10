module brick

using Mimi
using Distributions

@defcomp component1 begin

    savingsrate = Parameter{Distributions.Normal{Float64}}()
    pickrate = Variable(index=[time])
    function run_timestep(p, v, d, t)
        v.pickrate[t] = rand(p.savingsrate)
    end

end

function get_model()
    m = Model()
    set_dimension!(m, :time, collect(2015:5:2110))
    add_comp!(m, component1)
	set_param!(m, :component1, :savingsrate, Distributions.Normal(1.0))
    return m
end

end # module