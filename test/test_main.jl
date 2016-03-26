using Base.Test
using Mimi
using DataFrames

@defcomp foo1 begin
    index1 = Index()

    par1 = Parameter()
    par2::Bool = Parameter(index=[time,index1], description="description par 1")
    par3 = Parameter(index=[time])

    var1 = Variable()
    var2 = Variable(index=[time])
    var3 = Variable(index=[time,index1])
    var4::Bool = Variable(index=[3])
    var5 = Variable(index=[index1,4])
end

x1 = foo1(Float64, Dict{Symbol, Int}(:time=>10, :index1=>3))

@test x1.Dimensions.index1.start == 1
@test x1.Dimensions.index1.stop == 3

# Check variable types
@test isa(x1.Variables.var1, Float64)
@test isa(x1.Variables.var2, Array{Float64,1})
@test isa(x1.Variables.var3, Array{Float64,2})
@test isa(x1.Variables.var4, Array{Bool,1})
@test isa(x1.Variables.var5, Array{Float64,2})

# Check variable sizes
@test size(x1.Variables.var2,1)==10
@test size(x1.Variables.var3)==(10,3)
@test size(x1.Variables.var4,1)==3
@test size(x1.Variables.var5)==(3,4)

resetvariables(x1)

# Check all variables are defaulted
@test isnan(x1.Variables.var1)

@test_throws MethodError x1.Parameters.par1 = Array(Float64, 1,2)

x1.Parameters.par1 = 5.0
@test x1.Parameters.par1 == 5.0

m = Model()
setindex(m, :time, 20)
setindex(m, :index1, 5)
addcomponent(m, foo1)

@test in(:var1, variables(m, :foo1))

@test isa(getdataframe(m, :foo1, :var3), DataFrame)
