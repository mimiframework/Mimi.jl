using Mimi

y = macroexpand(:(
    @defcomp foo begin
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
    ))

println(y)
