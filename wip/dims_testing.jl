@defcomp comp1 begin
   par1 = Parameter(index=[time])
   var1 = Variable(index=[time])

   function run_timestep(p,v,d,t)
        v.var1[t] = p.par1[t]
   end
end

@defcomp comp2 begin
   par2 = Parameter(index=[time, country])
   var2 = Variable(index=[time,country])

   function run_timestep(p,v,d,t)
        v.var2[t] = p.par2[t]
   end
end

@defcomp comp3 begin
    par3 = Parameter(index=[time, town])
    var3 = Variable(index=[time,town])
 
    function run_timestep(p,v,d,t)
         v.var3[t,:] = p.par3[t,:]
    end
end

 m = Model()
set_dimension!(m, :time, 2000:2010)
set_dimension!(m, :country, [:A, :B, :C])
set_dimension!(m, :town, ["a", "b", "c", "d"])
add_comp!(m, comp2)
add_comp!(m, comp3)
set_param!(m, :comp2, :par2, zeros(11,3))
connect_param!(m, :comp3 => :par3, :comp2 => :var2)

