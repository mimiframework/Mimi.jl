using Mimi
using Test

@testset "Parameters" begin

@defcomp Foo begin
    par = Parameter(default=2)
end

m = Model()
set_dimension!(m, :time, 1:10)
add_comp!(m, Foo)

@test haskey(m.md.external_params, :par)

run(m)
@test haskey(m.md.external_params, :par)

end