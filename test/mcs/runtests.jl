using Mimi
using Test

@testset "Mimi-SA" begin

    @info("test_empirical.jl")
    include("test_empirical.jl")

    @info("test_defsim.jl")
    include("test_defsim.jl")

    @info("test_defsim_modifications.jl")
    include("test_defsim_modifications.jl")

    @info("test_defsim_sobol.jl")
    include("test_defsim_sobol.jl")

    @info("test_defsim_delta.jl")
    include("test_defsim_delta.jl")

    @info("test_reshaping.jl")
    include("test_reshaping.jl")

    @info("test_payload.jl")
    include("test_payload.jl")

    @info("test_marginalmodel.jl")
    include("test_marginalmodel.jl")

    @info("test_translist.jl")
    include("test_translist.jl")
end
