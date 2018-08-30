module TestReplaceComp

using Base.Test
using Mimi


@defcomp X begin    
    x = Parameter(index = [time])
    y = Variable(index = [time])
    function run_timestep(p, v, d, t)
        v.y[t] = 1
    end
end 

@defcomp X_repl begin
    x = Parameter(index = [time])
    y = Variable(index = [time])
    function run_timestep(p, v, d, t)
        v.y[t] = 2
    end
end

@defcomp bad1 begin
    x = Parameter()                 # parameter has same name as in component X, but different dimensions
    y = Variable(index = [time])
end

@defcomp bad2 begin
    x = Parameter(index = [time])
    z = Variable(index = [time])    # different variable name
end

@defcomp bad3 begin
    z = Parameter()                 # external parameter with different dimensions
    y = Variable(index = [time])
end

@defcomp bad4 begin
    x::Symbol = Parameter(index = [time])   # different datatype
    y = Variable()                          # different variable dimensions
end



# 1. Test scenario where the replacement works

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))
replace_comp!(m, X_repl, :X)
run(m)
@test length(components(m)) == 1
@test m[:X, :y] == 2 * ones(6) 


# 2. Test bad internal incoming parameter

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)
@test_throws ErrorException replace_comp!(m, bad1, :second) 
replace_comp!(m, bad1, :second, reconnect = false)  # Works without reconnecting
@test m.md.comp_defs[:second].comp_id.comp_name == :bad1


# 3. Test bad internal outgoing variable

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X, :first)
add_comp!(m, X, :second)
connect_param!(m, :second => :x, :first => :y)
@test_throws ErrorException replace_comp!(m, bad2, :first) 
replace_comp!(m, bad2, :first, reconnect = false) 
@test m.md.comp_defs[:first].comp_id.comp_name == :bad2


# 4. Test bad external parameter name

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))
replace_comp!(m, bad3, :X)                          # Warns that there is no parameter by the same name
@test m.md.comp_defs[:X].comp_id.comp_name == :bad3 # still replaces
@test length(m.md.external_param_conns) == 0        # the external paramter connection is gone
@test length(m.md.external_params) == 1             # the external parameter still exists


# 5. Test bad external parameter dimensions

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))
@test_throws ErrorException replace_comp!(m, bad1, :X)


# 6. Test bad external parameter datatype

m = Model()
set_dimension!(m, :time, 2000:2005)
add_comp!(m, X)
set_param!(m, :X, :x, zeros(6))
@test_throws ErrorException replace_comp!(m, bad4, :X)


end # module