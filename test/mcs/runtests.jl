using Mimi
using Test

@testset "Mimi-MCS" begin

    @info("test_empirical.jl")
    include("test_empirical.jl")

    @info("test_defmcs.jl")
    include("test_defmcs.jl")

    @info("test_defmcs_sobol.jl")
    include("test_defmcs_sobol.jl")

end