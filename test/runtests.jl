using Mimi
using Base.Test

tests = ["main", "optimimi"]

for t in tests
	fp = joinpath("test_$t.jl")
	println("$fp ...")
	include(fp)
end
