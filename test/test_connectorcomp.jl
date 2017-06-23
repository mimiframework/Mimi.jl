using Mimi
using Base.Test

#--------------------------------------
#  Manual way of using ConnectorComp
#--------------------------------------

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
addcomponent(m, ConnectorCompVector, :MyConnector) # can give it your own name
addcomponent(m, LongComponent; start=2000)

@test Mimi.getmetainfo(m, :MyConnector).component_name == :ConnectorCompVector

setparameter(m, :ShortComponent, :a, 2.)
setparameter(m, :LongComponent, :y, 1.)
connectparameter(m, :MyConnector, :input1, :ShortComponent, :b)
setparameter(m, :MyConnector, :input2, zeros(100))
connectparameter(m, :LongComponent, :x, :MyConnector, :output)

run(m)

@test length(m[:ShortComponent, :b])==901
@test length(m[:MyConnector, :input1])==901
@test length(m[:MyConnector, :input2])==100
@test length(m[:LongComponent, :z])==1001

for i in 1:900
    @test m[:ShortComponent, :b][i] == 2*i
end

b = getdataframe(m, :ShortComponent, :b)
@test size(b) == (1001, 2)

#-------------------------------------
#  Now using new API for connecting
#-------------------------------------

model2 = Model()
setindex(model2, :time, 2000:2010)
addcomponent(model2, ShortComponent; start=2005)
addcomponent(model2, LongComponent)

setparameter(model2, :ShortComponent, :a, 2.)
setparameter(model2, :LongComponent, :y, 1.)
connectparameter(model2, :LongComponent, :x, :ShortComponent, :b, zeros(11))

run(model2)

@test length(model2[:ShortComponent, :b])==6
@test length(model2[:LongComponent, :z])==11
@test length(components(model2))==2

#-------------------------------------
#  A Short component that ends early
#-------------------------------------

model3 = Model()
setindex(model3, :time, 2000:2010)
addcomponent(model3, ShortComponent; final=2005)
addcomponent(model3, LongComponent)

setparameter(model3, :ShortComponent, :a, 2.)
setparameter(model3, :LongComponent, :y, 1.)
connectparameter(model3, :LongComponent, :x, :ShortComponent, :b, zeros(11))

run(model3)

@test length(model3[:ShortComponent, :b])==6
@test length(model3[:LongComponent, :z])==11
@test length(components(model3))==2

b2 = getdataframe(model3, :ShortComponent, :b)
@test size(b2) == (11,2)
[(@test b2[:b][i]==2*i) for i in 1:6]
[(@test isnan(b2[:b][i])) for i in 7:11]

#------------------------------------------------------
#  A model that requires multiregional ConnectorComps
#------------------------------------------------------

@defcomp Long begin
    regions = Index()

    x = Parameter(index = [time, regions])
    out = Variable(index = [time, regions])
end

function run_timestep(s::Long, ts::Timestep)
    p, v, d = s.Parameters, s.Variables, s.Dimensions
    for r in d.regions
        v.out[ts, r] = p.x[ts, r]
    end
end

@defcomp Short begin
    regions = Index()

    a = Parameter(index=[regions])
    b = Variable(index=[time, regions])
end

function run_timestep(s::Short, ts::Timestep)
    p, v, d = s.Parameters, s.Variables, s.Dimensions
    for r in d.regions
        v.b[ts, r] = ts.t + p.a[r]
    end
end

model4 = Model()
setindex(model4, :time, 2000:5:2100)
setindex(model4, :regions, [:A, :B, :C])
addcomponent(model4, Short; start=2020)
addcomponent(model4, Long)

setparameter(model4, :Short, :a, [1,2,3])
connectparameter(model4, :Long, :x, :Short, :b, zeros(21,3))

run(model4)

@test size(model4[:Short, :b])==(17, 3)
@test size(model4[:Long, :out])==(21, 3)
@test length(components(model4))==2

b3 = getdataframe(model4, :Short, :b)
@test size(b3)==(63,3)

#-------------------------------------------------------------
#  Test where the short component starts late and ends early
#-------------------------------------------------------------

model5 = Model()
setindex(model5, :time, 2000:5:2100)
setindex(model5, :regions, [:A, :B, :C])
addcomponent(model5, Short; start=2020, final=2070)
addcomponent(model5, Long)

setparameter(model5, :Short, :a, [1,2,3])
connectparameter(model5, :Long=>:x, :Short=>:b, zeros(21,3))

run(model5)

@test size(model5[:Short, :b])==(11, 3)
@test size(model5[:Long, :out])==(21, 3)
@test length(components(model5))==2

b4 = getdataframe(model5, :Short, :b)
@test size(b4)==(63,3)

#-----------------------------------------
#  Test getdataframe with multiple pairs
#-----------------------------------------

result = getdataframe(model5, :Short=>:b, :Long=>:out)
@test size(result)==(63,4)
[(@test isnan(result[i, :b])) for i in 1:12]
[(@test isnan(result[i, :b])) for i in 46:63]
[(@test result[i, :out]==0) for i in 1:12]
[(@test result[i, :out]==0) for i in 46:63]
