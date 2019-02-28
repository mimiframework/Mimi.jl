using Mimi
using Test

@testset "Mimi-SA" begin

    @info("test_empirical.jl")
    include("test_empirical.jl")

    @info("test_defsim.jl")
    include("test_defsim.jl")

    @info("test_defsim_sobol.jl")
    include("test_defsim_sobol.jl")

end
