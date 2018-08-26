module TestNumComponents

using Base.Test
using Mimi

import Mimi:
  reset_compdefs

reset_compdefs()

@defcomp ArgTester begin
  varA = Variable(index=[time])
  parA = Parameter()
   
  function run_timestep(p, v, d, t)
    v.varA[t] = p.parA
  end
end

m = Model()

# trying to run model with no components
set_dimension!(m, :time, 1:10)
@test_throws ErrorException run(m)

end #module
