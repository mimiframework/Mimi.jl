using Mimi
using Test

@testset "Mimi-SA" begin

    @info("test_empirical.jl")
    include("test_empirical.jl")

    @info("test_defmcs.jl")
    include("test_defmcs.jl")

    @info("test_defmcs_modifications.jl")
    include("test_defmcs_modifications.jl")

    @info("test_defmcs_sobol.jl")
    include("test_defmcs_sobol.jl")

    @info("test_defmcs_delta.jl")
    include("test_defmcs_delta.jl")

    @info("test_reshaping.jl")
    include("test_reshaping.jl")    

    @info("test_payload.jl")
    include("test_payload.jl")

    @info("test_marginalmodel.jl")
    include("test_marginalmodel.jl")
end
