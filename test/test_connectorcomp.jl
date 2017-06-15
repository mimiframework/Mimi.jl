using Mimi
using Base.Test

#######################################
#  Manual way of using ConnectorComp  #
#######################################

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


######################################
#  Now using new API for connecting  #
######################################

model2 = Model()
setindex(model2, :time, 2000:2010)
addcomponent(model2, ShortComponent; start=2005)
addcomponent(model2, LongComponent)

setparameter(model2, :ShortComponent, :a, 2.)
setparameter(model2, :LongComponent, :y, 1.)
connectparameter(model2, :LongComponent, :x, :ShortComponent, :b, zeros(11))

run(model2)
