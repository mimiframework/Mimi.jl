using Mimi
using Base.Test

@defcomp LongComponent begin
    x = Parameter(index=[time])
    y = Parameter()
    z = Variable(index=[time])
end

function run_timestep(s::LongComponent, ts::Timestep)
    p = s.Parameters
    v = s.Variables

    v.z[ts] = p.x[ts] + p.y
end

@defcomp ShortComponent begin
    a = Parameter()
    b = Variable(index=[time])
end

function run_timestep(s::ShortComponent, ts::Timestep)
    p = s.Parameters
    v = s.Variables

    v.b[ts] = p.a * ts.t
end

m = Model()
setindex(m, :time, 2000:3000)
addcomponent(m, ShortComponent; start=2100)
addcomponent(m, ConnectorComp)
addcomponent(m, LongComponent; start=2000)

setparameter(m, :ShortComponent, :a, 2.)
setparameter(m, :LongComponent, :y, 1.)
connectparameter(m, :ConnectorComp, :input1, :ShortComponent, :b)
setparameter(m, :ConnectorComp, :input2, zeros(100))
connectparameter(m, :LongComponent, :x, :ConnectorComp, :output)

run(m)

@test length(m[:ShortComponent, :b])==901
@test length(m[:ConnectorComp, :input1])==901
@test length(m[:ConnectorComp, :input2])==100
@test length(m[:LongComponent, :z])==1001

for i in 1:900
    @test m[:ShortComponent, :b][i] == 2*i
end
