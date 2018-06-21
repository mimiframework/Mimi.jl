using FileIO

using Mimi
using Base.Test

# For now, use the warn function; for 0.7/1.0, remove this and use real logging...
macro info(msg)
    msg = "\n$msg"
    :(Base.println_with_color(:light_blue, $msg, bold=true))
end


@testset "Mimi-MCS" begin

    @info("test_empirical.jl")
    include("test_empirical.jl")

    @info("test_defmcs.jl")
    include("test_defmcs.jl")

end