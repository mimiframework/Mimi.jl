using Mimi
include("wip/export_all.jl")

years = tuple([2000:1:2024; 2025:5:2105]...)

ft = Timestep{2010, 10, 2050}(1)
vt = VariableTimestep{years}()

fc = Clock(2010, 10, 2050)
vc = Clock(years)

advance(fc); fc

advance(vc); vc
