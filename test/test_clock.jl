module TestClock

using Mimi
using Base.Test

import Mimi:
    AbstractTimestep, FixedTimestep, VariableTimestep, Clock, timestep, time_index, 
    advance, reset_compdefs

reset_compdefs()

t_f = FixedTimestep{1850, 10, 3000}(1)
c_f = Clock{FixedTimestep}(1850, 10, 3000)
@test timestep(c_f) == t_f
@test time_index(c_f) == 1
advance(c_f)
@test time_index(c_f) == 2


years = ([2000:1:2024; 2025:5:2105]...)
t_v = VariableTimestep{years}()
c_v = Clock{VariableTimestep}(years)
@test timestep(c_v) == t_v

end #module
