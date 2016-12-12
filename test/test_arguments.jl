using Base.Test
using Mimi

@defcomp A begin
  varA = Variable(index=[time])
  parA = Parameter()
end

m = Model()

#############################################
#  Tests for connecting scalar parameters   #
#############################################

function run_timestep(s::A, t::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    v.varA[t] = p.parA
end


@test_throws ErrorException run(m)
println("Passed all test_argument tests")
