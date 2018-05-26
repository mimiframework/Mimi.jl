using Mimi
include("wip/export_all.jl")

ft = Timestep{2010, 10, 2050}(1)
vt = VariableTimestep{2010, (10,20,50), 2090}()

gettime(ft)
gettime(vt)

is_start(ft)
is_start(vt)

is_stop(ft)
is_stop(vt)

finished(ft)
finished(vt)


fc = Clock(2010, 10, 2050)
vc = Clock(2010, (10,20,50, 20), 2090)

advance(fc); fc

advance(vc); vc
