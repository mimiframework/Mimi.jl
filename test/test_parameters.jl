using Mimi
using Test

@testset "Parameters" begin

@defcomp Foo begin
    par = Parameter(default=2)
end

m = Model()

add_comp!(m, Foo)

@test haskey(m.md.external_params, :par)

end
