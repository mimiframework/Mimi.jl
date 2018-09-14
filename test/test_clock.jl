using Mimi
using Test

import Mimi:
AbstractTimestep, FixedTimestep, VariableTimestep, Clock, timestep

Mimi.reset_compdefs()

t_f = FixedTimestep{1850, 10, 3000}(1)
c_f = Clock{FixedTimestep}(1850, 10, 3000)
@test timestep(c_f) == t_f

years = ([2000:1:2024; 2025:5:2105]...)
t_v = VariableTimestep{years}()
c_v = Clock{VariableTimestep}(years)
@test timestep(c_v) == t_v
