# Example sent by James Rising

@defcomp Simple begin
    region = Index()
    
    var = Variable(index=[time, region], unit="\$/yr")
    
    function run_timestep(p, v, d, t)
        v.var[t, :] .= 0
    end
end

model = Model()
set_dimension!(model, :time, collect(1:10))
set_dimension!(model, :region, ["Tropics", "Subtropics", "Temperates"])
add_comp!(model, Simple)

run(model)
