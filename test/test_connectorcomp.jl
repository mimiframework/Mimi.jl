module TestConnectorComp

using Mimi
using Test

import Mimi:
    reset_compdefs

reset_compdefs()

#
# Test the pre-defined connector component
#

#--------------------------------------
#  Manual way of using ConnectorComp
#--------------------------------------

@defcomp LongComponent begin
    x = Parameter(index=[time])
    y = Parameter()
    z = Variable(index=[time])
    
    function run_timestep(p, v, d, ts::Timestep)
        v.z[ts] = p.x[ts] + p.y
    end
end

@defcomp ShortComponent begin
    a = Parameter()
    b = Variable(index=[time])
    
    function run_timestep(p, v, d, ts::Timestep)
        v.b[ts] = p.a * ts.t
    end
end

m = Model()
set_dimension!(m, :time, 2000:3000)
nsteps = Mimi.dim_count(m.md, :time)

add_comp!(m, ShortComponent; first=2100)
add_comp!(m, ConnectorCompVector, :MyConnector) # can give it your own name
add_comp!(m, LongComponent; first=2000)

comp_def = compdef(m, :MyConnector)
@test Mimi.compname(comp_def.comp_id) == :ConnectorCompVector

set_param!(m, :ShortComponent, :a, 2.)
set_param!(m, :LongComponent, :y, 1.)
connect_param!(m, :MyConnector, :input1, :ShortComponent, :b)
set_param!(m, :MyConnector, :input2, zeros(nsteps))
connect_param!(m, :LongComponent, :x, :MyConnector, :output)

run(m)

@test length(m[:ShortComponent, :b]) == 901
@test length(m[:MyConnector, :input1]) == 901
@test length(m[:MyConnector, :input2]) ==  1001 # TBD: was 100 -- accidental deletion or...?
@test length(m[:LongComponent, :z]) == 1001

@test all([m[:ShortComponent, :b][i] == 2*i for i in 1:900])

b = getdataframe(m, :ShortComponent, :b)
@test size(b) == (1001, 2)

#-------------------------------------
#  Now using new API for connecting
#-------------------------------------

model2 = Model()
set_dimension!(model2, :time, 2000:2010)
add_comp!(model2, ShortComponent; start=2005)
add_comp!(model2, LongComponent)

set_param!(model2, :ShortComponent, :a, 2.)
set_param!(model2, :LongComponent, :y, 1.)
connect_param!(model2, :LongComponent, :x, :ShortComponent, :b, zeros(11))

run(model2)

@test length(model2[:ShortComponent, :b]) == 6
@test length(model2[:LongComponent, :z]) == 11
@test length(components(model2.mi)) == 2

#-------------------------------------
#  A Short component that ends early
#-------------------------------------

model3 = Model()
set_dimension!(model3, :time, 2000:2010)
add_comp!(model3, ShortComponent; last=2005)
add_comp!(model3, LongComponent)

set_param!(model3, :ShortComponent, :a, 2.)
set_param!(model3, :LongComponent, :y, 1.)
connect_param!(model3, :LongComponent, :x, :ShortComponent, :b, zeros(11))

run(model3)

@test length(model3[:ShortComponent, :b]) == 6
@test length(model3[:LongComponent, :z]) == 11
@test length(components(model3.mi)) == 2

b2 = getdataframe(model3, :ShortComponent, :b)
@test size(b2) == (11,2)
@test all([b2[:b][i] == 2*i for i in 1:6])
@test all([isnan(b2[:b][i]) for i in 7:11])

#------------------------------------------------------
#  A model that requires multiregional ConnectorComps
#------------------------------------------------------

@defcomp Long begin
    regions = Index()

    x = Parameter(index = [time, regions])
    out = Variable(index = [time, regions])
    
    function run_timestep(p, v, d, ts::Timestep)
        for r in d.regions
            v.out[ts, r] = p.x[ts, r]
        end
    end
end

@defcomp Short begin
    regions = Index()

    a = Parameter(index=[regions])
    b = Variable(index=[time, regions])
    
    function run_timestep(p, v, d, ts::Timestep)
        for r in d.regions
            v.b[ts, r] = ts.t + p.a[r]
        end
    end
end

model4 = Model()
set_dimension!(model4, :time, 2000:5:2100)
set_dimension!(model4, :regions, [:A, :B, :C])
add_comp!(model4, Short; start=2020)
add_comp!(model4, Long)

set_param!(model4, :Short, :a, [1,2,3])
connect_param!(model4, :Long, :x, :Short, :b, zeros(21,3))

run(model4)

@test size(model4[:Short, :b]) == (17, 3)
@test size(model4[:Long, :out]) == (21, 3)
@test length(components(model4)) == 2

b3 = getdataframe(model4, :Short, :b)
@test size(b3)==(63,3)

#-------------------------------------------------------------
#  Test where the short component starts late and ends early
#-------------------------------------------------------------

model5 = Model()
set_dimension!(model5, :time, 2000:5:2100)
set_dimension!(model5, :regions, [:A, :B, :C])
add_comp!(model5, Short; first=2020, last=2070)
add_comp!(model5, Long)

set_param!(model5, :Short, :a, [1,2,3])
connect_param!(model5, :Long=>:x, :Short=>:b, zeros(21,3))

run(model5)

@test size(model5[:Short, :b]) == (11, 3)
@test size(model5[:Long, :out]) == (21, 3)
@test length(components(model5)) == 2

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

end #module
